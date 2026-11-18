"""Focused tests for the shared public-mirror snapshot evaluator.

Run from the repository root:

    python -m unittest discover -s tests -p test_public_mirror_common.py

Each test builds a temporary snapshot by copying the tracked public files
(the manifest and its five outputs) and mutates only that scratch copy.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import public_mirror_common as pmc  # noqa: E402

SNAPSHOT_FILES = (
    "data/manifest.json",
    "data/live.json",
    "data/reports.json",
    "data/observations.json",
    "data/sites-normalized.json",
    "data/analytics.json",
)

# The historical expectations below are pinned to the reviewed May 5, 2026
# snapshot. A reviewed refresh that replaces data/manifest.json must update
# these expectations together with the pinned manifest fixture.
PINNED_MANIFEST = REPO_ROOT / "tests" / "fixtures" / "freshness" / "clw-manifest-2026-05-05.json"
HISTORY_AS_OF = "2026-11-17T12:00:00Z"

HISTORY_FINDINGS = [
    ("warning", "snapshot_old", "data/manifest.json"),
    ("warning", "source_observation_old", "fhabs-bloom-reports"),
    ("warning", "source_observation_old", "fhabs-results"),
]

# Every file the evaluator opens is recorded here while recording is enabled.
# Audit hooks cannot be removed, so the hook is installed once and gated.
_AUDIT = {"recording": False, "opened": []}


def _audit_hook(event: str, args: tuple) -> None:
    if _AUDIT["recording"] and event == "open" and args:
        target = args[0]
        if isinstance(target, (str, bytes, os.PathLike)):
            _AUDIT["opened"].append(os.path.realpath(os.fsdecode(target)))


sys.addaudithook(_audit_hook)


def utc(value: str) -> datetime:
    return pmc.parse_as_of(value)


def keys(findings: list) -> list[tuple[str, str, str]]:
    return sorted((f.severity, f.code, f.subject) for f in findings)


def codes(findings: list) -> list[str]:
    return sorted(f.code for f in findings)


class SnapshotFixture:
    """A scratch copy of the tracked public snapshot files."""

    def __init__(self, include_cli: bool = False) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="clw-pmc-")
        self.base = Path(self._tmp.name)
        self.root = self.base / "checkout"
        for relative in SNAPSHOT_FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO_ROOT / relative, target)
        if include_cli:
            (self.root / "scripts").mkdir()
            shutil.copyfile(
                SCRIPTS_DIR / "public_mirror_common.py",
                self.root / "scripts" / "public_mirror_common.py",
            )

    def __enter__(self) -> "SnapshotFixture":
        return self

    def __exit__(self, *exc_info: object) -> None:
        self._tmp.cleanup()

    def load(self, relative: str) -> object:
        return json.loads((self.root / relative).read_text(encoding="utf-8"))

    def save(self, relative: str, data: object) -> None:
        (self.root / relative).write_text(json.dumps(data, indent=2), encoding="utf-8")

    def edit(self, relative: str, change) -> None:
        """Apply an in-place mutation; the callable's return value is ignored."""
        data = self.load(relative)
        change(data)
        self.save(relative, data)

    def source(self, manifest: dict, source_id: str) -> dict:
        return next(s for s in manifest["sources"] if s.get("id") == source_id)

    def check(self, as_of: str = HISTORY_AS_OF) -> list:
        return pmc.check_snapshot(self.root, utc(as_of))

    def run_cli(self, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, "-B", str(self.root / "scripts" / "public_mirror_common.py"), *args],
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )


def setUpModule() -> None:
    tracked = (REPO_ROOT / "data" / "manifest.json").read_bytes()
    if tracked != PINNED_MANIFEST.read_bytes():
        raise AssertionError(
            "data/manifest.json no longer matches the pinned May 5, 2026 fixture. "
            "Update the historical expectations in this module with the reviewed refresh."
        )


