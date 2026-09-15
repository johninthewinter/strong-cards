# ~/.claude/hooks/tests/test_state_persistence.py
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import load_state, save_state, STATE_VERSION


def test_load_state_missing_returns_default(tmp_path):
    s = load_state(tmp_path)
    assert s["version"] == STATE_VERSION
    assert s["staleness_count"] == 0
    assert s["denied_this_session"] == []


def test_save_then_load_round_trip(tmp_path):
    s = load_state(tmp_path)
    s["staleness_count"] = 5
    s["denied_this_session"] = ["CLAUDE.md"]
    save_state(tmp_path, s)
    loaded = load_state(tmp_path)
    assert loaded["staleness_count"] == 5
    assert loaded["denied_this_session"] == ["CLAUDE.md"]


def test_save_creates_claude_dir(tmp_path):
    s = load_state(tmp_path)
    save_state(tmp_path, s)
    assert (tmp_path / ".claude" / "md-state.json").is_file()


def test_corrupt_state_falls_back_to_default(tmp_path):
    claude_dir = tmp_path / ".claude"
    claude_dir.mkdir()
    (claude_dir / "md-state.json").write_text("{not json")
    s = load_state(tmp_path)
    assert s["version"] == STATE_VERSION
