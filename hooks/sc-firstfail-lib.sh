#!/usr/bin/env bash
# Shared helpers for the Strong Card first-failure PostToolUse and PreToolUse hooks.
# Keep path resolution and lock naming in one place: if those halves disagree, the
# apparent enforcement is only a reminder again.

sc_ff_state_dir() (
  scff_tmp_root=${TMPDIR:-/tmp}
  [ "$scff_tmp_root" = "/" ] || scff_tmp_root=${scff_tmp_root%/}
  scff_dir=${SC_FIRSTFAIL_STATE_DIR:-"$scff_tmp_root/strong-card-firstfail-$(id -u)"}

  umask 077
  if [ -e "$scff_dir" ] && [ ! -d "$scff_dir" ]; then
    return 1
  fi
  mkdir -p "$scff_dir" 2>/dev/null || return 1
  chmod 700 "$scff_dir" 2>/dev/null || return 1
  printf '%s\n' "$scff_dir"
)

sc_ff_hash() (
  scff_value=$1
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$scff_value" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$scff_value" | sha256sum | awk '{print $1}'
  else
    # macOS ships shasum. This fallback preserves function on unusual hosts, while
    # the worktree stored inside each lock still detects a key collision.
    printf '%s' "$scff_value" | cksum | awk '{print $1 "-" $2}'
  fi
)

sc_ff_lock_path() (
  scff_worktree=$1
  scff_dir=$(sc_ff_state_dir) || return 1
  scff_key=$(sc_ff_hash "$scff_worktree") || return 1
  [ -n "$scff_key" ] || return 1
  printf '%s/sc-firstfail-%s.json\n' "$scff_dir" "$scff_key"
)

# Extract the directory the command targets. Dispatch directory flags win over a
# leading cd because a harness can itself be launched from some unrelated directory.
sc_ff_command_dir() (
  scff_cmd=$1
  scff_hook_cwd=$2
  scff_dir=""

  scff_dir=$(printf '%s' "$scff_cmd" \
    | grep -oE -- '--(dir|cwd|directory)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
    | head -n1 | sed -E 's/^--(dir|cwd|directory)[= ]+//' | tr -d "\"'" || true)

  if [ -z "$scff_dir" ]; then
    scff_dir=$(printf '%s' "$scff_cmd" \
      | grep -oE '^[[:space:]]*\(?[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]&;]+)' \
      | head -n1 | sed -E 's/^[[:space:]]*\(?[[:space:]]*cd[[:space:]]+//' | tr -d "\"'" || true)
  fi

  if [ -z "$scff_dir" ]; then
    scff_dir=$(printf '%s' "$scff_cmd" \
      | grep -oE -- '(^|[[:space:]])-C[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
      | head -n1 | sed -E 's/^[[:space:]]*-C[= ]+//' | tr -d "\"'" || true)
  fi

  [ -n "$scff_dir" ] || scff_dir=$scff_hook_cwd
  [ -n "$scff_dir" ] || scff_dir=$PWD
  printf '%s\n' "$scff_dir"
)

