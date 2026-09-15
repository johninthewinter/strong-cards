#!/usr/bin/env bash
# Executed proof for sc-delete-guard.sh / sc-trash.sh / sc-trash-verify.sh.
# Uses an isolated trash root and pending file; touches nothing in the real trash.
set -uo pipefail

H="$HOME/.claude/hooks"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sc-delete-guard-test-XXXXXX")
export SC_TRASH_ROOT="$WORK/trash"
export SC_TRASH_PENDING_FILE="$WORK/pending.txt"
PASS=0; FAIL=0

ok()  { printf 'PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

guard() { # guard <command-string> -> exit code of the hook
  printf '{"tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | "$H/sc-delete-guard.sh" >/dev/null 2>&1
  return $?
}

expect_block() { guard "$1"; [ $? -eq 2 ] && ok "blocked: $1" || bad "NOT blocked: $1"; }
expect_allow() { guard "$1"; [ $? -eq 0 ] && ok "allowed: $1" || bad "WRONGLY blocked: $1"; }

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
expect_allow "mv old.txt new.txt"
expect_allow "python3 build.py > build.log"
expect_allow "jq . a.json > b.json"
expect_allow "find . -name '*.py' -print"
expect_allow "$H/sc-trash.sh /tmp/whatever"

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
