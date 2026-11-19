"""End-to-end parity tests for the two public-mirror validator commands.

Run from the repository root:

    python -m unittest discover -s tests -p test_public_mirror_entrypoints.py

Each case copies the checkout's tracked and untracked-but-not-ignored files
into a scratch Git repository, replaces its snapshot files with the pinned
May 5, 2026 fixture (see tests/public_mirror_fixtures.py) unless the case
checks the live snapshot, mutates only that copy, and runs:

- ``python scripts/validate-public-mirror.py [--as-of ...]``
- ``powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-public-mirror.ps1 [-AsOfUtc ...]``

Shared findings are the ``[code] subject: message`` lines; parity compares
sorted ``(severity, code, subject)`` values and exit status. Native checks may
add other findings.

PowerShell selection: ``CLW_POWERSHELL`` names the executable; otherwise
``powershell.exe``, ``powershell``, then ``pwsh`` are tried. PowerShell cases
are skipped when no runtime is found, unless ``CLW_REQUIRE_POWERSHELL=1``,
which turns a missing runtime into a failure. The PowerShell command also
needs Node.js and Git on PATH; the Python running these tests (with the pinned
tzdata installed) is placed first on PATH for the PowerShell bridge.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Callable, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = REPO_ROOT / "tests"
if str(TESTS_DIR) not in sys.path:
    sys.path.insert(0, str(TESTS_DIR))

import public_mirror_fixtures as fixtures  # noqa: E402

AS_OF = "2026-11-17T12:00:00Z"
COMMAND_TIMEOUT_SECONDS = 600

HISTORY = [
    ("warning", "snapshot_old", "data/manifest.json"),
    ("warning", "source_observation_old", "fhabs-bloom-reports"),
    ("warning", "source_observation_old", "fhabs-results"),
]

OUTPUT_FILES = (
    "data/live.json",
    "data/reports.json",
    "data/observations.json",
    "data/sites-normalized.json",
    "data/analytics.json",
)

_SHARED_LINE = re.compile(r"^\s*- \[([a-z0-9_]+)\] (.+?): ")
_SECTION_HEADERS = {
    "Warnings:": "warning",
    "Failures:": "failure",
    "Validation failed:": "failure",
}


def _find_powershell() -> Optional[str]:
    configured = os.environ.get("CLW_POWERSHELL")
    if configured:
        return shutil.which(configured) or configured
    for name in ("powershell.exe", "powershell", "pwsh"):
        found = shutil.which(name)
        if found:
            return found
    return None


POWERSHELL = _find_powershell()
REQUIRE_POWERSHELL = os.environ.get("CLW_REQUIRE_POWERSHELL") == "1"


def shared_findings(stdout: str) -> list[tuple[str, str, str]]:
    """Extract sorted (severity, code, subject) from a validator's output."""

    section = None
    found = []
    for line in stdout.splitlines():
        stripped = line.strip()
        if stripped in _SECTION_HEADERS:
            section = _SECTION_HEADERS[stripped]
            continue
        if not stripped.startswith("- "):
            section = None
            continue
        match = _SHARED_LINE.match(line)
        if match and section:
            found.append((section, match.group(1), match.group(2)))
    return sorted(found)


def _load(checkout: Path, relative: str) -> dict:
    return json.loads((checkout / relative).read_text(encoding="utf-8"))


def _save(checkout: Path, relative: str, data: object) -> None:
    # ASCII-only JSON reads the same under Windows PowerShell 5.1's default encoding.
    (checkout / relative).write_text(json.dumps(data, indent=2, ensure_ascii=True), encoding="utf-8")


def _edit(checkout: Path, relative: str, change: Callable[[dict], object]) -> None:
    data = _load(checkout, relative)
    change(data)
    _save(checkout, relative, data)


def _git(checkout: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-c", "core.autocrlf=false", "-c", "core.safecrlf=false", *args],
        cwd=checkout,
        check=True,
        capture_output=True,
    )


def _command_env() -> dict:
    env = dict(os.environ)
    env["PATH"] = os.path.dirname(sys.executable) + os.pathsep + env.get("PATH", "")
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def setUpModule() -> None:
    fixtures.verify_fixture()
    if REQUIRE_POWERSHELL and not POWERSHELL:
        raise AssertionError("CLW_REQUIRE_POWERSHELL=1, but no PowerShell executable was found.")
    if REQUIRE_POWERSHELL and not shutil.which("node"):
        raise AssertionError("CLW_REQUIRE_POWERSHELL=1, but Node.js is not on PATH for the smoke check.")


