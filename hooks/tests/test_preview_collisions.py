import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from claude_md_check import build_extraction_preview


def test_colliding_titles_get_unique_slugs(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text(
        "# Top\n\n"
        + "## Running\n\n" + ("a\n" * 200)
        + "## Running!\n\n" + ("b\n" * 200)
    )
    preview = build_extraction_preview(f, target_lines=30)
    paths = [e["rules_path"] for e in preview["extractions"]]
    assert len(paths) == len(set(paths)), f"collision in {paths}"


def test_non_ascii_titles_do_not_collide(tmp_path):
    f = tmp_path / "CLAUDE.md"
    f.write_text(
        "# Top\n\n"
        + "## 日本語\n\n" + ("a\n" * 200)
        + "## 한국어\n\n" + ("b\n" * 200)
    )
    preview = build_extraction_preview(f, target_lines=30)
    paths = [e["rules_path"] for e in preview["extractions"]]
    assert len(paths) == len(set(paths)), f"collision in {paths}"
