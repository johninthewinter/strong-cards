#!/usr/bin/env bash
# PreToolUse / Bash — hard-block direct deletion. Deletion is replaced by
# sc-trash.sh (reviewable move-to-trash + PostToolUse double verification).
#
# Exit 2 is Claude Code's blocking contract; stderr becomes the tool denial reason.
#
# Design notes (why this shape):
#  - Naive substring matching on "rm" both over-blocks (`npm run rm-cache`,
#    `grep "rm -rf" audit.log`) and under-blocks (`sudo  /bin/rm  -rf x`,
#    `xargs rm`, `\rm`). So the real decision is made on a TOKENIZED argv:
#    the command is split with Python's shlex (posix, punctuation_chars=True),
#    segmented on shell operators, wrapper words are peeled, and only the
#    resolved argv[0] of each simple command is judged.
#  - A redundant raw-regex catastrophic check runs FIRST, before tokenization,
#    so `rm -rf /` style commands are blocked even if tokenization fails or a
#    future refactor breaks the parser (defense in depth, per the task spec).
#  - Missing jq / python3 fails OPEN, matching every other hook here: a hook
#    must never wedge every Bash call on this machine. That is a deliberate
#    availability-over-enforcement tradeoff, documented in TRASH-README.md.

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)
TRASH_TOOL="$SCRIPT_DIR/sc-trash.sh"

# ---------------------------------------------------------------------------
# Layer 1 — redundant catastrophic-pattern check (raw text, no tokenization).
# Intentionally loud and intentionally overlapping with Layer 2.
# ---------------------------------------------------------------------------
CATASTROPHIC=""
if printf '%s' "$CMD" | grep -qE '(^|[^[:alnum:]_.-])r?m?[[:space:]]*--no-preserve-root'; then
  CATASTROPHIC="--no-preserve-root present"
elif printf '%s' "$CMD" \
  | grep -qE '(^|[^[:alnum:]_./-])\\?rm[[:space:]]+(-[[:alnum:]-]+[[:space:]]+)*(/|/\*|~|~/\*|\$HOME|"\$HOME"|\$\{HOME\})([[:space:]]|/\*|$)'; then
  CATASTROPHIC="root- or home-level recursive removal target"
fi

if [ -n "$CATASTROPHIC" ]; then
  cat >&2 <<EOF
######################################################################
##  CATASTROPHIC DELETE BLOCKED — SC DELETE GUARD                    ##
######################################################################

Reason: $CATASTROPHIC
Command: $CMD

This command could destroy the user's machine or home directory. It is
refused unconditionally. Do not rewrite it, do not split it across calls,
do not route it through a subshell or another tool. Stop and tell the user
exactly what you were about to run and why.
EOF
  exit 2
fi