class ScratchCheckouts:
    """Scratch Git repositories copied from one template of the checkout."""

    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="clw-entry-")
        self.base = Path(self._tmp.name)
        self.template = self.base / "template"
        listed = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
        ).stdout.decode("utf-8")
        for relative in filter(None, listed.split("\0")):
            source = REPO_ROOT / relative
            if source.is_file():
                target = self.template / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        _git(self.template, "init", "-q")
        _git(self.template, "add", "-A")
        self._count = 0

    def new(self, history: bool = True) -> Path:
        """Return a fresh scratch checkout.

        With ``history`` (the default) its snapshot files are the pinned May 5
        fixture; otherwise it keeps the checkout's live data/ files.
        """
        self._count += 1
        checkout = self.base / f"case-{self._count:02d}"
        shutil.copytree(self.template, checkout, symlinks=True)
        if history:
            fixtures.install_snapshot(checkout)
        return checkout

    def cleanup(self) -> None:
        self._tmp.cleanup()


class EntryPointTestCase(unittest.TestCase):
    scratch: ScratchCheckouts

    @classmethod
    def setUpClass(cls) -> None:
        cls.scratch = ScratchCheckouts()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.scratch.cleanup()

    def require_powershell(self) -> str:
        if not POWERSHELL:
            self.skipTest("No PowerShell runtime found; set CLW_REQUIRE_POWERSHELL=1 to make this a failure.")
        return POWERSHELL

    def run_python(self, checkout: Path, as_of: Optional[str] = AS_OF) -> subprocess.CompletedProcess:
        args = [sys.executable, "-B", str(checkout / "scripts" / "validate-public-mirror.py")]
        if as_of is not None:
            args += ["--as-of", as_of]
        return subprocess.run(
            args,
            cwd=checkout,
            env=_command_env(),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=COMMAND_TIMEOUT_SECONDS,
        )

    def run_powershell(self, checkout: Path, as_of: Optional[str] = AS_OF) -> subprocess.CompletedProcess:
        args = [
            self.require_powershell(),
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(checkout / "scripts" / "validate-public-mirror.ps1"),
        ]
        if as_of is not None:
            args += ["-AsOfUtc", as_of]
        return subprocess.run(
            args,
            cwd=checkout,
            env=_command_env(),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=COMMAND_TIMEOUT_SECONDS,
        )

    def assert_parity(
        self,
        checkout: Path,
        expected_exit: int,
        expected_shared: Optional[list] = None,
        as_of: Optional[str] = AS_OF,
    ) -> tuple:
        python = self.run_python(checkout, as_of)
        detail = f"\n--- python stdout ---\n{python.stdout}\n--- python stderr ---\n{python.stderr}"
        self.assertEqual(python.returncode, expected_exit, detail)
        if expected_shared is not None:
            self.assertEqual(shared_findings(python.stdout), sorted(expected_shared), detail)

        powershell = None
        if POWERSHELL:
            powershell = self.run_powershell(checkout, as_of)
            detail += f"\n--- powershell stdout ---\n{powershell.stdout}\n--- powershell stderr ---\n{powershell.stderr}"
            self.assertEqual(powershell.returncode, python.returncode, detail)
            self.assertEqual(shared_findings(powershell.stdout), shared_findings(python.stdout), detail)
        elif REQUIRE_POWERSHELL:
            self.fail("CLW_REQUIRE_POWERSHELL=1, but no PowerShell executable was found.")
        return python, powershell


