#!/usr/bin/env bash
# Executed proof for sc-delete-guard.sh / sc-trash.sh / sc-trash-verify.sh.
# Uses an isolated trash root and pending file; touches nothing in the real trash.
set -uo pipefail

H="$HOME/.claude/hooks"
UNDER_TEST=$(CDPATH= cd "$(dirname "$0")/.." 2>/dev/null && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sc-delete-guard-test-XXXXXX")
export SC_TRASH_ROOT="$WORK/trash"
export SC_TRASH_PENDING_FILE="$WORK/pending.txt"
PASS=0; FAIL=0

ok()  { printf 'PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

guard() { # guard <command-string> -> exit code of the hook
  printf '{"tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | "$UNDER_TEST/sc-delete-guard.sh" >/dev/null 2>&1
  return $?
}

timeout_guard() { # timeout_guard <command-string> -> exit code of the hook
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | "$UNDER_TEST/enforce-codex-timeout.py" >/dev/null 2>&1
  return $?
}

expect_block() { guard "$1"; [ $? -eq 2 ] && ok "blocked: $1" || bad "NOT blocked: $1"; }
expect_allow() { guard "$1"; [ $? -eq 0 ] && ok "allowed: $1" || bad "WRONGLY blocked: $1"; }
expect_timeout_block() { timeout_guard "$1"; [ $? -eq 2 ] && ok "timeout blocked: $1" || bad "timeout NOT blocked: $1"; }
expect_timeout_allow() { timeout_guard "$1"; [ $? -eq 0 ] && ok "timeout allowed: $1" || bad "timeout WRONGLY blocked: $1"; }

echo "===== TEST 1: rm -rf is blocked and not executed ====="
mkdir -p "$WORK/some-test-dir" && echo canary > "$WORK/some-test-dir/canary.txt"
expect_block "rm -rf $WORK/some-test-dir"
[ -f "$WORK/some-test-dir/canary.txt" ] && ok "target survived (guard ran before execution)" \
                                        || bad "target was destroyed"
expect_block "rm -rf /"
expect_block "sudo /bin/rm -fr /tmp/x"
expect_block "find . -name '*.pyc' -delete"
expect_block "find . -type f -exec rm {} \\;"
expect_block "git clean -fdx"
expect_block "git branch -D obsolete-card"
expect_block "git branch --delete --force obsolete-card"
expect_block "git reset --hard HEAD~1"
expect_block "git checkout -- ."
expect_block "git checkout -- src/file.py"
expect_block "git restore ."
expect_block "git stash drop stash@{0}"
expect_block "git stash clear"
expect_block "shred -u secret.key"
expect_block "truncate -s 0 app.log"
expect_block "mv notes.txt /dev/null"
expect_block "ls | xargs rm"
expect_block "> app.log"
expect_block ": > app.log"
expect_block "cat /dev/null > app.log"
expect_block "cd /tmp && echo hi && rm -f x"

echo
echo "===== TEST 4: ordinary safe commands are NOT falsely blocked ====="
expect_allow "ls -la /tmp"
expect_allow "cat /etc/hosts"
expect_allow "grep -rn 'rm -rf' /var/log/audit.log"
expect_allow "echo 'rm -rf /' >> notes.txt"
expect_allow "npm run rm-cache"
expect_allow "git status --porcelain"
expect_allow "git branch"
expect_allow "git branch -d merged-card"
expect_allow "git reset --soft HEAD~1"
expect_allow "git checkout branchname"
expect_allow "git checkout -b new-branch"
expect_allow "git restore --staged src/file.py"
expect_allow "git stash list"
expect_allow "mv old.txt new.txt"
expect_allow "python3 build.py > build.log"
expect_allow "jq . a.json > b.json"
expect_allow "find . -name '*.py' -print"
expect_allow "$H/sc-trash.sh /tmp/whatever"

echo
echo "===== TEST 4b: worktree removal requires clean-and-merged state ====="
REPO="$WORK/worktree-repo"
CLEAN_WT="$WORK/clean-merged-worktree"
UNMERGED_WT="$WORK/unmerged-worktree"
DIRTY_WT="$WORK/dirty-merged-worktree"
mkdir -p "$REPO"
(
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name "SC Delete Guard Test"
  git config user.email "sc-delete-guard@example.invalid"
  printf 'base\n' > tracked.txt
  git add tracked.txt
  git commit -q -m base
  git worktree add -q -b clean-merged-check "$CLEAN_WT" main
)
(
  cd "$CLEAN_WT" || exit 1
  printf 'merged\n' > merged.txt
  git add merged.txt
  git commit -q -m merged
)
(
  cd "$REPO" || exit 1
  git merge -q --ff-only clean-merged-check
  git worktree add -q -b unmerged-check "$UNMERGED_WT" main
  git worktree add -q -b dirty-merged-check "$DIRTY_WT" main
)
(
  cd "$UNMERGED_WT" || exit 1
  printf 'unmerged\n' > unmerged.txt
  git add unmerged.txt
  git commit -q -m unmerged
)
printf 'dirty\n' > "$DIRTY_WT/dirty.txt"
expect_allow "git worktree remove --force $CLEAN_WT"
expect_block "git worktree remove $UNMERGED_WT"
expect_block "git worktree remove --force $DIRTY_WT"
expect_allow "git worktree remove --force $WORK/not-a-worktree"

echo
echo "===== TEST 4c: codex timeout matching uses parsed argv ====="
expect_timeout_block "codex exec --model gpt-5.6-luna task"
expect_timeout_block "sudo env PROFILE=test codex --quiet exec task"
expect_timeout_block "sudo -u test-user codex exec task"
expect_timeout_block "echo ready && codex exec task"
expect_timeout_block "echo ready
codex exec task"
expect_timeout_allow "timeout 900 codex exec --model gpt-5.6-luna task"
expect_timeout_allow "sudo timeout --signal TERM 900 codex exec task"
expect_timeout_allow "grep -n 'codex exec' audit.log"
expect_timeout_allow "echo 'codex exec must be bounded'"

echo
echo "===== TEST 2: sc-trash.sh moves, hashes, manifests ====="
TF="$WORK/some-test-file"
printf 'hello trash\n' > "$TF"
EXPECT_HASH=$(shasum -a 256 "$TF" | awk '{print $1}')
"$H/sc-trash.sh" "$TF"
[ ! -e "$TF" ] && ok "original is gone" || bad "original still present"
ENTRY=$(head -n1 "$SC_TRASH_PENDING_FILE")
# Read the real paths from the manifest: sc-trash.sh canonicalizes /var -> /private/var
# on macOS, so reconstructing them from $TF in the test would not match.
PAYLOAD=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["trashed_path"])' "$ENTRY/MANIFEST.json")
TF=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["original_path"])' "$ENTRY/MANIFEST.json")
[ -f "$PAYLOAD" ] && ok "trash payload exists at $PAYLOAD" || bad "payload missing"
[ "$(cat "$PAYLOAD" 2>/dev/null)" = "hello trash" ] && ok "trashed content is correct" || bad "content wrong"
MAN_HASH=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["sha256"])' "$ENTRY/MANIFEST.json" 2>/dev/null)
[ "$MAN_HASH" = "$EXPECT_HASH" ] && ok "manifest sha256 matches real file hash ($MAN_HASH)" \
                                 || bad "manifest hash wrong: $MAN_HASH vs $EXPECT_HASH"
