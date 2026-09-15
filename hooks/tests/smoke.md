# Manual Smoke Tests — claude-md hooks

Run these once after install, whenever settings.json changes, or whenever
you upgrade Claude Code.

## 1. Under-budget file: hook stays silent

```bash
mkdir -p /tmp/hook-smoke && cd /tmp/hook-smoke
printf '# Project\n\nsmall file.\n' > CLAUDE.md
echo '{"tool_input":{"file_path":"/tmp/hook-smoke/CLAUDE.md"},"cwd":"/tmp/hook-smoke"}' \
  | ~/.claude/hooks/claude-md-post-edit.sh
```

Expected: no stdout.

## 2. Over-budget file: hook proposes extraction

```bash
cd /tmp/hook-smoke
{ echo '# Project'; echo; echo '## Big'; yes line | head -200; } > CLAUDE.md
echo '{"tool_input":{"file_path":"/tmp/hook-smoke/CLAUDE.md"},"cwd":"/tmp/hook-smoke"}' \
  | ~/.claude/hooks/claude-md-post-edit.sh
```

Expected: JSON on stdout with `systemMessage` containing `over budget`.

## 3. Archive path: skipped

```bash
cp CLAUDE.md CLAUDE.md_archive_20260415-test.md
echo '{"tool_input":{"file_path":"/tmp/hook-smoke/CLAUDE.md_archive_20260415-test.md"},"cwd":"/tmp/hook-smoke"}' \
  | ~/.claude/hooks/claude-md-post-edit.sh
```

Expected: no stdout.

## 4. Bare mode: hook silent

```bash
CLAUDE_CODE_SIMPLE=1 bash -c '
  echo "{\"tool_input\":{\"file_path\":\"/tmp/hook-smoke/CLAUDE.md\"},\"cwd\":\"/tmp/hook-smoke\"}" \
    | ~/.claude/hooks/claude-md-post-edit.sh'
```

Expected: no stdout.

## 5. Staleness counter

```bash
rm -rf /tmp/hook-smoke/.claude
for i in 1 2 3; do
  echo "{\"tool_input\":{\"file_path\":\"/tmp/hook-smoke/foo${i}.py\"},\"cwd\":\"/tmp/hook-smoke\"}" \
    | ~/.claude/hooks/claude-md-post-edit.sh
done
cat /tmp/hook-smoke/.claude/md-state.json
```

Expected: `staleness_count: 3`.

## 6. Loop-prevention marker

```bash
mkdir -p /tmp/hook-smoke/.claude
touch /tmp/hook-smoke/.claude/md-autoupdate-ts
echo '{"tool_input":{"file_path":"/tmp/hook-smoke/CLAUDE.md"},"cwd":"/tmp/hook-smoke"}' \
  | ~/.claude/hooks/claude-md-post-edit.sh
```

Expected: no stdout (marker fresh, hook bypassed).

## 7. Live Claude Code test

In a scratch directory, create a bloated `CLAUDE.md`, start `claude`,
observe SessionStart nudge. Ask Claude to add a line to CLAUDE.md,
observe PostToolUse emission with preview.

## Cleanup

```bash
rm -rf /tmp/hook-smoke
```