class SharedParityTests(EntryPointTestCase):
    def test_reviewed_history_matches(self) -> None:
        self.assert_parity(self.scratch.new(), 0, HISTORY)

    def test_ordinary_invocations_match_on_clean_snapshot(self) -> None:
        # The live snapshot at the real clock: whatever it holds, a reviewed
        # mirror passes with at most age warnings, and both commands agree.
        python, _ = self.assert_parity(self.scratch.new(history=False), 0, as_of=None)
        codes = {key[1] for key in shared_findings(python.stdout)}
        self.assertTrue(codes <= {"snapshot_old", "source_observation_old"}, python.stdout)

    def test_fresh_snapshot_has_no_age_warnings(self) -> None:
        checkout = self.scratch.new()
        stamp = "2026-11-17T10:00:00Z"

        def freshen(manifest: dict) -> None:
            manifest["generatedAt"] = stamp
            for source in manifest["sources"]:
                source["latestObservationDate"] = "2026-11-16"
                if source["id"].startswith("fhabs-"):
                    source["resourceDate"] = "2026-11-16"
                    source["resourceAgeDays"] = 1

        _edit(checkout, "data/manifest.json", freshen)
        for relative in OUTPUT_FILES:
            _edit(checkout, relative, lambda data: data.update(generatedAt=stamp))
        self.assert_parity(checkout, 0, [])

    def test_future_source_date_fails_in_both(self) -> None:
        checkout = self.scratch.new()
        _edit(
            checkout,
            "data/manifest.json",
            lambda m: next(s for s in m["sources"] if s["id"] == "usgs-lake-level").update(
                latestObservationDate="2026-05-06"
            ),
        )
        self.assert_parity(
            checkout, 1, HISTORY + [("failure", "observation_after_generation", "usgs-lake-level")]
        )

    def test_output_count_mismatch_fails_in_both(self) -> None:
        checkout = self.scratch.new()
        _edit(
            checkout,
            "data/manifest.json",
            lambda m: next(o for o in m["outputs"] if o["file"] == "data/reports.json").update(recordCount=231),
        )
        self.assert_parity(checkout, 1, HISTORY + [("failure", "output_count_mismatch", "data/reports.json")])

    def test_tracked_private_sentinel_fails_in_both(self) -> None:
        checkout = self.scratch.new()
        sentinel = checkout / "data" / "private" / "test-only.json"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text('{"sentinel": "synthetic test-only file"}\n', encoding="utf-8")
        _git(checkout, "add", "-f", "data/private/test-only.json")
        tracked = subprocess.run(
            ["git", "ls-files", "data/private"], cwd=checkout, check=True, capture_output=True, text=True
        ).stdout.split()
        self.assertEqual(tracked, ["data/private/test-only.json"])

        python, powershell = self.assert_parity(checkout, 1, HISTORY)
        self.assertIn("must not track excluded review/private/local artifact", python.stdout)
        if powershell is not None:
            self.assertIn("must not track excluded review/private/local artifact", powershell.stdout)

    def test_json_null_snapshot_files_fail_in_both(self) -> None:
        cases = {
            "data/manifest.json": [("failure", "invalid_manifest", "data/manifest.json")],
            "data/live.json": HISTORY + [("failure", "invalid_output_data", "data/live.json")],
            "data/analytics.json": HISTORY + [("failure", "invalid_output_data", "data/analytics.json")],
        }
        for relative, expected in cases.items():
            with self.subTest(file=relative):
                checkout = self.scratch.new()
                (checkout / relative).write_text("null\n", encoding="utf-8")
                self.assert_parity(checkout, 1, expected)

    def test_data_directory_outside_checkout_fails_in_both(self) -> None:
        checkout = self.scratch.new()
        outside = checkout.parent / f"{checkout.name}-outside-data"
        shutil.move(str(checkout / "data"), str(outside))
        try:
            (checkout / "data").symlink_to(outside, target_is_directory=True)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"directory symlinks unavailable: {exc}")
        self.assert_parity(checkout, 1, [("failure", "unsafe_snapshot_path", "data/manifest.json")])

    def test_missing_pinned_timezone_data_fails_in_both(self) -> None:
        checkout = self.scratch.new()
        evaluator = checkout / "scripts" / "public_mirror_common.py"
        text = evaluator.read_text(encoding="utf-8")
        self.assertEqual(text.count('PINNED_TZDATA_VERSION = "2026.6"'), 1)
        evaluator.write_text(text.replace('PINNED_TZDATA_VERSION = "2026.6"', 'PINNED_TZDATA_VERSION = "1999.1"'), encoding="utf-8")
        self.assert_parity(checkout, 1, [("failure", "timezone_data_unavailable", "tzdata")])

    def test_invalid_explicit_clock_is_an_argument_error(self) -> None:
        checkout = self.scratch.new()
        python = self.run_python(checkout, "2026-11-17T04:00:00-08:00")
        self.assertEqual(python.returncode, 2, python.stdout + python.stderr)
        self.assertIn("--as-of", python.stderr)
        if POWERSHELL:
            powershell = self.run_powershell(checkout, "2026-11-17T04:00:00-08:00")
            self.assertEqual(powershell.returncode, 1, powershell.stdout + powershell.stderr)
            self.assertIn("Shared snapshot evaluator failed (exit code 2", powershell.stdout)


