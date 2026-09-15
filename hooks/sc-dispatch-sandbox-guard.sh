#!/usr/bin/env bash
# PreToolUse / Bash — Strong Card sandbox guard (RULES §3, §2).
#
# BLOCKS a coder dispatch whose working directory is not a dedicated git worktree.
# This is the one hook that enforces rather than reminds: exit 2 on a PreToolUse hook
# prevents the tool call from running at all, and stderr is fed back to Claude as the reason.
#
# Why: on 2026-08-10 `opencode run --dir <repo-root>` gave a local coder write access to the
# entire working tree. It left its 2-file touch list and deleted a shipped, SIGKILL-tested
# production module. Nothing was revertable — the tree was untracked.
#
# Four dispatch shapes are supported, because they express the sandbox boundary differently:
#   - opencode: a `--dir`/`--cwd` FLAG on the dispatch command itself.
#   - pi (2026-08-11 onward, RULES §9): pi has NO --dir/--cwd flag at all (confirmed against
#     `pi --help`). Its cwd is whatever the shell was in when it ran — either a `cd <path> &&`
#     prefix in the SAME command, or (if the operator already `cd`'d in an earlier call) the
#     PreToolUse hook's own `.cwd` field. Both are checked below.
#   - sbx (2026-09-11 onward): opencode2 has NO --dir/--cwd flag at all (confirmed against
#     `opencode2 run --help`, v0.0.0-beta-19234 — its positionals are the MESSAGE). When the
#     dispatch goes through `sbx exec`, the container's mount IS the boundary — strictly
#     stronger than a --dir flag, since it's a whole separate filesystem namespace, not just
#     a working-directory pointer — and `-w/--workdir` names it.
#   - codex (2026-09-15 onward, SC-03): `codex exec` is the dispatch route the codex-gpt
#     Agent actually uses, and it was unguarded until now. Per the resolved -C rule
#     (see ~/.claude/agents/codex-gpt.md), the operator EnterWorktree's first and codex
#     inherits that cwd with NO path flag — so the hook's own `.cwd` is the boundary.
#     A `-C`/`--cd` flag, if one is passed anyway, is honoured as the stated directory,
#     but is never TRUSTED: whichever directory we end up with is verified below against
#     `--absolute-git-dir` vs `--git-common-dir` — a real linked-worktree test, not a
#     claim in the command string.

set -uo pipefail

INPUT=$(cat)

# --- fail CLOSED on a missing dependency (SC-03) --------------------------------
# Without jq we cannot parse .tool_input.command, so we cannot tell a dispatch from a
# plain `ls`. Exiting 0 here (the pre-2026-09-15 behaviour) silently disabled the guard
# for every dispatch. Exiting 2 unconditionally would wedge EVERY Bash call on the
# machine. So: degrade to a raw-text scan of the hook payload and block anything that
# looks like a dispatch, with an explicit reason. Unguardable dispatches are refused;
# ordinary commands still run.
if ! command -v jq >/dev/null 2>&1; then
  case "$INPUT" in
    *"opencode run"*|*"opencode2 run"*|*"claude-local -p"*|*"strong-card-runner"*|\
    *"pi -p"*|*"pi --print"*|*"codex exec"*)
      printf 'STRONG CARD SANDBOX GUARD — dispatch blocked (RULES §3).\n\n%s\n' \
        "\`jq\` is not on PATH, so this hook cannot parse the tool payload and cannot verify
that this dispatch targets a dedicated git worktree. The guard fails CLOSED: an
unverifiable dispatch is refused rather than silently permitted.

