import os
import sys
from pathlib import Path
import tempfile
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import is_over_budget, MAX_LINES, MAX_BYTES


def _write(p: Path, lines: int, filler: str = "x") -> Path:
    p.write_text("\n".join(filler for _ in range(lines)) + "\n")
    return p


def test_under_line_budget_is_ok(tmp_path):
    f = _write(tmp_path / "CLAUDE.md", 50)
    over, reason = is_over_budget(f)
    assert over is False
    assert reason == ""


def test_over_line_budget_flags(tmp_path):
    f = _write(tmp_path / "CLAUDE.md", MAX_LINES + 1)
    over, reason = is_over_budget(f)
    assert over is True
    assert "line" in reason.lower()


def test_over_byte_budget_flags(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("x" * (MAX_BYTES + 1))
    over, reason = is_over_budget(f)
    assert over is True
    assert "byte" in reason.lower() or "kb" in reason.lower()


def test_env_override_lines(tmp_path, monkeypatch):
    monkeypatch.setenv("CLAUDE_MD_MAX_LINES", "10")
    import importlib, claude_md_check
    importlib.reload(claude_md_check)
    f = _write(tmp_path / "CLAUDE.md", 15)
    over, reason = claude_md_check.is_over_budget(f)
    assert over is True


def test_missing_file_is_not_over_budget(tmp_path):
    over, reason = is_over_budget(tmp_path / "does-not-exist.md")
    assert over is False


def test_invalid_env_var_falls_back_to_default(monkeypatch):
    monkeypatch.setenv("CLAUDE_MD_MAX_LINES", "not-a-number")
    import importlib
    import claude_md_check
    importlib.reload(claude_md_check)
    assert claude_md_check.MAX_LINES == 150