class EvaluatorFailureTests(EntryPointTestCase):
    STUB_HEADER = "import json, sys\nif __name__ == '__main__':\n"

    def replace_evaluator(self, checkout: Path, main_body: str, module_body: str = "") -> None:
        source = module_body + self.STUB_HEADER + "".join(f"    {line}\n" for line in main_body.splitlines())
        (checkout / "scripts" / "public_mirror_common.py").write_text(source, encoding="utf-8")

    def test_unavailable_evaluator_fails_both_gates(self) -> None:
        checkout = self.scratch.new()
        (checkout / "scripts" / "public_mirror_common.py").unlink()
        python = self.run_python(checkout)
        self.assertNotEqual(python.returncode, 0, python.stdout)
        self.assertIn("Shared snapshot evaluator is unavailable", python.stdout)
        if POWERSHELL:
            powershell = self.run_powershell(checkout)
            self.assertNotEqual(powershell.returncode, 0, powershell.stdout)
            self.assertIn("Shared snapshot evaluator is unavailable", powershell.stdout)

    def test_malformed_evaluator_fails_python_gate(self) -> None:
        cases = {
            "incomplete module": "",
            "bad severity": (
                "from datetime import datetime, timezone\n"
                "class F:\n"
                "    severity, code, subject, message = 'info', 'x', 'y', 'z'\n"
                "def parse_as_of(value):\n"
                "    return datetime(2026, 11, 17, 12, tzinfo=timezone.utc)\n"
                "def utc_now():\n"
                "    return datetime(2026, 11, 17, 12, tzinfo=timezone.utc)\n"
                "def check_text_guards(root, profile):\n"
                "    return []\n"
                "def check_snapshot(root, as_of):\n"
                "    return [F()]\n"
            ),
            "evaluator raises": (
                "from datetime import datetime, timezone\n"
                "def parse_as_of(value):\n"
                "    return datetime(2026, 11, 17, 12, tzinfo=timezone.utc)\n"
                "def utc_now():\n"
                "    return datetime(2026, 11, 17, 12, tzinfo=timezone.utc)\n"
                "def check_text_guards(root, profile):\n"
                "    return []\n"
                "def check_snapshot(root, as_of):\n"
                "    raise RuntimeError('synthetic evaluator error')\n"
            ),
        }
        for label, module_body in cases.items():
            with self.subTest(case=label):
                checkout = self.scratch.new()
                self.replace_evaluator(checkout, "sys.exit(0)", module_body)
                python = self.run_python(checkout)
                self.assertEqual(python.returncode, 1, python.stdout + python.stderr)
                self.assertIn("Shared snapshot evaluator", python.stdout)
                self.assertNotIn("Traceback", python.stderr)

    def test_malformed_bridge_response_fails_powershell_gate(self) -> None:
        self.require_powershell()
        valid_failure = {"severity": "failure", "code": "x", "subject": "y", "message": "z"}
        cases = {
            "not JSON": "print('not json')\nsys.exit(0)",
            "empty output": "sys.exit(0)",
            "two JSON documents": "print('{\"schema_version\":1,\"findings\":[]}')\nprint('{}')\nsys.exit(0)",
            "top-level array": "print(json.dumps([{'schema_version': 1, 'findings': []}]))\nsys.exit(0)",
            "wrong schema version": "print(json.dumps({'schema_version': 2, 'findings': []}))\nsys.exit(0)",
            "string schema version": "print(json.dumps({'schema_version': '1', 'findings': []}))\nsys.exit(0)",
            "findings not a list": "print(json.dumps({'schema_version': 1, 'findings': {}}))\nsys.exit(0)",
            "unknown severity": (
                "print(json.dumps({'schema_version': 1, 'findings': [dict(severity='info', code='x', subject='y', message='z')]}))\n"
                "sys.exit(0)"
            ),
            "missing finding field": (
                "print(json.dumps({'schema_version': 1, 'findings': [dict(severity='warning', code='x', subject='y')]}))\n"
                "sys.exit(0)"
            ),
            "failure with exit 0": f"print(json.dumps({{'schema_version': 1, 'findings': [{valid_failure!r}]}}))\nsys.exit(0)",
            "exit 1 without failure": "print(json.dumps({'schema_version': 1, 'findings': []}))\nsys.exit(1)",
            "unexpected exit code": "print(json.dumps({'schema_version': 1, 'findings': []}))\nsys.exit(3)",
            "crash": "raise RuntimeError('synthetic evaluator crash')",
        }
        for label, main_body in cases.items():
            with self.subTest(case=label):
                checkout = self.scratch.new()
                self.replace_evaluator(checkout, main_body)
                powershell = self.run_powershell(checkout)
                self.assertEqual(powershell.returncode, 1, powershell.stdout + powershell.stderr)
                self.assertRegex(
                    powershell.stdout,
                    r"Shared snapshot evaluator (returned an invalid report|failed)",
                )


