# ~/.claude/hooks/tests/test_preview.py
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import build_extraction_preview


FAT_CLAUDE_MD = """\
# Project

Short intro.

## Small Section

one line.

## Huge Section A

""" + "\n".join(f"line {i}" for i in range(80)) + """

## Huge Section B

""" + "\n".join(f"line {i}" for i in range(60)) + """

## Tiny

final.
"""


def test_preview_identifies_largest_sections(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text(FAT_CLAUDE_MD)
    preview = build_extraction_preview(f, target_lines=30)
    assert "Huge Section A" in preview["extractions"][0]["section"]
    assert preview["extractions"][0]["lines"] >= 80


def test_preview_stops_when_target_met(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text(FAT_CLAUDE_MD)
    preview = build_extraction_preview(f, target_lines=30)
    assert preview["projected_lines"] <= 80  # one extraction enough


def test_preview_slugifies_section_titles(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text(FAT_CLAUDE_MD)
    preview = build_extraction_preview(f, target_lines=30)
    slugs = [e["rules_path"] for e in preview["extractions"]]
    assert all(s.startswith("rules/") and s.endswith(".md") for s in slugs)
    assert all(" " not in s for s in slugs)


def test_preview_on_tiny_file_returns_empty(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text("# Tiny\n\nnothing to cut.\n")
    preview = build_extraction_preview(f, target_lines=150)
    assert preview["extractions"] == []
    assert preview["projected_lines"] == 3
