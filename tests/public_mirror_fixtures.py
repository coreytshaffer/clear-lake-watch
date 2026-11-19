"""Pinned May 5, 2026 public snapshot used by the public-mirror validator tests.

The files under ``tests/fixtures/public-mirror-2026-05-05/data/`` are
byte-identical copies of the manifest and its five outputs at commit
``b6a8890``. The historical replay tests read these copies, not the live
``data/`` directory, so a reviewed refresh of ``data/`` needs no test edits.
"""

from __future__ import annotations

import hashlib
import shutil
from pathlib import Path

FIXTURE_ROOT = Path(__file__).resolve().parent / "fixtures" / "public-mirror-2026-05-05"

SNAPSHOT_FILES = (
    "data/manifest.json",
    "data/live.json",
    "data/reports.json",
    "data/observations.json",
    "data/sites-normalized.json",
    "data/analytics.json",
)

# Git blob ids of the same paths at b6a8890 (`git rev-parse b6a8890:<path>`).
FIXTURE_BLOBS = {
    "data/manifest.json": "a94130381d4fc4a74254fd5bc27d2b9000d4a004",
    "data/live.json": "60cac58cd341f442c7a563d904014a95ffe35c85",
    "data/reports.json": "6db6579e10db3afe28bf0d11b35730662d44e6cc",
    "data/observations.json": "a28a2020a7fb53c19cbc333ebd06bdebaf812557",
    "data/sites-normalized.json": "2332efe60c9896973faad4aa7e367ef7f924a75a",
    "data/analytics.json": "c21494edd43fb074ddc14dddf47364a026eea364",
}


def git_blob_id(content: bytes) -> str:
    # Checkouts that convert line endings (core.autocrlf) restore CRLF to LF
    # before hashing, as Git itself does.
    normalized = content.replace(b"\r\n", b"\n")
    return hashlib.sha1(b"blob %d\0" % len(normalized) + normalized).hexdigest()


def verify_fixture() -> None:
    """Fail loudly if a pinned fixture file is missing or was edited."""

    for relative, expected in FIXTURE_BLOBS.items():
        path = FIXTURE_ROOT / relative
        if not path.is_file():
            raise AssertionError(f"Pinned snapshot fixture is missing: {path}")
        actual = git_blob_id(path.read_bytes())
        if actual != expected:
            raise AssertionError(
                f"Pinned snapshot fixture {relative} changed (blob {actual}, expected {expected}). "
                "These files must stay identical to the May 5, 2026 snapshot at b6a8890."
            )


def install_snapshot(root: Path) -> None:
    """Copy the pinned snapshot files into ``root/data``, replacing any there."""

    for relative in SNAPSHOT_FILES:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(FIXTURE_ROOT / relative, target)