# ---------------------------------------------------------------------------
# Layer 2 — tokenized argv analysis.
# ---------------------------------------------------------------------------
PY_VERDICT=$(python3 - "$CMD" <<'PYEOF' 2>/dev/null
import os, shlex, subprocess, sys

cmd = sys.argv[1]

OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", "&&&", "\n"}
KEYWORDS = {"then", "do", "else", "elif", "fi", "done", "{", "}", "!", "time"}
# Words that prefix a real command without being the command.
WRAPPERS = {"sudo", "doas", "env", "command", "nohup", "nice", "ionice",
            "stdbuf", "builtin", "exec", "setsid", "timeout", "eval"}

def fail(reason, detail=""):
    print("BLOCK")
    print(reason)
    print(detail)
    sys.exit(0)

try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except Exception:
    # Tokenization failed (unbalanced quotes, exotic syntax). Fall back to a
    # conservative boundary regex: block if a deletion verb appears as a word.
    import re
    if re.search(r'(^|[^\w./-])\\?(rm|shred|srm|truncate)([\s]|$)', cmd) or \
       re.search(r'(^|[^\w./-])git\s+clean(\s|$)', cmd):
        fail("unparseable command containing a deletion verb",
             "Tokenization failed, so this is refused conservatively.")
    print("ALLOW"); sys.exit(0)

# Split into simple-command segments.
segments, cur = [], []
for t in tokens:
    if t in OPERATORS or t in KEYWORDS:
        if cur: segments.append(cur)
        cur = []
    else:
        cur.append(t)
if cur: segments.append(cur)

def peel(words):
    """Strip env assignments and wrapper words; return (argv, name)."""
    i = 0
    while i < len(words):
        w = words[i]
        if "=" in w and not w.startswith("=") and "/" not in w.split("=")[0]:
            i += 1; continue
        base = os.path.basename(w.lstrip("\\"))
        if base in WRAPPERS:
            i += 1
            # skip wrapper's own flags (e.g. timeout 30s, nice -n 5)
            while i < len(words) and words[i].startswith("-"):
                i += 1
            if base == "timeout" and i < len(words) and not words[i].startswith("-"):
                i += 1  # the duration operand
            continue
        break
    argv = words[i:]
    if not argv:
        return [], ""
    return argv, os.path.basename(argv[0].lstrip("\\"))

def git_result(worktree, *args):
    """Run a bounded, read-only git query in worktree."""
    try:
        return subprocess.run(
            ["git", *args], cwd=worktree, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=5, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

def existing_worktree(path):
    """Resolve path only when it is the root of a live Git worktree."""
    resolved = os.path.realpath(os.path.abspath(os.path.expanduser(path)))
    if not os.path.isdir(resolved):
        return None
    inside = git_result(resolved, "rev-parse", "--is-inside-work-tree")
    top = git_result(resolved, "rev-parse", "--show-toplevel")
    if not inside or inside.returncode != 0 or inside.stdout.strip() != "true":
        return None
    if not top or top.returncode != 0:
        return None
    if os.path.realpath(top.stdout.strip()) != resolved:
        return None
    return resolved

def worktree_is_clean_and_merged(worktree):
    status = git_result(worktree, "status", "--porcelain", "--untracked-files=all")
    clean = bool(status and status.returncode == 0 and not status.stdout.strip())

    # A removable card worktree is merged only when HEAD is already reachable
    # from the project's integration ref. Prefer local main/master; origin/HEAD
    # is a fallback when the repository exposes its default branch only there.
    refs = []
    for ref in ("refs/heads/main", "refs/heads/master"):
        probe = git_result(worktree, "show-ref", "--verify", "--quiet", ref)
        if probe and probe.returncode == 0:
            refs.append(ref)
    if not refs:
        remote_head = git_result(
            worktree, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"
        )
        if remote_head and remote_head.returncode == 0 and remote_head.stdout.strip():
            refs.append(remote_head.stdout.strip())

    merged = False
    for ref in refs:
        ancestry = git_result(worktree, "merge-base", "--is-ancestor", "HEAD", ref)
        if ancestry and ancestry.returncode == 0:
            merged = True
            break
    return clean, merged

def positional_args(args):
    """Return operands after stripping flags, respecting `--`."""
    operands, after_separator = [], False
    for arg in args:
        if not after_separator and arg == "--":
            after_separator = True
        elif not after_separator and arg.startswith("-"):
            continue
        else:
            operands.append(arg)
    return operands

GLOB = set("*?[")

for words in segments:
    # Separate redirections from command words for this segment.
    cmdwords, redirect_ops = [], []
    j = 0
    while j < len(words):
        w = words[j]
        if w in (">", ">|", ">>", "<", "<<", "<<<"):
            redirect_ops.append(w)
            j += 2  # skip the target operand
            continue
        if w.isdigit() and j + 1 < len(words) and words[j + 1] in (">", ">>", ">|"):
            j += 1
            continue
        cmdwords.append(w)
        j += 1

    argv, name = peel(cmdwords)

    # ---- pure truncation via `> file` (see TRASH-README for the tradeoff) ----
    if ">" in redirect_ops or ">|" in redirect_ops:
        rest = argv[1:] if argv else []
        noop = (
            not argv
            or name in (":", "true")
            or (name == "cat" and rest == ["/dev/null"])
            or (name in ("echo", "printf")
                and all(a in ("-n", "", '""', "''", "%s") for a in rest))
        )
        if noop:
            fail("destructive truncation via `>` with no content-producing command",
                 "Emptying an existing file is deletion of its contents.")

    if not argv:
        continue

    # sc-trash.sh itself is the sanctioned path — never block it.
    if name == "sc-trash.sh":
        continue

    # ---- xargs: judge the command it will run ----
    if name == "xargs":
        k = 1
        while k < len(argv) and argv[k].startswith("-"):
            k += 2 if argv[k] in ("-n", "-P", "-I", "-L", "-s", "-E", "-d") else 1
        if k < len(argv):
            argv, name = argv[k:], os.path.basename(argv[k].lstrip("\\"))
        else:
            continue

    # ---- rm (any form) ----
    if name == "rm":
        fail("`rm` is not permitted for any agent on this machine",
             "Every removal goes through the trash workflow instead.")

    if name in ("shred", "srm"):
        fail("`%s` irreversibly destroys file contents" % name, "")

    if name == "truncate":
        fail("`truncate` zeroes a file, which is deletion of its contents", "")

    # ---- destructive git operations ----
    if name == "git":
        sub = [a for a in argv[1:] if not a.startswith("-")]
        if not sub:
            continue
        git_sub = sub[0]
        sub_idx = argv.index(git_sub, 1)
        args = argv[sub_idx + 1:]

        if git_sub == "clean":
            fail("`git clean` deletes untracked files with no recovery path",
                 "Use `git status --porcelain` to list them, then sc-trash.sh.")

        if git_sub == "branch":
            force_delete = "-D" in args or (
                "--delete" in args and "--force" in args
            )
            if force_delete:
                fail("`git branch -D` force-deletes a branch with no recovery path",
                     "Use `git branch` without `-D`, or get explicit user confirmation of the loss.")

        if git_sub == "reset" and "--hard" in args:
            fail("`git reset --hard` irrecoverably discards uncommitted changes",
                 "Use `git stash` or `git reset --soft`/`--mixed`, or get explicit user confirmation.")

        if git_sub == "checkout" and "--" in args:
            separator = args.index("--")
            if args[separator + 1:]:
                fail("`git checkout -- <path>` irrecoverably discards uncommitted path changes",
                     "Use `git stash` first, or get explicit user confirmation of the loss.")

        if git_sub == "restore" and "--staged" not in args and positional_args(args):
            fail("`git restore <path>` irrecoverably discards uncommitted path changes",
                 "Use `git stash` first, or get explicit user confirmation of the loss.")

        if git_sub == "stash":
            stash_ops = positional_args(args)
            if stash_ops and stash_ops[0] in ("drop", "clear"):
                fail("`git stash %s` permanently deletes stashed work with no recovery path" % stash_ops[0],
                     "Use `git stash list` first, or get explicit user confirmation of the loss.")

        if git_sub == "worktree":
            worktree_ops = positional_args(args)
            if worktree_ops and worktree_ops[0] == "remove" and len(worktree_ops) > 1:
                target = existing_worktree(worktree_ops[-1])
                if target:
                    clean, merged = worktree_is_clean_and_merged(target)
                    if not (clean and merged):
                        state = "dirty" if not clean else "clean but not merged into main/master"
                        fail("`git worktree remove` target is not clean and merged (%s)" % state,
                             "Move uncommitted content first with sibling `./sc-trash.sh <path>`; otherwise only the user should re-run after clearly confirming the loss.")

    # ---- find ... -delete / -exec rm / -ok rm ----
    if name in ("find", "fd"):
        for idx, a in enumerate(argv[1:], start=1):
            if a == "-delete":
                fail("`find -delete` deletes matches directly", "")
            if a in ("-exec", "-execdir", "-ok", "-okdir", "-x", "--exec"):
                nxt = argv[idx + 1] if idx + 1 < len(argv) else ""
                if os.path.basename(nxt.lstrip("\\")) in ("rm", "shred", "srm", "truncate"):
                    fail("`find %s %s` deletes matches directly" % (a, nxt), "")

    # ---- mv to /dev/null (deletion disguised as a move) ----
    if name == "mv":
        operands = [a for a in argv[1:] if not a.startswith("-")]
        if operands and operands[-1] == "/dev/null":
            fail("`mv ... /dev/null` destroys the file",
                 "`mv` itself is allowed; /dev/null as a destination is not.")

print("ALLOW")
PYEOF
)

VERDICT=$(printf '%s\n' "$PY_VERDICT" | sed -n '1p')
[ "$VERDICT" = "BLOCK" ] || exit 0

REASON=$(printf '%s\n' "$PY_VERDICT" | sed -n '2p')
DETAIL=$(printf '%s\n' "$PY_VERDICT" | sed -n '3p')

printf 'SC DELETE GUARD — command blocked. No agent deletes files on this machine.\n\n' >&2
printf 'Reason:  %s\n' "$REASON" >&2
[ -n "$DETAIL" ] && printf 'Detail:  %s\n' "$DETAIL" >&2
printf 'Command: %s\n' "$CMD" >&2

cat >&2 <<EOF

USE THIS INSTEAD — the only sanctioned removal path:

  "$TRASH_TOOL" <path> [<path>...]

It moves each path into ~/.claude/trash/<date>/<time>-<basename>/ with a
sha256 manifest, and a PostToolUse hook then re-hashes the trashed copy and
confirms the original slot is empty. Nothing is ever destroyed; only the
user empties the trash, by hand, in their own terminal.

If you believe this command is genuinely non-destructive and was misjudged,
do NOT work around the guard. Say so to the user and let them decide.
EOF
exit 2
