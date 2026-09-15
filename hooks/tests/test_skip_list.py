import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import should_skip


def test_archive_files_skipped():
    assert should_skip(Path("/proj/CLAUDE.md_archive_20260415.md")) is True
    assert should_skip(Path("/proj/CLAUDE.md.backup-20260415-160000")) is True


def test_git_dirs_skipped():
    assert should_skip(Path("/proj/.git/CLAUDE.md")) is True


def test_node_modules_skipped():
    assert should_skip(Path("/proj/node_modules/pkg/CLAUDE.md")) is True


def test_worktrees_skipped():
    assert should_skip(Path("/proj/.worktrees/feat/CLAUDE.md")) is True


def test_graphify_out_skipped():
    assert should_skip(Path("/proj/graphify-out/CLAUDE.md")) is True


def test_global_cli_configs_skipped():
    home = Path.home()
    assert should_skip(home / ".claude" / "CLAUDE.md") is True
    assert should_skip(home / ".codex" / "AGENTS.md") is True
    assert should_skip(home / ".opencode" / "AGENTS.md") is True


def test_project_claude_md_not_skipped():
    assert should_skip(Path("/proj/CLAUDE.md")) is False


def test_project_agents_md_not_skipped():
    assert should_skip(Path("/proj/AGENTS.md")) is False


def test_relative_node_modules_path_skipped():
    # Non-existent relative path inside node_modules must still be skipped.
    assert should_skip(Path("node_modules/foo/CLAUDE.md")) is True


def test_relative_project_path_not_skipped():
    # Non-existent relative path NOT inside a skip-dir must not be skipped.
    assert should_skip(Path("foo/CLAUDE.md")) is False
