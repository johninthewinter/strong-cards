#!/usr/bin/env bash
# PreToolUse / Bash — pi broker interactive-only guard.
#
# BLOCKS any Bash command that launches `pi` with `-p`/`--print` (non-interactive,
# one-shot, no visibility, no way to intervene mid-run). The `pi` broker (caveman
# compression proxy + local Qwen via mtplx) exists so the user can watch and steer the
# local-model coder session live — a headless `--print` run defeats that completely.
#
# Why this is a hard block, not a reminder: on 2026-08-16 the same mistake (dispatching
# `pi --print ... &` to a background log file nobody watched) was made TWICE in one
# session, including once immediately after being corrected and saving a memory about
# it. A memory note is advisory only and gets skipped under task pressure; this hook
# makes the mistake physically impossible instead of merely discouraged.
#
# See also: memory feedback_pi_broker_interactive_only.md (same repo, deeper rationale).

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # no jq: fail open, never wedge the session

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Only look at commands that actually invoke `pi` (word boundary via space/start), not
# every substring match (avoids false positives on unrelated words containing "pi").
case "$CMD" in
  *"pi "*|*"pi\t"*|*=pi\ *) ;;
  pi\ *) ;;
  *)
    # Also catch `caveman run -- pi ...` and similar wrapper shapes.
    case "$CMD" in
      *"-- pi "*) ;;
      *) exit 0 ;;
    esac
    ;;
esac

# The actual trigger: -p or --print anywhere in a command that also runs pi.
case "$CMD" in
  *" pi "*"--print"*|*" pi "*" -p "*|*"-- pi "*"--print"*|*"-- pi "*" -p "*)
    printf 'PI BROKER INTERACTIVE GUARD — command blocked.\n\n' >&2
    printf 'This command runs `pi` with `--print`/`-p` — non-interactive, one-shot, no\n' >&2
    printf 'visibility, no way for the user to watch or intervene mid-run.\n\n' >&2
    printf 'The pi broker (caveman + local Qwen via mtplx) exists specifically so the user\n' >&2
    printf 'can see and control the local-model coder session live. Corrected twice on\n' >&2
    printf '2026-08-16 in the same session — this hook exists so it cannot happen a third\n' >&2
    printf 'time.\n\n' >&2
    printf 'Required instead: use Pi Broker, /Users/misterj/src/Pi_Broker — it opens a REAL,\n' >&2
    printf 'visible interactive `pi` TUI window on the users screen (no -p/--print anywhere\n' >&2
    printf 'in its own architecture) and lets you drive it programmatically over a socket:\n\n' >&2
    printf '  cd /Users/misterj/src/Pi_Broker && bash scripts/quickstart.sh 1\n' >&2
    printf '  # opens one titled terminal window the user can see and type into\n' >&2
    printf '  npm exec -- pi-broker prompt <socket-from-quickstart-output> session-1 "<card prompt text>"\n' >&2
    printf '  npm exec -- pi-broker list <socket>      # confirm the session is up\n\n' >&2
    printf 'Do NOT reach for tmux, a headless background run, or asking the user to run pi\n' >&2
    printf 'themselves — Pi Broker already exists for exactly this and is the required path.\n' >&2
    exit 2
    ;;
esac

exit 0