echo "--- MANIFEST.json ---"; cat "$ENTRY/MANIFEST.json"

echo
echo "===== TEST 3a: PostToolUse verify PASSES on a legitimate move ====="
printf '%s\n' "$ENTRY" > "$SC_TRASH_PENDING_FILE"
VOUT=$("$H/sc-trash-verify.sh" 2>&1); VRC=$?
printf '%s\n' "$VOUT"
[ $VRC -eq 0 ] && ok "verify exit 0 on clean move" || bad "verify wrongly failed (rc=$VRC)"
printf '%s' "$VOUT" | grep -q "CHECK A: PASS" && ok "Check A reported PASS" || bad "Check A missing"
printf '%s' "$VOUT" | grep -q "CHECK B: PASS" && ok "Check B reported PASS" || bad "Check B missing"

echo
echo "===== TEST 3b: verify FLAGS a tampered trash entry (hash mismatch) ====="
printf 'TAMPERED\n' > "$PAYLOAD"
printf '%s\n' "$ENTRY" > "$SC_TRASH_PENDING_FILE"
TOUT=$("$H/sc-trash-verify.sh" 2>&1); TRC=$?
printf '%s\n' "$TOUT"
[ $TRC -eq 2 ] && ok "verify exit 2 on tampered payload" || bad "tamper NOT caught (rc=$TRC)"
printf '%s' "$TOUT" | grep -q "HASH MISMATCH" && ok "hash mismatch reported explicitly" || bad "no mismatch message"

echo
echo "===== TEST 3c: verify FLAGS a refilled original slot (Check B) ====="
printf 'hello trash\n' > "$PAYLOAD"          # repair payload so only Check B can fail
printf 'impostor\n' > "$TF"                  # something raced to refill the original path
printf '%s\n' "$ENTRY" > "$SC_TRASH_PENDING_FILE"
BOUT=$("$H/sc-trash-verify.sh" 2>&1); BRC=$?
printf '%s\n' "$BOUT"
[ $BRC -eq 2 ] && ok "verify exit 2 on refilled original" || bad "refill NOT caught (rc=$BRC)"
printf '%s' "$BOUT" | grep -q "CHECK A: PASS" && ok "Check A still PASS (isolates Check B)" || bad "Check A unexpectedly failed"
printf '%s' "$BOUT" | grep -q "CHECK B: FAIL" && ok "Check B caught the refill" || bad "Check B did not fire"

echo
echo "===== TEST 5: sc-trash.sh error paths do not half-succeed ====="
"$H/sc-trash.sh" "$WORK/does-not-exist" >/dev/null 2>&1
[ $? -ne 0 ] && ok "missing path exits non-zero" || bad "missing path exited 0"
"$H/sc-trash.sh" "$ENTRY" >/dev/null 2>&1
[ $? -ne 0 ] && ok "refuses to trash the trash" || bad "trashed its own trash"

echo
echo "======================================================"
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
echo "workdir (left for inspection, nothing deleted): $WORK"
[ "$FAIL" -eq 0 ] || exit 1