class WindowsGateTests(EntryPointTestCase):
    """The PowerShell command keeps its stronger native checks."""

    def assert_powershell_only_failure(self, checkout: Path, expected_message: str) -> None:
        self.require_powershell()
        python, powershell = self.assert_parity_with_native_difference(checkout)
        self.assertEqual(python.returncode, 0, python.stdout)
        self.assertEqual(powershell.returncode, 1, powershell.stdout + powershell.stderr)
        self.assertIn(expected_message, powershell.stdout)

    def assert_parity_with_native_difference(self, checkout: Path) -> tuple:
        python = self.run_python(checkout)
        powershell = self.run_powershell(checkout)
        self.assertEqual(shared_findings(python.stdout), HISTORY, python.stdout)
        self.assertEqual(shared_findings(powershell.stdout), HISTORY, powershell.stdout)
        return python, powershell

    def test_permission_to_publish_false_still_fails(self) -> None:
        checkout = self.scratch.new()
        _edit(
            checkout,
            "data/reviewed-field-observations.json",
            lambda d: d["records"].append(
                {
                    "recordId": "synthetic-test-record",
                    "qaStatus": "approved-public",
                    "permissionToPublish": False,
                }
            ),
        )
        self.assert_powershell_only_failure(
            checkout, "Reviewed public field observation synthetic-test-record lacks permissionToPublish true."
        )

    def test_manifest_observation_note_guard_still_fails(self) -> None:
        checkout = self.scratch.new()
        _edit(
            checkout,
            "data/manifest.json",
            lambda m: m.update(
                notes=[n for n in m["notes"] if "Observation dates may be older" not in n]
            ),
        )
        self.assert_powershell_only_failure(
            checkout, "Manifest must preserve dashboard-refresh versus source-observation distinction."
        )

    def test_file_backed_text_guard_still_fails(self) -> None:
        checkout = self.scratch.new()
        doc = checkout / "docs" / "source-freshness-validation.md"
        text = doc.read_text(encoding="utf-8")
        self.assertIn("Warning Versus Failure", text)
        doc.write_text(text.replace("Warning Versus Failure", "Severity Notes"), encoding="utf-8")
        self.assert_powershell_only_failure(
            checkout, "Source freshness validation doc must explain warning versus failure behavior."
        )


class TextGuardEntryPointTests(EntryPointTestCase):
    def test_common_text_guard_preserves_legacy_messages(self) -> None:
        checkout = self.scratch.new()
        doc = checkout / "index.html"
        literal = "Public Data Snapshot, Not Advisory Guidance"
        original = doc.read_text(encoding="utf-8")
        self.assertIn(literal, original)
        doc.write_text(original.replace(literal, literal.lower()), encoding="utf-8")

        python, powershell = self.assert_parity(checkout, 1, HISTORY)
        self.assertIn(f"index.html is missing required text: {literal}", python.stdout)
        if powershell is not None:
            self.assertIn("Homepage must include the public snapshot status strip.", powershell.stdout)

    def test_python_only_text_guard_preserves_profile(self) -> None:
        checkout = self.scratch.new()
        doc = checkout / "README.md"
        literal = "static reviewed snapshot generated on May 5, 2026"
        original = doc.read_text(encoding="utf-8")
        self.assertIn(literal, original)
        doc.write_text(original.replace(literal, "archived snapshot"), encoding="utf-8")

        python = self.run_python(checkout)
        self.assertEqual(python.returncode, 1, python.stdout + python.stderr)
        self.assertIn(f"README.md is missing required text: {literal}", python.stdout)
        if POWERSHELL:
            powershell = self.run_powershell(checkout)
            self.assertEqual(powershell.returncode, 0, powershell.stdout + powershell.stderr)

    def test_missing_text_guard_catalog_fails_both_commands(self) -> None:
        checkout = self.scratch.new()
        catalog = "scripts/public-mirror-text-guards.json"
        (checkout / catalog).unlink()
        self.assert_parity(checkout, 1, HISTORY + [("failure", "guard_catalog_invalid", catalog)])

    def test_text_guard_rejects_ignored_private_file_in_both_commands(self) -> None:
        checkout = self.scratch.new()
        relative = "docs/private/test-only.md"
        private_doc = checkout / relative
        private_doc.parent.mkdir()
        private_doc.write_text("Synthetic private text", encoding="utf-8")
        _git(checkout, "check-ignore", "--quiet", "--", relative)

        catalog_path = checkout / "scripts/public-mirror-text-guards.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        catalog[relative] = [
            {"text": "Synthetic private text", "python": True, "powershell": "Missing fixture text."}
        ]
        catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

        self.assert_parity(checkout, 1, HISTORY + [("failure", "guard_file_unreadable", relative)])


if __name__ == "__main__":
    unittest.main()