Fix: install jq (\`brew install jq\`), then re-run the dispatch." >&2
      exit 2 ;;
    *) exit 0 ;;
  esac
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Is this a coder dispatch? Tokenization-aware (mirrors sc-delete-guard.sh's Layer 2:
# shlex-tokenize, split on shell operators into simple-command segments, peel wrapper
# words, then judge only argv[0]/argv[1] of each segment) instead of a bare substring
# case match. A bare substring match false-triggers when a dispatch keyword is merely
# quoted inside an unrelated read-only command -- e.g. `cat` or `grep` on a file whose
# text quotes this guard's own example dispatch lines back (reproduced live 2026-09-15
# while auditing this very hook; see docs/reviews/2026-09-15-global-hooks-audit/report.md
# section 2.6.2). Falls back to the previous substring behaviour only if python3 is
# missing (degrade, don't wedge every Bash call over a missing interpreter).
SHAPE=$(
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CMD" <<'PYEOF' 2>/dev/null
import os, shlex, sys

cmd = sys.argv[1]
OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", "&&&", "\n"}
KEYWORDS = {"then", "do", "else", "elif", "fi", "done", "{", "}", "!", "time"}
WRAPPERS = {"sudo", "doas", "env", "command", "nohup", "nice", "ionice",
            "stdbuf", "builtin", "exec", "setsid", "timeout", "eval"}

try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    tokens = list(lex)
except Exception:
    print("PARSE_FAILED")
    sys.exit(0)

segments, cur = [], []
for t in tokens:
    if t in OPERATORS or t in KEYWORDS:
        if cur:
            segments.append(cur)
        cur = []
    else:
        cur.append(t)
if cur:
    segments.append(cur)

def peel(words):
    i = 0
    while i < len(words):
        w = words[i]
        if "=" in w and not w.startswith("=") and "/" not in w.split("=")[0]:
            i += 1
            continue
        base = os.path.basename(w.lstrip("\\"))
        if base in WRAPPERS:
            i += 1
            while i < len(words) and words[i].startswith("-"):
                i += 1
            if base == "timeout" and i < len(words) and not words[i].startswith("-"):
                i += 1
            continue
        break
    argv = words[i:]
    if not argv:
        return [], ""
    return argv, os.path.basename(argv[0].lstrip("\\"))

def first_positional(rest):
    for a in rest:
        if not a.startswith("-"):
            return a
    return ""

shapes = []
for words in segments:
    argv, name = peel(words)
    if not argv:
        continue
    rest = argv[1:]
    if name in ("opencode", "opencode2") and first_positional(rest) == "run":
        shapes.append("DISPATCH")
    elif name == "claude-local" and rest[:1] == ["-p"]:
        shapes.append("DISPATCH")
    elif name == "strong-card-runner":
        shapes.append("DISPATCH")
    elif name == "pi" and rest[:1] and rest[0] in ("-p", "--print"):
        shapes.append("IS_PI")
    elif name == "codex" and first_positional(rest) == "exec":
        shapes.append("IS_CODEX")
    elif name == "sbx" and first_positional(rest) == "exec":
        shapes.append("IS_SBX")

if shapes:
    print(",".join(shapes))
else:
    print("NONE")
PYEOF
  else
    printf 'NO_PYTHON3\n'
  fi
)

IS_PI=0
IS_SBX=0
IS_CODEX=0
case "$SHAPE" in
  NO_PYTHON3|PARSE_FAILED)
    # Degrade to the previous substring behaviour rather than wedge every Bash call.
    case "$CMD" in
      *"opencode run"*|*"opencode2 run"*|*"claude-local -p"*|*"strong-card-runner"*) ;;
      *"pi -p"*|*"pi --print"*) IS_PI=1 ;;
      *"codex exec"*) IS_CODEX=1 ;;
      *) exit 0 ;;
    esac
    case "$CMD" in *"sbx exec"*) IS_SBX=1 ;; esac
    ;;
  NONE)
    exit 0
    ;;
  *)
    case "$SHAPE" in *IS_PI*) IS_PI=1 ;; esac
    case "$SHAPE" in *IS_CODEX*) IS_CODEX=1 ;; esac
    case "$SHAPE" in *IS_SBX*) IS_SBX=1 ;; esac
    ;;
esac

# Read-only / help invocations are not dispatches.
case "$CMD" in *" --help"*|*" -h "*|*"--list-models"*|*"--version"*|*" -v "*) exit 0 ;; esac

block() {
  printf 'STRONG CARD SANDBOX GUARD — dispatch blocked (RULES §3).\n\n%s\n\n' "$1" >&2
  cat >&2 <<'EOF'
Required shape:

  git -C <repo> worktree add ../.wt/card-<slug> -b card/<slug>

  # opencode:
  opencode run --dir ../.wt/card-<slug> ... -f <card-file>

  # pi (no --dir flag — the cwd IS the boundary, so cd into it explicitly):
  cd ../.wt/card-<slug> && pi -p "$(cat <card-file>)" --provider <name> --model <id>

  # sbx (containerised — opencode2 has no --dir flag either):
  sbx exec -w /abs/path/to/worktree <sandbox> opencode2 run --model <id> "..."

  # codex (no -C — EnterWorktree into the worktree first; the inherited cwd IS the
  # boundary, and this guard verifies it is a real linked worktree):
  codex exec -m <model-id> -c model_reasoning_effort=<effort> --sandbox workspace-write "..."

Then BEFORE merging, review the whole tree, not just the expected files:

  git -C ../.wt/card-<slug> status --porcelain   # deletions + untracked
  git -C ../.wt/card-<slug> diff --stat          # compare against the card's Touch List

Then: commit inside the worktree, `git merge card/<slug> --no-edit`, `git worktree remove`.

If the tree is not under git yet, commit a baseline FIRST (RULES §2.1) — recovery from an
out-of-scope worker without git history is luck, not process.
EOF
  exit 2
}

HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

if [ "$IS_SBX" = "1" ]; then
  # opencode2 has no --dir/--cwd flag at all. Through `sbx exec`, the container's mount
  # IS the boundary (strictly stronger than a --dir flag: a whole separate filesystem
  # namespace, not just a working-directory pointer) — `-w/--workdir` names it.
  DIR=$(printf '%s' "$CMD" \
    | grep -oE -- '(-w|--workdir)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
    | head -n1 | sed -E 's/^(-w|--workdir)[= ]+//' | tr -d "\"'")
  # A --dir flag (opencode v1 inside the sandbox) is equally valid.
  [ -n "$DIR" ] || DIR=$(printf '%s' "$CMD" \
    | grep -oE -- '--(dir|cwd)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
    | head -n1 | sed -E 's/^--(dir|cwd)[= ]+//' | tr -d "\"'")
  [ -n "$DIR" ] || block "sbx dispatch declares neither -w/--workdir nor --dir, so the worker
runs in the container's default cwd rather than in the mounted worktree. Launch it as:
  sbx exec -w /abs/path/to/worktree <sandbox> opencode2 run --model <id> \"...\""
elif [ "$IS_CODEX" = "1" ]; then
  # codex exec. Standing rule: no -C — EnterWorktree first, inherit the cwd. So the
  # hook's own .cwd is normally the boundary. A leading `cd <path> &&`, or a -C/--cd
  # flag if one is passed anyway, names it instead. Whatever we resolve is VERIFIED
  # below as a real linked worktree; nothing here is taken on trust.
  # Only scan the argv AFTER `codex exec`, and tokenize it the way a shell would
  # (`xargs -n1` honours quoting), so the PROMPT collapses into a single token and a
  # `git -C <path>` written inside that prompt cannot be mistaken for codex's own
  # directory flag. Malformed quoting yields no token list — DIR stays empty and we
  # fall through to the cwd, which is still verified below.
  CODEX_TAIL=${CMD#*codex exec}
  DIR=$(printf '%s' "$CODEX_TAIL" | xargs -n1 2>/dev/null | awk '
    /^(-C|--cd)$/            { take=1; next }
    take                     { print; exit }
    /^(-C|--cd)=/            { sub(/^(-C|--cd)=/, ""); print; exit }
  ')
  [ -n "$DIR" ] || DIR=$(printf '%s' "$CMD" \
    | grep -oE '^[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]&;]+)' \
    | head -n1 | sed -E 's/^[[:space:]]*cd[[:space:]]+//' | tr -d "\"'")
  if [ -z "$DIR" ]; then
    DIR="$HOOK_CWD"
    [ -n "$DIR" ] || block "codex exec dispatch: the hook could not read a cwd, and the command
names no directory either, so the worktree this worker will write in is unknowable.
EnterWorktree into a dedicated worktree first, then dispatch:
  codex exec -m <model> --sandbox workspace-write \"...\"   # no -C, cwd is the boundary"
  fi
elif [ "$IS_PI" = "1" ]; then
  # pi has no --dir flag. The boundary is whatever directory it actually runs in: a `cd
  # <path> &&`/`cd <path>;` prefix in this same command, or (if absent) the hook's own cwd —
  # which is only safe when the operator already `cd`'d into the worktree in a PRIOR call.
  DIR=$(printf '%s' "$CMD" \
    | grep -oE '^[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]&;]+)' \
    | head -n1 | sed -E 's/^[[:space:]]*cd[[:space:]]+//' | tr -d "\"'")
  if [ -z "$DIR" ]; then
    DIR="$HOOK_CWD"
    [ -n "$DIR" ] || block "pi dispatch has no leading 'cd <worktree> &&' and the hook could
not read a cwd either. pi has no --dir flag (confirmed: not in \`pi --help\`) — its sandbox
boundary IS its working directory. Launch it as:
  cd ../.wt/card-<slug> && pi -p \"...\" --provider <name> --model <id>"
  fi
else
  # Extract --dir / --cwd value (supports `--dir X` and `--dir=X`).
  DIR=$(printf '%s' "$CMD" \
    | grep -oE -- '--(dir|cwd)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
    | head -n1 | sed -E 's/^--(dir|cwd)[= ]+//' | tr -d "\"'")
  [ -n "$DIR" ] || block "This dispatch declares no --dir, so the worker inherits the session's
working directory — i.e. the main repo. Unbounded write access."
fi

# Resolve relative to the tool call's cwd.
case "$DIR" in
  /*) ABS="$DIR" ;;
  *)  ABS="${HOOK_CWD:-$PWD}/$DIR" ;;
esac
ABS=$(cd "$ABS" 2>/dev/null && pwd) || block "dispatch working directory does not exist: $DIR"

git -C "$ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || block "dispatch working directory is not inside a git repository: $ABS
An untracked tree has no revert path (RULES §2.1)."

# A linked worktree's .git is a FILE ('gitdir: ...'), and its git-dir differs from the
# common git-dir. The primary working tree fails both — which is exactly what we block.
GITDIR=$(git -C "$ABS" rev-parse --absolute-git-dir 2>/dev/null)
COMMON=$(git -C "$ABS" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

if [ -z "$GITDIR" ] || [ "$GITDIR" = "$COMMON" ]; then
  block "dispatch working directory points at the PRIMARY working tree, not a dedicated worktree:
  $ABS
A worker pointed here can modify, stub, or delete ANY file in the repo, regardless of what
the card's Touch List says. The Touch List is prose; the worktree is the boundary."
fi

# Dirty worktree at dispatch time makes the post-run diff unreadable — you cannot tell the
# worker's changes from what was already there.
if [ -n "$(git -C "$ABS" status --porcelain 2>/dev/null)" ]; then
  printf 'STRONG CARD: worktree %s is dirty at dispatch time. Commit or stash first — otherwise the post-dispatch `git diff --stat` cannot distinguish the worker'"'"'s changes from pre-existing ones, and RULES §3.3 verification is meaningless.\n' "$ABS" >&2
  exit 2
fi

exit 0
