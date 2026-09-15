import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude_md_check.py"


def _run(args, cwd=None):
    r = subprocess.run(
        [sys.executable, str(HOOK), *args],
        capture_output=True, text=True, cwd=cwd,
    )
    return r


def test_post_edit_silent_when_under_budget(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("# tiny\n")
    r = _run(["post-edit", str(f), str(tmp_path)])
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_post_edit_emits_json_when_over_budget(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("## A\n" + ("x\n" * 200))
    r = _run(["post-edit", str(f), str(tmp_path)])
    assert r.returncode == 0
    payload = json.loads(r.stdout)
    assert "systemMessage" in payload
    assert "over budget" in payload["systemMessage"].lower()


def test_post_edit_skipped_for_archive(tmp_path):
    f = tmp_path / "CLAUDE.md_archive_20260415.md"
    f.write_text("x\n" * 500)
    r = _run(["post-edit", str(f), str(tmp_path)])
    assert r.stdout.strip() == ""


def test_post_edit_respects_bare_mode(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("## A\n" + ("x\n" * 200))
    env_normal = os.environ.copy()
    env_normal.pop("CLAUDE_CODE_SIMPLE", None)
    r_normal = subprocess.run(
        [sys.executable, str(HOOK), "post-edit", str(f), str(tmp_path)],
        capture_output=True, text=True, env=env_normal,
    )
    assert "systemMessage" in r_normal.stdout, "bare-off baseline should emit output"
    env_bare = os.environ.copy()
    env_bare["CLAUDE_CODE_SIMPLE"] = "1"
    r_bare = subprocess.run(
        [sys.executable, str(HOOK), "post-edit", str(f), str(tmp_path)],
        capture_output=True, text=True, env=env_bare,
    )
    assert r_bare.stdout.strip() == ""


def test_session_start_silent_when_clean(tmp_path):
    (tmp_path / "CLAUDE.md").write_text("# ok\n")
    r = _run(["session-start", str(tmp_path)])
    assert r.stdout.strip() == ""


def test_session_start_reports_when_over_budget(tmp_path):
    (tmp_path / "CLAUDE.md").write_text("## A\n" + ("x\n" * 200))
    r = _run(["session-start", str(tmp_path)])
    payload = json.loads(r.stdout)
    assert "hookSpecificOutput" in payload
    assert "additionalContext" in payload["hookSpecificOutput"]


def test_post_edit_skips_when_recent_marker(tmp_path):
    # Create a fat CLAUDE.md
    f = tmp_path / "CLAUDE.md"
    f.write_text("## A\n" + ("x\n" * 200))
    # Touch loop-prevention marker
    marker = tmp_path / ".claude" / "md-autoupdate-ts"
    marker.parent.mkdir(exist_ok=True)
    marker.write_text("")  # mtime = now
    r = _run(["post-edit", str(f), str(tmp_path)])
    assert r.stdout.strip() == ""


def test_post_edit_fires_when_marker_old(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("## A\n" + ("x\n" * 200))
    marker = tmp_path / ".claude" / "md-autoupdate-ts"
    marker.parent.mkdir(exist_ok=True)
    marker.write_text("")
    old = time.time() - 3600
    os.utime(marker, (old, old))
    r = _run(["post-edit", str(f), str(tmp_path)])
    assert "systemMessage" in r.stdout