class ReviewedHistoryTests(unittest.TestCase):
    def test_reviewed_history_warns_without_failing(self) -> None:
        with SnapshotFixture() as fx:
            findings = fx.check()
        self.assertEqual(keys(findings), HISTORY_FINDINGS)
        self.assertTrue(all(f.severity == "warning" for f in findings))
        messages = {f.subject: f.message for f in findings}
        self.assertIn("196", messages["data/manifest.json"])
        self.assertIn("240", messages["fhabs-bloom-reports"])
        self.assertIn("845", messages["fhabs-results"])

    def test_findings_are_immutable(self) -> None:
        finding = pmc.Finding("warning", "snapshot_old", "data/manifest.json", "m")
        with self.assertRaises(Exception):
            finding.code = "changed"  # type: ignore[misc]


class PacificCalendarTests(unittest.TestCase):
    BEFORE = "2026-05-20T06:59:59Z"  # 11:59:59 PM PDT, May 19
    AT = "2026-05-20T07:00:00Z"  # midnight PDT, May 20

    def snapshot_old(self, findings: list) -> list:
        return [f for f in findings if f.code == "snapshot_old"]

    def test_snapshot_age_changes_at_pacific_midnight(self) -> None:
        with SnapshotFixture() as fx:
            before = fx.check(self.BEFORE)
            at = fx.check(self.AT)
        self.assertEqual(self.snapshot_old(before), [])
        self.assertEqual(len(self.snapshot_old(at)), 1)
        self.assertIn("15 Pacific calendar days", self.snapshot_old(at)[0].message)
        self.assertNotIn("failure", {f.severity for f in before + at})

    def test_snapshot_age_ignores_process_time_zone(self) -> None:
        with SnapshotFixture(include_cli=True) as fx:
            for zone in ("UTC", "Asia/Tokyo", "America/Los_Angeles", "Pacific/Kiritimati", "Etc/GMT+12"):
                env = dict(os.environ, TZ=zone)
                with self.subTest(zone=zone):
                    before = fx.run_cli("--as-of", self.BEFORE, env=env)
                    at = fx.run_cli("--as-of", self.AT, env=env)
                    self.assertEqual((before.returncode, at.returncode), (0, 0), before.stderr + at.stderr)
                    before_codes = [f["code"] for f in json.loads(before.stdout)["findings"]]
                    at_codes = [f["code"] for f in json.loads(at.stdout)["findings"]]
                    self.assertNotIn("snapshot_old", before_codes)
                    self.assertEqual(at_codes.count("snapshot_old"), 1)


class SourceAgeTests(unittest.TestCase):
    AS_OF_VALUES = ("2026-05-05T09:00:00Z", HISTORY_AS_OF, "2031-01-01T00:00:00+00:00")

    def source_keys(self, observation_date: str, as_of: str) -> list:
        with SnapshotFixture() as fx:
            fx.edit(
                "data/manifest.json",
                lambda m: fx.source(m, "usgs-lake-level").update(latestObservationDate=observation_date),
            )
            findings = fx.check(as_of)
        return [k for k in keys(findings) if k[2] == "usgs-lake-level"]

    def test_source_age_uses_generation_day(self) -> None:
        expected = {
            "2026-04-21": [],
            "2026-04-20": [("warning", "source_observation_old", "usgs-lake-level")],
            "2026-05-06": [("failure", "observation_after_generation", "usgs-lake-level")],
        }
        for observation_date, expected_keys in expected.items():
            for as_of in self.AS_OF_VALUES:
                with self.subTest(observation_date=observation_date, as_of=as_of):
                    self.assertEqual(self.source_keys(observation_date, as_of), expected_keys)

    def test_offset_instant_observation_uses_its_pacific_day(self) -> None:
        # 2026-05-06T06:59:59Z is still May 5 in Pacific time.
        self.assertEqual(self.source_keys("2026-05-06T06:59:59Z", HISTORY_AS_OF), [])
        self.assertEqual(
            self.source_keys("2026-05-06T07:00:00Z", HISTORY_AS_OF),
            [("failure", "observation_after_generation", "usgs-lake-level")],
        )