# Canonicalize to the Git worktree root, so pytest launched from a package subdirectory
# and pytest launched from the root share one lock. Non-Git directories use their real path.
sc_ff_canonical_path() (
  scff_path=$1
  scff_base=${2:-$PWD}

  case "$scff_path" in
    /*) scff_abs=$scff_path ;;
    *)  scff_abs=$scff_base/$scff_path ;;
  esac

  scff_abs=$(CDPATH= cd "$scff_abs" 2>/dev/null && pwd -P) || return 1
  scff_top=$(git -C "$scff_abs" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$scff_top" ]; then
    scff_abs=$(CDPATH= cd "$scff_top" 2>/dev/null && pwd -P) || return 1
  fi
  printf '%s\n' "$scff_abs"
)

sc_ff_worktree_for_command() (
  scff_cmd=$1
  scff_hook_cwd=$2
  scff_candidate=$(sc_ff_command_dir "$scff_cmd" "$scff_hook_cwd") || return 1
  sc_ff_canonical_path "$scff_candidate" "${scff_hook_cwd:-$PWD}"
)

# Deliberately conservative while a lock is active: any explicit pytest/py.test execution
# counts as another suite-shaped invocation, including python -m pytest and common run
# wrappers. We do not match a mere argument to rg/grep/printf, which would block inspection.
# Focused selectors still count: RULES §4 says judgment precedes retry or remediation.
sc_ff_is_pytest_command() (
  scff_boundary='(^|[;&|()][;&|()]*[[:space:]]*)'
  scff_assign='([[:alnum:]_]+=[^[:space:]]+[[:space:]]+)*'
  scff_end='([[:space:];&|()]|$)'
  scff_quote="[\"']?"

  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}${scff_quote}([^[:space:];&|()\"']*/)?(pytest|py\\.test)${scff_quote}${scff_end}" \
    && return 0
  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}(\"[^\"]*/(pytest|py\\.test)\"|'[^']*/(pytest|py\\.test)')${scff_end}" \
    && return 0
  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}${scff_quote}([^[:space:];&|()\"']*/)?python([0-9.]+)?${scff_quote}[[:space:]]+-m[[:space:]]+(pytest|py\\.test)${scff_end}" \
    && return 0
  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}(\"[^\"]*/python([0-9.]+)?\"|'[^']*/python([0-9.]+)?')[[:space:]]+-m[[:space:]]+(pytest|py\\.test)${scff_end}" \
    && return 0
  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}(uv|poetry|pipenv)[[:space:]]+run([[:space:]]+[^;&|()]*)?[[:space:]]+(pytest|py\\.test)${scff_end}"
)

sc_ff_has_pytest_summary() (
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | grep -qE '(^|[^0-9])[0-9]+[[:space:]]+(failed|passed|failures|errors?|skipped|deselected|xfailed|xpassed|warnings?)([^[:alpha:]]|$)'
)

# A pure read/inspection command cannot itself have executed a test suite, no matter what
# text its output contains — e.g. `cat`/`tail` on a log file that happens to quote a pytest
# summary line, or `grep` for a failure-shaped string in unrelated source. Used to gate the
# sc_ff_has_pytest_summary() fallback below: that fallback exists to catch a real test run
# launched through a wrapper script the pytest/py.test regexes above don't match, not to
# fire on arbitrary bash output that merely resembles a summary. Confirmed 2026-08-16,
# nukegraph "The Write Path" (RULES §14.1): `ls`/`tail` on an old audit-log JSON file, and
# separately `cat`/`tail` on this repo's own hook source (which quotes an example "3 failed,
# 490 passed" string in a comment), both set the lock with no test tool ever invoked.
sc_ff_is_readonly_inspection_command() (
  scff_boundary='(^|[;&|()][;&|()]*[[:space:]]*)'
  scff_assign='([[:alnum:]_]+=[^[:space:]]+[[:space:]]+)*'
  scff_cmd_re='(ls|cat|head|tail|less|more|grep|egrep|fgrep|rg|find|wc|file|stat|pwd|echo|printf|jq)'

  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}([^[:space:];&|()\"']*/)?${scff_cmd_re}([[:space:]]|\$)" \
    && return 0

  # `git log`/`show`/`diff`/`status`/`blame` — read-only inspection subcommands only; other
  # git subcommands (e.g. `git merge`, which legitimately prints "N files changed") are not
  # matched here on purpose.
  printf '%s' "$1" | grep -qE \
    "${scff_boundary}${scff_assign}([^[:space:];&|()\"']*/)?git[[:space:]]+(log|show|diff|status|blame)([[:space:]]|\$)" \
    && return 0

  return 1
)

sc_ff_clear_command() (
  scff_worktree=$1
  scff_quoted=$(jq -nr --arg value "$scff_worktree" '$value | @sh') || return 1
  printf '"$HOME/.claude/hooks/sc-clear-firstfail-lock.sh" --judge-verdict '\''<judge verdict and concrete card edit/split>'\'' --judge-evidence '\''<judge transcript/session ID/path>'\'' %s' "$scff_quoted"
)
