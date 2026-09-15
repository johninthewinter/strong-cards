#!/usr/bin/env python3
"""
PreToolUse enforcement hook: any Bash command that shells out to `codex exec`
(the gpt-5.6-luna/sol dispatch path) must be wrapped in a bounded `timeout`.

Rule (Joe, 2026-08-02): codex exec has a confirmed failure mode of hanging
with zero output for hours -- one instance sat stuck 4.5+ hours completely
undetected in a live session, because nothing about the tool call signaled
failure. Unlike fanout-analysis-guard.py's judgment call (review vs.
single-shot), "wrap codex exec in a timeout" is mechanical and always
correct, so this hook actually blocks instead of just reminding.

See memory feedback_gpt56_codex_exec_dispatch_reliability for the full
timeout+retry+scavenge pattern this enforces the first step of.
"""

from __future__ import annotations

import json
import os
import shlex
import sys

OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", "&&&", "\n"}
KEYWORDS = {"then", "do", "else", "elif", "fi", "done", "{", "}", "!", "time"}
WRAPPERS = {
    "sudo", "doas", "env", "command", "nohup", "nice", "ionice",
    "stdbuf", "builtin", "exec", "setsid", "timeout", "eval",
}


def command_segments(command: str) -> list[list[str]]:
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
        lex.whitespace = " \t\r"
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        return []  # fail open, matching the other hooks

    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in OPERATORS or token in KEYWORDS:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(token)
    if current:
        segments.append(current)
    return segments


def skip_wrapper_options(words: list[str], index: int, wrapper: str) -> int:
    options_with_value = {
        "sudo": {"-u", "-g", "-h", "-p", "-C", "-T", "-R", "-D",
                 "--user", "--group", "--host", "--prompt", "--chdir",
                 "--chroot", "--role", "--type", "--other-user"},
        "doas": {"-u", "-C"},
        "env": {"-u", "-C", "-S", "--unset", "--chdir", "--split-string"},
        "timeout": {"-s", "-k", "--signal", "--kill-after"},
        "nice": {"-n", "--adjustment"},
        "ionice": {"-c", "-n", "-t", "-u", "-P"},
        "stdbuf": {"-i", "-o", "-e"},
    }.get(wrapper, set())

    while index < len(words) and words[index].startswith("-"):
        option = words[index]
        if option == "--":
            return index + 1
        bare_option = option.split("=", 1)[0]
        index += 1
        if bare_option in options_with_value and "=" not in option and index < len(words):
            index += 1
    return index


def peel(words: list[str]) -> tuple[list[str], str, bool]:
    """Strip assignments/wrappers and report whether timeout wrapped the command."""
    index = 0
    bounded = False
    while index < len(words):
        word = words[index]
        if "=" in word and not word.startswith("=") and "/" not in word.split("=")[0]:
            index += 1
            continue
        name = os.path.basename(word.lstrip("\\"))
        if name not in WRAPPERS:
            break
        index += 1
        index = skip_wrapper_options(words, index, name)
        if name == "timeout":
            bounded = True
            if index < len(words) and not words[index].startswith("-"):
                index += 1  # duration operand
    argv = words[index:]
    if not argv:
        return [], "", bounded
    return argv, os.path.basename(argv[0].lstrip("\\")), bounded


def has_unbounded_codex_exec(command: str) -> bool:
    for segment in command_segments(command):
        argv, name, bounded = peel(segment)
        if name == "codex" and "exec" in argv[1:] and not bounded:
            return True
    return False


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # fail open

    if payload.get("tool_name") != "Bash":
        return 0

    command = str((payload.get("tool_input") or {}).get("command", ""))
    if not has_unbounded_codex_exec(command):
        return 0

    print(
        "codex exec must be wrapped in a bounded timeout before this command can run -- "
        "it has a confirmed failure mode of hanging with zero output for hours (one "
        "instance sat stuck 4.5+ hours undetected in a live session). Rewrap this exact "
        "command with `timeout 900 codex exec ...` (or another explicit bound appropriate "
        "to the task), and after it returns check that real output actually grew, not just "
        "that the exit code was 0 -- an empty/unchanged output with exit 0 is still a "
        "stall. Retry up to 3 times on a stall, killing any leftover process each time, "
        "before reporting failure honestly. Scavenge real substantive output from a messy "
        "or stalled attempt rather than discarding it.",
        file=sys.stderr,
    )
    return 2  # block: Claude sees this stderr and must adjust the command


if __name__ == "__main__":
    sys.exit(main())