class InvalidInputTests(unittest.TestCase):
    def test_invalid_dates_and_thresholds_fail_cleanly(self) -> None:
        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m.update(generatedAt="2026-05-05T01:44:50.0255703"))
            self.assertIn(("failure", "invalid_timestamp", "data/manifest.json"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit(
                "data/manifest.json",
                lambda m: fx.source(m, "usgs-lake-level").update(latestObservationDate="2026-02-30"),
            )
            self.assertIn(("failure", "invalid_observation_date", "usgs-lake-level"), keys(fx.check()))

        with SnapshotFixture() as fx:
            findings = fx.check("2026-05-05T08:44:50Z")  # before 01:44:50.0255703-07:00
            self.assertIn(("failure", "snapshot_after_as_of", "data/manifest.json"), keys(findings))
            self.assertNotIn("snapshot_old", codes(findings))

        for bad_limit in (True, 0, "14", -3, 14.5, None):
            with self.subTest(limit=bad_limit), SnapshotFixture() as fx:
                fx.edit("data/manifest.json", lambda m: m.update(sourceFreshnessMaxAgeDays=bad_limit))
                findings = fx.check()
                self.assertIn(("failure", "invalid_age_limit", "data/manifest.json"), keys(findings))
                self.assertNotIn("snapshot_old", codes(findings))

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m.pop("sourceFreshnessMaxAgeDays"))
            findings = fx.check()
            self.assertEqual(keys(findings), HISTORY_FINDINGS)
            snapshot_message = next(f.message for f in findings if f.code == "snapshot_old")
            self.assertIn("sourceFreshnessMaxAgeDays=14", snapshot_message)

    def test_timestamp_forms(self) -> None:
        accepted = {
            "2026-05-05T08:44:50Z",
            "2026-05-05T08:44:50.1Z",
            "2026-05-05T01:44:50.0255703-07:00",
            "2026-05-05T08:44:50.025570312+00:00",
        }
        rejected = {
            "2026-05-05T08:44:50",
            "2026-05-05",
            "2026-05-05 08:44:50Z",
            "2026-05-05T08:44:50z",
            "2026-05-05T24:00:00Z",
            "2026-05-05T08:44:60Z",
            "2026-02-29T08:44:50Z",
            "2026-05-05T08:44:50+24:00",
            "2026-05-05T08:44:50.Z",
            "2026-05-05T08:44:50.0255703123Z",
            "",
        }
        for value in accepted:
            with self.subTest(value=value):
                self.assertIsNotNone(pmc.parse_timestamp(value))
        for value in rejected | {None, 20260505, True}:
            with self.subTest(value=value):
                self.assertIsNone(pmc.parse_timestamp(value))

    def test_parse_as_of_requires_explicit_utc(self) -> None:
        self.assertEqual(pmc.parse_as_of("2026-11-17T12:00:00Z"), datetime(2026, 11, 17, 12, tzinfo=timezone.utc))
        self.assertEqual(pmc.parse_as_of("2026-11-17T12:00:00+00:00"), datetime(2026, 11, 17, 12, tzinfo=timezone.utc))
        for value in ("2026-11-17T12:00:00", "2026-11-17T04:00:00-08:00", "2026-11-17", "-00:00", "now"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                pmc.parse_as_of(value)

    def test_naive_as_of_is_rejected(self) -> None:
        with SnapshotFixture() as fx, self.assertRaises(ValueError):
            pmc.check_snapshot(fx.root, datetime(2026, 11, 17, 12))

    def test_malformed_manifests_never_raise(self) -> None:
        cases = {
            "missing manifest": (None, ("failure", "missing_file", "data/manifest.json")),
            "invalid JSON": ("{", ("failure", "invalid_json", "data/manifest.json")),
            "array manifest": ([], ("failure", "invalid_manifest", "data/manifest.json")),
            "sources not a list": (
                {"sources": {}},
                ("failure", "invalid_manifest", "data/manifest.json#/sources"),
            ),
            "outputs not a list": (
                {"outputs": "data/live.json"},
                ("failure", "invalid_manifest", "data/manifest.json#/outputs"),
            ),
            "source entry not an object": (
                {"sources": ["usgs-lake-level"]},
                ("failure", "invalid_manifest", "data/manifest.json#/sources/0"),
            ),
            "output entry not an object": (
                {"outputs": ["data/live.json"]},
                ("failure", "invalid_manifest", "data/manifest.json#/outputs/0"),
            ),
        }
        for label, (content, expected) in cases.items():
            with self.subTest(case=label), SnapshotFixture() as fx:
                path = fx.root / "data" / "manifest.json"
                if content is None:
                    path.unlink()
                elif isinstance(content, str):
                    path.write_text(content, encoding="utf-8")
                elif isinstance(content, list):
                    fx.save("data/manifest.json", content)
                else:
                    fx.edit("data/manifest.json", lambda m, c=content: m.update(c))
                findings = fx.check()
                self.assertIn(expected, keys(findings))

        source_cases = {
            "rowCount": (("29", True, 0, None), "invalid_row_count"),
            "status": (("", None, 7), "missing_source_status"),
            "latestObservationDate": (("", None), "missing_observation_date"),
        }
        for field, (values, code) in source_cases.items():
            for value in values:
                with self.subTest(field=field, value=value), SnapshotFixture() as fx:
                    fx.edit("data/manifest.json", lambda m, f=field, v=value: fx.source(m, "usgs-cole-creek-discharge").update({f: v}))
                    self.assertIn(("failure", code, "usgs-cole-creek-discharge"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m["sources"][0].pop("id"))
            findings = keys(fx.check())
            self.assertIn(("failure", "missing_source_id", "data/manifest.json#/sources/0"), findings)
            self.assertIn(("failure", "missing_source", "usgs-lake-level"), findings)

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: fx.source(m, "fhabs-results").update(status="error"))
            self.assertIn(("failure", "source_status_inconsistent", "data/manifest.json"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: fx.source(m, "fhabs-results").update(clearLakeRowCount=0))
            self.assertIn(("failure", "invalid_clear_lake_row_count", "fhabs-results"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.save("data/analytics.json", [1, 2, 3])
            self.assertIn(("failure", "invalid_output_data", "data/analytics.json"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit("data/reports.json", lambda d: d.pop("generatedAt"))
            self.assertIn(("failure", "invalid_timestamp", "data/reports.json"), keys(fx.check()))


class OutputGapTests(unittest.TestCase):
    BASE = "2026-05-05T08:44:50.0000000Z"

    def gap_keys(self, manifest_stamp: str, output_stamp: str, output: str = "data/reports.json") -> list:
        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m.update(generatedAt=manifest_stamp))
            for relative in SNAPSHOT_FILES[1:]:
                stamp = output_stamp if relative == output else manifest_stamp
                fx.edit(relative, lambda d, s=stamp: d.update(generatedAt=s))
            findings = fx.check()
        return [k for k in keys(findings) if k[1] == "output_refresh_gap"]

    def test_output_gap_is_strict(self) -> None:
        gap = [("failure", "output_refresh_gap", "data/reports.json")]
        cases = [
            (self.BASE, self.BASE, []),
            (self.BASE, "2026-05-05T08:49:50.0000000Z", []),
            (self.BASE, "2026-05-05T08:49:50.000000Z", []),
            (self.BASE, "2026-05-05T08:49:50.0010000Z", gap),
            (self.BASE, "2026-05-05T08:49:50.001Z", gap),
            (self.BASE, "2026-05-05T08:49:50.0000001Z", gap),
            (self.BASE, "2026-05-05T01:49:50.0000001-07:00", gap),
            (self.BASE, "2026-05-05T08:39:50.0000000Z", []),
            (self.BASE, "2026-05-05T08:39:49.9999999Z", gap),
            ("2026-05-05T08:44:50.0000001Z", "2026-05-05T08:49:50.0000001Z", []),
            ("2026-05-05T08:44:50.0000001Z", "2026-05-05T08:49:50.0000002Z", gap),
            ("2026-05-05T08:44:50.0000009Z", "2026-05-05T08:49:50.0000010Z", gap),
            ("2026-05-05T08:44:50.0000009Z", "2026-05-05T08:39:50.0000009Z", []),
            ("2026-05-05T08:44:50.0000009Z", "2026-05-05T08:39:50.0000008Z", gap),
        ]
        for manifest_stamp, output_stamp, expected in cases:
            with self.subTest(manifest=manifest_stamp, output=output_stamp):
                self.assertEqual(self.gap_keys(manifest_stamp, output_stamp), expected)

    def test_live_output_gap_is_counted_once(self) -> None:
        late = "2026-05-05T08:49:50.0010000Z"
        self.assertEqual(
            self.gap_keys(self.BASE, late, output="data/live.json"),
            [("failure", "output_refresh_gap", "data/live.json")],
        )
        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m.update(generatedAt=self.BASE))
            fx.edit("data/live.json", lambda d: d.update(generatedAt=late))
            fx.edit(
                "data/manifest.json",
                lambda m: m.update(outputs=[o for o in m["outputs"] if o["file"] != "data/live.json"]),
            )
            found = keys(fx.check())
        self.assertIn(("failure", "missing_output", "data/live.json"), found)
        self.assertEqual([k for k in found if k[1] == "output_refresh_gap"], [("failure", "output_refresh_gap", "data/live.json")])


class ManifestIntegrityTests(unittest.TestCase):
    def test_manifest_integrity_uses_stronger_existing_checks(self) -> None:
        with SnapshotFixture() as fx:
            fx.edit(
                "data/manifest.json",
                lambda m: m.update(outputs=[o for o in m["outputs"] if o["file"] != "data/analytics.json"]),
            )
            self.assertIn(("failure", "missing_output", "data/analytics.json"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit(
                "data/manifest.json",
                lambda m: next(o for o in m["outputs"] if o["file"] == "data/reports.json").update(recordCount=231),
            )
            self.assertIn(("failure", "output_count_mismatch", "data/reports.json"), keys(fx.check()))

        for output, change in (
            ("data/live.json", lambda d: d["mapMarkers"].pop()),
            ("data/analytics.json", lambda d: d["observationCoverage"].pop()),
            ("data/sites-normalized.json", lambda d: d["sites"].pop()),
            ("data/observations.json", lambda d: d["records"].pop()),
        ):
            with self.subTest(output=output), SnapshotFixture() as fx:
                fx.edit(output, change)
                self.assertIn(("failure", "output_count_mismatch", output), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit(
                "data/manifest.json",
                lambda m: next(o for o in m["outputs"] if o["file"] == "data/reports.json").update(recordCount=0),
            )
            self.assertIn(("failure", "invalid_record_count", "data/reports.json"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: fx.source(m, "fhabs-results").pop("resourceDate"))
            self.assertIn(("failure", "invalid_fhabs_resource", "fhabs-results"), keys(fx.check()))

        for field, value in (
            ("resourceAgeDays", -1),
            ("resourceAgeDays", None),
            ("resourceAgeDays", "1"),
            ("resourceDate", "2026-05-06"),
            ("resourceDate", "2026-13-01"),
        ):
            with self.subTest(field=field, value=value), SnapshotFixture() as fx:
                fx.edit("data/manifest.json", lambda m, f=field, v=value: fx.source(m, "fhabs-bloom-reports").update({f: v}))
                self.assertIn(("failure", "invalid_fhabs_resource", "fhabs-bloom-reports"), keys(fx.check()))

        with SnapshotFixture() as fx:
            fx.edit("data/manifest.json", lambda m: m.update(sources=[s for s in m["sources"] if s["id"] != "fhabs-results"]))
            self.assertIn(("failure", "missing_source", "fhabs-results"), keys(fx.check()))

        with SnapshotFixture() as fx:
            (fx.root / "data" / "reports.json").unlink()
            self.assertIn(("failure", "missing_file", "data/reports.json"), keys(fx.check()))

    def test_unsafe_output_paths_are_never_read(self) -> None:
        with SnapshotFixture() as fx:
            outside = fx.base / "outside.json"
            outside.write_text('{"generatedAt": "2026-05-05T08:44:50Z", "records": [1]}', encoding="utf-8")
            unsafe = [
                "../outside.json",
                str(outside),
                outside.as_posix(),
                "data/../../outside.json",
                "data\\..\\..\\outside.json",
                "data/private/test-only.json",
                "data/reports.csv",
                "",
            ]
            fx.edit(
                "data/manifest.json",
                lambda m: m["outputs"].extend({"file": path, "recordCount": 1} for path in unsafe),
            )
            _AUDIT["opened"].clear()
            _AUDIT["recording"] = True
            try:
                findings = keys(fx.check())
            finally:
                _AUDIT["recording"] = False
            opened = list(_AUDIT["opened"])

        for path in unsafe:
            with self.subTest(path=path):
                subject = path or "data/manifest.json#/outputs/{}".format(5 + unsafe.index(path))
                self.assertIn(("failure", "invalid_output_path", subject), findings)
        self.assertNotIn(os.path.realpath(outside), opened)
        self.assertTrue(any(p.endswith(os.path.join("data", "manifest.json")) for p in opened), opened)
        self.assertFalse(any(k[1] in {"missing_file", "invalid_json"} for k in findings), findings)

    def test_symlinked_output_cannot_escape_data(self) -> None:
        with SnapshotFixture() as fx:
            outside = fx.base / "outside.json"
            outside.write_text('{"generatedAt": "2026-05-05T08:44:50Z", "records": [1]}', encoding="utf-8")
            link = fx.root / "data" / "escape.json"
            try:
                link.symlink_to(outside)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"symlinks unavailable: {exc}")
            fx.edit("data/manifest.json", lambda m: m["outputs"].append({"file": "data/escape.json", "recordCount": 1}))
            _AUDIT["opened"].clear()
            _AUDIT["recording"] = True
            try:
                findings = keys(fx.check())
            finally:
                _AUDIT["recording"] = False
            self.assertIn(("failure", "invalid_output_path", "data/escape.json"), findings)
            self.assertNotIn(os.path.realpath(outside), _AUDIT["opened"])


class TimezoneDataTests(unittest.TestCase):
    def test_requirements_pin_matches_evaluator(self) -> None:
        lines = (REPO_ROOT / "requirements-public-mirror.txt").read_text(encoding="utf-8").splitlines()
        pins = [line.split()[0] for line in lines if line.startswith("tzdata==")]
        self.assertEqual(pins, [f"tzdata=={pmc.PINNED_TZDATA_VERSION}"])
        self.assertEqual(pmc.PINNED_TZDATA_VERSION, "2026.6")

    def test_pinned_zone_comes_from_tzdata_package(self) -> None:
        zone = pmc.load_pacific_zone()
        self.assertEqual(str(zone), "America/Los_Angeles")
        self.assertEqual(datetime(2026, 7, 1, 12, tzinfo=timezone.utc).astimezone(zone).utcoffset().total_seconds(), -7 * 3600)
        self.assertEqual(datetime(2026, 12, 1, 12, tzinfo=timezone.utc).astimezone(zone).utcoffset().total_seconds(), -8 * 3600)

    def test_missing_or_mismatched_zone_data_is_a_diagnosed_failure(self) -> None:
        failures = {
            "not installed": mock.patch.object(
                pmc.importlib_metadata, "version", side_effect=pmc.importlib_metadata.PackageNotFoundError("tzdata")
            ),
            "wrong version": mock.patch.object(pmc.importlib_metadata, "version", return_value="2025.2"),
            "missing zone file": mock.patch.object(pmc, "PACIFIC_ZONE_RESOURCE", ("zoneinfo", "America", "Nowhere")),
        }
        for label, patcher in failures.items():
            with self.subTest(case=label), SnapshotFixture() as fx, patcher:
                findings = fx.check()
                self.assertIn(("failure", "timezone_data_unavailable", "tzdata"), keys(findings))
                self.assertNotIn("snapshot_old", codes(findings))
                tz_message = next(f.message for f in findings if f.code == "timezone_data_unavailable")
                self.assertIn("requirements-public-mirror.txt", tz_message)


class CommandTests(unittest.TestCase):
    def test_bridge_reports_versioned_json(self) -> None:
        with SnapshotFixture(include_cli=True) as fx:
            result = fx.run_cli("--as-of", HISTORY_AS_OF)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            self.assertEqual(result.stdout.count("\n"), 1)
            report = json.loads(result.stdout)
            self.assertEqual(sorted(report), ["findings", "schema_version"])
            self.assertEqual(report["schema_version"], 1)
            self.assertEqual(
                sorted((f["severity"], f["code"], f["subject"]) for f in report["findings"]),
                HISTORY_FINDINGS,
            )
            for finding in report["findings"]:
                self.assertEqual(sorted(finding), ["code", "message", "severity", "subject"])

            fx.edit("data/manifest.json", lambda m: fx.source(m, "usgs-lake-level").update(latestObservationDate="2026-05-06"))
            failed = fx.run_cli("--as-of", HISTORY_AS_OF)
            self.assertEqual(failed.returncode, 1)
            self.assertIn("observation_after_generation", failed.stdout)
            self.assertNotIn("Traceback", failed.stderr)

            (fx.root / "data" / "manifest.json").write_text("{", encoding="utf-8")
            broken = fx.run_cli("--as-of", HISTORY_AS_OF)
            self.assertEqual(broken.returncode, 1)
            self.assertEqual(json.loads(broken.stdout)["findings"][0]["code"], "invalid_json")
            self.assertNotIn("Traceback", broken.stderr)

    def test_invalid_arguments_exit_2_on_stderr(self) -> None:
        with SnapshotFixture(include_cli=True) as fx:
            for args in (
                ("--as-of", "2026-11-17T12:00:00"),
                ("--as-of", "2026-11-17T04:00:00-08:00"),
                ("--as-of",),
                ("--unknown",),
                ("extra",),
            ):
                with self.subTest(args=args):
                    result = fx.run_cli(*args)
                    self.assertEqual(result.returncode, 2)
                    self.assertEqual(result.stdout, "")
                    self.assertTrue(result.stderr.strip())
                    self.assertNotIn("Traceback", result.stderr)

    def test_default_clock_is_sampled_once(self) -> None:
        sampled = datetime(2026, 11, 17, 12, tzinfo=timezone.utc)
        with SnapshotFixture() as fx, mock.patch.object(pmc, "PROJECT_ROOT", fx.root), mock.patch.object(
            pmc, "utc_now", return_value=sampled
        ) as clock, mock.patch("sys.stdout") as stdout:
            exit_code = pmc.main([])
        self.assertEqual(exit_code, 0)
        clock.assert_called_once_with()
        written = "".join(call.args[0] for call in stdout.write.call_args_list)
        self.assertEqual(sorted((f["severity"], f["code"], f["subject"]) for f in json.loads(written)["findings"]), HISTORY_FINDINGS)


if __name__ == "__main__":
    unittest.main()
