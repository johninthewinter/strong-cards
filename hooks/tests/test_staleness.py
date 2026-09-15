# ~/.claude/hooks/tests/test_staleness.py
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import (
    is_code_file, bump_staleness, load_state, STALENESS_THRESHOLD
)


def test_python_file_is_code():
    assert is_code_file(Path("foo.py")) is True


def test_typescript_file_is_code():
    assert is_code_file(Path("foo.ts")) is True
    assert is_code_file(Path("foo.tsx")) is True


def test_javascript_file_is_code():
    assert is_code_file(Path("foo.js")) is True


def test_markdown_is_not_code():
    assert is_code_file(Path("foo.md")) is False


def test_claude_md_is_not_code():
    assert is_code_file(Path("CLAUDE.md")) is False


def test_bump_increments_counter(tmp_path):
    bump_staleness(tmp_path)
    assert load_state(tmp_path)["staleness_count"] == 1
    bump_staleness(tmp_path)
    assert load_state(tmp_path)["staleness_count"] == 2


def test_threshold_constant_is_positive():
    assert STALENESS_THRESHOLD > 0
