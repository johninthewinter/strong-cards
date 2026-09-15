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
import re
import sys

CODEX_EXEC = re.compile(r"\bcodex exec\b")
HAS_TIMEOUT = re.compile(r"\btimeout\s+\d")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # fail open

    if payload.get("tool_name") != "Bash":
        return 0

    command = str((payload.get("tool_input") or {}).get("command", ""))
    if not CODEX_EXEC.search(command):
        return 0
    if HAS_TIMEOUT.search(command):
        return 0  # already wrapped, fine

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
