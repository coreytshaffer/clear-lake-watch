"""Shared snapshot evaluator for the Clear Lake Watch public-mirror validators.

Both public-mirror commands use this module for snapshot age, source
observation age, and manifest integrity:

- ``scripts/validate-public-mirror.py`` imports :func:`check_snapshot`.
- ``scripts/validate-public-mirror.ps1`` runs this file as an internal command
  and imports the JSON report it prints.

Internal command::

    python scripts/public_mirror_common.py [--as-of UTC_INSTANT]

It prints one JSON object, ``{"schema_version": 1, "findings": [...]}``, on
stdout and exits 0 when no finding is a failure, 1 when at least one finding
is a failure, and 2 for invalid arguments (reported on stderr). Without
``--as-of`` the evaluation clock is sampled once from the system UTC clock.

Evaluation is offline and read-only. It reads only ``data/manifest.json``,
``data/live.json``, and manifest outputs whose paths pass the safety check.
Every read must resolve to a file directly inside the checkout's own
``data/`` directory, so symlinks cannot redirect it outside the checkout. Calendar ages use Pacific calendar days
from the pinned ``tzdata`` package, never host time-zone data. A reviewed
public mirror may be old: snapshot and source age produce warnings, while
structural problems produce failures. See docs/source-freshness-validation.md
for the finding codes.
"""

from __future__ import annotations

import argparse
import functools
import importlib.metadata as importlib_metadata
import importlib.resources
import json
import math
import os
import re
import sys
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, List, Optional, Sequence
from zoneinfo import ZoneInfo

SCHEMA_VERSION = 1
WARNING = "warning"
FAILURE = "failure"

MIN_PYTHON = (3, 11)
PINNED_TZDATA_VERSION = "2026.6"
PACIFIC_ZONE_KEY = "America/Los_Angeles"
PACIFIC_ZONE_RESOURCE = ("zoneinfo", "America", "Los_Angeles")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = "data/manifest.json"
LIVE_PATH = "data/live.json"
AGE_LIMIT_FIELD = "sourceFreshnessMaxAgeDays"
DEFAULT_AGE_LIMIT_DAYS = 14

# Outputs from one refresh pass must be generated within five minutes of the
# manifest. The comparison uses 100-nanosecond ticks so the seventh fractional
# digit written by PowerShell's round-trip format is never lost.
TICKS_PER_MICROSECOND = 10
TICKS_PER_SECOND = 10_000_000
MAX_OUTPUT_GAP_TICKS = 5 * 60 * TICKS_PER_SECOND

EXPECTED_SOURCE_IDS = (
    "usgs-lake-level",
    "usgs-cole-creek-discharge",
    "fhabs-bloom-reports",
    "fhabs-results",
)

EXPECTED_OUTPUT_FILES = (
    "data/live.json",
    "data/reports.json",
    "data/observations.json",
    "data/sites-normalized.json",
    "data/analytics.json",
)

# Record-count projections, matching the PowerShell validator: live cards plus
# map markers, report records, observation records, normalized sites, and the
# three analytics arrays.
OUTPUT_COUNT_FIELDS = {
    "data/live.json": ("liveCards", "mapMarkers"),
    "data/reports.json": ("records",),
    "data/observations.json": ("records",),
    "data/sites-normalized.json": ("sites",),
    "data/analytics.json": (
        "reportTrendByYear",
        "advisoryDistributionByArm",
        "observationCoverage",
    ),
}

# Every snapshot file the evaluator reads names one JSON file directly inside data/.
SAFE_SNAPSHOT_PATH = re.compile(r"data/[A-Za-z0-9._-]+\.json")

_DATE_ONLY = re.compile(r"(\d{4})-(\d{2})-(\d{2})", re.ASCII)
_INSTANT = re.compile(
    r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})",
    re.ASCII,
)


@dataclass(frozen=True)
class Finding:
    """One evaluator result. Parity is compared by (severity, code, subject)."""

    severity: str
    code: str
    subject: str
    message: str


@dataclass(frozen=True)
class Instant:
    """An offset-bearing timestamp converted to UTC.

    ``utc`` keeps whole microseconds; ``tick`` is the seventh fractional digit
    (0-9), the remaining 100-nanosecond ticks. Digits past the seventh are
    truncated.
    """

    utc: datetime
    tick: int


class TimezoneDataError(RuntimeError):
    """The pinned America/Los_Angeles zone data could not be loaded."""


def parse_timestamp(value: object) -> Optional[Instant]:
    """Parse an ISO 8601 instant with a ``Z`` or ``+HH:MM`` offset.

    Returns None for anything else, including offset-free datetimes,
    date-only strings, impossible dates or times, and non-strings.
    """

    if not isinstance(value, str):
        return None
    match = _INSTANT.fullmatch(value)
    if not match:
        return None
    year, month, day, hour, minute, second = (int(part) for part in match.groups()[:6])
    fraction = (match.group(7) or "").ljust(7, "0")[:7]
    offset_text = match.group(8)
    if offset_text == "Z":
        offset = timedelta(0)
    else:
        offset_hours, offset_minutes = int(offset_text[1:3]), int(offset_text[4:6])
        if offset_hours > 23 or offset_minutes > 59:
            return None
        offset = timedelta(hours=offset_hours, minutes=offset_minutes)
        if offset_text[0] == "-":
            offset = -offset
    try:
        local = datetime(
            year, month, day, hour, minute, second, int(fraction[:6]), tzinfo=timezone(offset)
        )
        utc = local.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        return None
    return Instant(utc=utc, tick=int(fraction[6]))


def parse_as_of(value: str) -> datetime:
    """Parse an explicit evaluation clock: a UTC instant ending in Z or +00:00."""

    instant = parse_timestamp(value)
    if instant is None or not (value.endswith("Z") or value.endswith("+00:00")):
        raise ValueError(
            "expected a UTC instant ending in Z or +00:00, such as 2026-11-17T12:00:00Z; "
            f"got {value!r}"
        )
    return instant.utc


def utc_now() -> datetime:
    """Sample the system UTC clock. Called at most once per command."""

    return datetime.now(timezone.utc)


def load_pacific_zone() -> ZoneInfo:
    """Load America/Los_Angeles from the pinned tzdata package only.

    The zone file is read through importlib.resources so host time-zone data
    (TZPATH, /usr/share/zoneinfo, the TZ variable) cannot override the pin.
    """

    remedy = "Install it with: python -m pip install -r requirements-public-mirror.txt"
    try:
        installed = importlib_metadata.version("tzdata")
    except importlib_metadata.PackageNotFoundError as exc:
        raise TimezoneDataError(
            f"The pinned tzdata=={PINNED_TZDATA_VERSION} package is not installed. {remedy}"
        ) from exc
    if installed != PINNED_TZDATA_VERSION:
        raise TimezoneDataError(
            f"tzdata {installed} is installed, but the evaluator requires the pinned "
            f"tzdata=={PINNED_TZDATA_VERSION}. {remedy}"
        )
    try:
        resource = functools.reduce(
            lambda node, part: node.joinpath(part),
            PACIFIC_ZONE_RESOURCE,
            importlib.resources.files("tzdata"),
        )
        with resource.open("rb") as handle:
            return ZoneInfo.from_file(handle, key=PACIFIC_ZONE_KEY)
    except (ImportError, OSError, ValueError) as exc:
        raise TimezoneDataError(
            f"Unable to load {PACIFIC_ZONE_KEY} from the pinned tzdata=={PINNED_TZDATA_VERSION} "
            f"package ({exc}). {remedy}"
        ) from exc


def parse_calendar_date(value: object, zone: ZoneInfo) -> Optional[date]:
    """Return a real calendar date from ``YYYY-MM-DD`` or an instant's Pacific day."""

    if not isinstance(value, str):
        return None
    match = _DATE_ONLY.fullmatch(value)
    if match:
        try:
            return date(*(int(part) for part in match.groups()))
        except ValueError:
            return None
    instant = parse_timestamp(value)
    if instant is None:
        return None
    return instant.utc.astimezone(zone).date()


def tick_gap(left: Instant, right: Instant) -> int:
    """Signed elapsed time from ``left`` to ``right`` in 100-nanosecond ticks."""

    delta = right.utc - left.utc
    microseconds = (delta.days * 86_400 + delta.seconds) * 1_000_000 + delta.microseconds
    return microseconds * TICKS_PER_MICROSECOND + (right.tick - left.tick)


def _format_ticks(ticks: int) -> str:
    whole, remainder = divmod(abs(ticks), TICKS_PER_SECOND)
    return f"{whole}.{remainder:07d} seconds"


def _is_blank(value: object) -> bool:
    return value is None or (isinstance(value, str) and not value.strip())


def _is_positive_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
        and value > 0
    )


def _is_json_integer(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _array_count(value: object) -> int:
    # Mirrors PowerShell's @($Value).Count: null is 0, an array is its length,
    # and any other single value counts once.
    if value is None:
        return 0
    if isinstance(value, list):
        return len(value)
    return 1


def _json_type(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "a boolean"
    if isinstance(value, (int, float)):
        return "a number"
    if isinstance(value, str):
        return "a string"
    if isinstance(value, list):
        return "an array"
    return "an object"


def _reject_constant(name: str) -> Any:
    raise ValueError(f"non-standard JSON constant {name}")


def resolve_snapshot_file(root: Path, relative: str) -> Optional[str]:
    """Return the real path of ``relative`` if it stays inside the checkout.

    ``relative`` must name a JSON file directly inside ``data/``. The lexical
    check runs first, so an unsafe path is never touched on disk. A path that
    passes is then resolved against the checkout's real path: ``data/`` must
    be the checkout's own directory, not a symlink elsewhere, and the file must
    resolve directly inside it. Returns None otherwise.
    """

    if not isinstance(relative, str) or not SAFE_SNAPSHOT_PATH.fullmatch(relative):
        return None
    root_real = os.path.realpath(root)
    expected_data = os.path.join(root_real, "data")
    data_real = os.path.realpath(expected_data)
    if os.path.normcase(data_real) != os.path.normcase(expected_data):
        return None
    target = os.path.realpath(os.path.join(root_real, *relative.split("/")))
    if os.path.normcase(os.path.dirname(target)) != os.path.normcase(data_real):
        return None
    return target


# Returned by _Evaluation.load_json when a file could not be read or parsed;
# a finding has already been recorded. JSON null loads as None, so the two
# outcomes stay distinct.
_LOAD_FAILED = object()


class _Evaluation:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.findings: List[Finding] = []

    def add(self, severity: str, code: str, subject: str, message: str) -> None:
        self.findings.append(Finding(severity, code, subject, message))

    def fail(self, code: str, subject: str, message: str) -> None:
        self.add(FAILURE, code, subject, message)

    def warn(self, code: str, subject: str, message: str) -> None:
        self.add(WARNING, code, subject, message)

    def load_json(self, relative: str) -> Any:
        """Parse one snapshot file, or record a finding and return _LOAD_FAILED."""

        path = resolve_snapshot_file(self.root, relative)
        if path is None:
            self.fail(
                "unsafe_snapshot_path",
                relative,
                "Snapshot file does not resolve directly inside this checkout's data/ directory; it was not read.",
            )
            return _LOAD_FAILED
        try:
            with open(path, encoding="utf-8-sig") as handle:
                text = handle.read()
        except FileNotFoundError:
            self.fail("missing_file", relative, f"Missing required file: {relative}")
            return _LOAD_FAILED
        except (OSError, UnicodeDecodeError) as exc:
            self.fail("invalid_json", relative, f"Unable to read {relative}: {exc}")
            return _LOAD_FAILED
        try:
            return json.loads(text, parse_constant=_reject_constant)
        except ValueError as exc:
            self.fail("invalid_json", relative, f"Invalid JSON in {relative}: {exc}")
            return _LOAD_FAILED


def check_snapshot(root: Path, as_of: datetime) -> list[Finding]:
    """Evaluate snapshot age, source observation age, and manifest integrity.

    ``as_of`` must be timezone-aware. Malformed inputs produce findings rather
    than exceptions.
    """

    if not isinstance(as_of, datetime) or as_of.tzinfo is None or as_of.utcoffset() is None:
        raise ValueError("as_of must be a timezone-aware datetime")
    as_of_utc = as_of.astimezone(timezone.utc)
    ev = _Evaluation(Path(root))

    if sys.version_info < MIN_PYTHON:
        ev.fail(
            "unsupported_python",
            "python",
            f"Python {'.'.join(map(str, MIN_PYTHON))} or newer is required; running "
            f"{sys.version_info.major}.{sys.version_info.minor}.",
        )

    zone: Optional[ZoneInfo]
    try:
        zone = load_pacific_zone()
    except TimezoneDataError as exc:
        zone = None
        ev.fail(
            "timezone_data_unavailable",
            "tzdata",
            f"Calendar-day age checks were not evaluated. {exc}",
        )

    manifest = ev.load_json(MANIFEST_PATH)
    if manifest is _LOAD_FAILED:
        return ev.findings
    if not isinstance(manifest, dict):
        ev.fail(
            "invalid_manifest",
            MANIFEST_PATH,
            f"The manifest must be a JSON object; found {_json_type(manifest)}.",
        )
        return ev.findings

    generation = parse_timestamp(manifest.get("generatedAt"))
    if generation is None:
        ev.fail(
            "invalid_timestamp",
            MANIFEST_PATH,
            "Manifest generatedAt is missing or is not an ISO 8601 timestamp with a UTC offset: "
            f"{manifest.get('generatedAt')!r}",
        )
    generation_day = (
        generation.utc.astimezone(zone).date() if generation is not None and zone is not None else None
    )

    limit = _age_limit(ev, manifest)
    _check_snapshot_age(ev, generation, generation_day, as_of_utc, zone, limit)
    _check_sources(ev, manifest, generation_day, zone, limit)
    _check_outputs(ev, manifest, generation)
    return ev.findings


def _age_limit(ev: _Evaluation, manifest: dict) -> Optional[int]:
    if AGE_LIMIT_FIELD not in manifest:
        return DEFAULT_AGE_LIMIT_DAYS
    value = manifest[AGE_LIMIT_FIELD]
    if _is_json_integer(value) and value > 0:
        return value
    ev.fail(
        "invalid_age_limit",
        MANIFEST_PATH,
        f"{AGE_LIMIT_FIELD} must be a positive JSON integer when present; found {json.dumps(value)}. "
        "Age warnings were not evaluated.",
    )
    return None


def _check_snapshot_age(
    ev: _Evaluation,
    generation: Optional[Instant],
    generation_day: Optional[date],
    as_of_utc: datetime,
    zone: Optional[ZoneInfo],
    limit: Optional[int],
) -> None:
    if generation is None:
        return
    if (as_of_utc, 0) < (generation.utc, generation.tick):
        ev.fail(
            "snapshot_after_as_of",
            MANIFEST_PATH,
            f"Manifest generatedAt {generation.utc.isoformat()} is after the evaluation clock "
            f"{as_of_utc.isoformat()}.",
        )
        return
    if zone is None or generation_day is None or limit is None:
        return
    age_days = (as_of_utc.astimezone(zone).date() - generation_day).days
    if age_days > limit:
        ev.warn(
            "snapshot_old",
            MANIFEST_PATH,
            f"Dashboard snapshot is {age_days} Pacific calendar days old, which exceeds "
            f"{AGE_LIMIT_FIELD}={limit}. Keep static-snapshot language visible.",
        )


def _check_sources(
    ev: _Evaluation,
    manifest: dict,
    generation_day: Optional[date],
    zone: Optional[ZoneInfo],
    limit: Optional[int],
) -> None:
    sources = manifest.get("sources")
    if not isinstance(sources, list):
        ev.fail("invalid_manifest", f"{MANIFEST_PATH}#/sources", "Manifest sources must be a list.")
        return

    seen_ids = set()
    non_ok_ids = []
    for index, source in enumerate(sources):
        pointer = f"{MANIFEST_PATH}#/sources/{index}"
        if not isinstance(source, dict):
            ev.fail("invalid_manifest", pointer, "Manifest source entry must be an object.")
            continue
        status = source.get("status")
        source_id = source.get("id")
        if not isinstance(source_id, str) or not source_id.strip():
            ev.fail("missing_source_id", pointer, "Manifest source is missing id.")
            if status != "ok":
                non_ok_ids.append(pointer)
            continue
        seen_ids.add(source_id)
        if status != "ok":
            non_ok_ids.append(source_id)
        if not isinstance(status, str) or not status.strip():
            ev.fail("missing_source_status", source_id, "Manifest source is missing status.")
        if not _is_positive_number(source.get("rowCount")):
            ev.fail("invalid_row_count", source_id, "Manifest source must have a positive numeric rowCount.")
        _check_observation_date(ev, source_id, source.get("latestObservationDate"), generation_day, zone, limit)
        if source_id.lower().startswith("fhabs-"):
            _check_fhabs_source(ev, source_id, source, generation_day, zone)

    for expected_id in EXPECTED_SOURCE_IDS:
        if expected_id not in seen_ids:
            ev.fail("missing_source", expected_id, "Manifest is missing expected source.")

    if manifest.get("status") == "ok" and non_ok_ids:
        ev.fail(
            "source_status_inconsistent",
            MANIFEST_PATH,
            "Manifest status is ok, but one or more sources are not ok: " + ", ".join(non_ok_ids),
        )


def _check_observation_date(
    ev: _Evaluation,
    source_id: str,
    value: object,
    generation_day: Optional[date],
    zone: Optional[ZoneInfo],
    limit: Optional[int],
) -> None:
    if _is_blank(value):
        ev.fail("missing_observation_date", source_id, "Manifest source is missing latestObservationDate.")
        return
    if zone is None:
        return
    observed = parse_calendar_date(value, zone)
    if observed is None:
        ev.fail(
            "invalid_observation_date",
            source_id,
            f"latestObservationDate {value!r} is not a real YYYY-MM-DD date or offset-bearing timestamp.",
        )
        return
    if generation_day is None:
        return
    age_days = (generation_day - observed).days
    if age_days < 0:
        ev.fail(
            "observation_after_generation",
            source_id,
            f"latestObservationDate {observed.isoformat()} is after the snapshot generation day "
            f"{generation_day.isoformat()} (Pacific).",
        )
    elif limit is not None and age_days > limit:
        ev.warn(
            "source_observation_old",
            source_id,
            f"Latest observation {observed.isoformat()} is {age_days} days older than the snapshot "
            f"generation day {generation_day.isoformat()} (Pacific); keep stale-source language visible.",
        )


def _check_fhabs_source(
    ev: _Evaluation,
    source_id: str,
    source: dict,
    generation_day: Optional[date],
    zone: Optional[ZoneInfo],
) -> None:
    if not _is_positive_number(source.get("clearLakeRowCount")):
        ev.fail(
            "invalid_clear_lake_row_count",
            source_id,
            "FHABS source must have a positive numeric clearLakeRowCount.",
        )

    resource_date = source.get("resourceDate")
    if _is_blank(resource_date):
        ev.fail(
            "invalid_fhabs_resource",
            source_id,
            "FHABS source must include resourceDate for FHABS freshness validation.",
        )
    elif zone is not None:
        resource_day = parse_calendar_date(resource_date, zone)
        if resource_day is None:
            ev.fail(
                "invalid_fhabs_resource",
                source_id,
                f"FHABS resourceDate {resource_date!r} is not a real date.",
            )
        elif generation_day is not None and resource_day > generation_day:
            ev.fail(
                "invalid_fhabs_resource",
                source_id,
                f"FHABS resourceDate {resource_day.isoformat()} is after the snapshot generation day "
                f"{generation_day.isoformat()} (Pacific).",
            )

    resource_age = source.get("resourceAgeDays")
    if resource_age is None:
        ev.fail(
            "invalid_fhabs_resource",
            source_id,
            "FHABS source must include resourceAgeDays for FHABS freshness validation.",
        )
    elif not _is_json_integer(resource_age):
        ev.fail(
            "invalid_fhabs_resource",
            source_id,
            f"FHABS resourceAgeDays must be a whole number of days; found {json.dumps(resource_age)}.",
        )
    elif resource_age < 0:
        ev.fail("invalid_fhabs_resource", source_id, "FHABS resourceAgeDays cannot be negative.")


def _check_outputs(ev: _Evaluation, manifest: dict, generation: Optional[Instant]) -> None:
    outputs = manifest.get("outputs")
    listed: List[tuple] = []
    rejected = set()
    if isinstance(outputs, list):
        for index, entry in enumerate(outputs):
            pointer = f"{MANIFEST_PATH}#/outputs/{index}"
            if not isinstance(entry, dict):
                ev.fail("invalid_manifest", pointer, "Manifest output entry must be an object.")
                continue
            relative = entry.get("file")
            if not isinstance(relative, str) or not relative:
                ev.fail("invalid_output_path", pointer, "Manifest output is missing file.")
                continue
            if resolve_snapshot_file(ev.root, relative) is None:
                rejected.add(relative)
                ev.fail(
                    "invalid_output_path",
                    relative,
                    "Manifest output file must name a JSON file directly inside this checkout's data/ "
                    "directory (forward slashes, no traversal, no symlink out of the checkout); "
                    "it was not read.",
                )
                continue
            listed.append((relative, entry))
        listed_files = {relative for relative, _ in listed}
        for expected in EXPECTED_OUTPUT_FILES:
            if expected not in listed_files:
                ev.fail("missing_output", expected, "Manifest is missing expected output entry.")
    else:
        ev.fail("invalid_manifest", f"{MANIFEST_PATH}#/outputs", "Manifest outputs must be a list.")

    # data/live.json is always compared with the manifest, once, whether or
    # not the manifest lists it. A listed path already rejected as unsafe is
    # not read or reported again.
    gap_files = [relative for relative, _ in listed]
    if LIVE_PATH not in rejected:
        gap_files.append(LIVE_PATH)
    loaded = {}
    for relative in dict.fromkeys(gap_files):
        data = ev.load_json(relative)
        if data is _LOAD_FAILED:
            continue
        if not isinstance(data, dict):
            ev.fail(
                "invalid_output_data",
                relative,
                f"Output file must contain a JSON object; found {_json_type(data)}.",
            )
            continue
        loaded[relative] = data
        stamp = parse_timestamp(data.get("generatedAt"))
        if stamp is None:
            ev.fail(
                "invalid_timestamp",
                relative,
                "Output generatedAt is missing or is not an ISO 8601 timestamp with a UTC offset: "
                f"{data.get('generatedAt')!r}",
            )
        elif generation is not None:
            gap = tick_gap(generation, stamp)
            if abs(gap) > MAX_OUTPUT_GAP_TICKS:
                ev.fail(
                    "output_refresh_gap",
                    relative,
                    "Output appears to come from a different refresh pass than the manifest. "
                    f"Gap: {_format_ticks(gap)}; limit: 300 seconds.",
                )

    for relative, entry in listed:
        declared = entry.get("recordCount")
        if not _is_positive_number(declared):
            ev.fail("invalid_record_count", relative, "Manifest output must have a positive numeric recordCount.")
            continue
        data = loaded.get(relative)
        fields = OUTPUT_COUNT_FIELDS.get(relative)
        if data is None or fields is None:
            continue
        computed = sum(_array_count(data.get(field)) for field in fields)
        if declared != computed:
            ev.fail(
                "output_count_mismatch",
                relative,
                f"Manifest recordCount {json.dumps(declared)} does not match computed count {computed}.",
            )


def findings_report(findings: Iterable[Finding]) -> dict:
    return {"schema_version": SCHEMA_VERSION, "findings": [asdict(f) for f in findings]}


def has_failure(findings: Iterable[Finding]) -> bool:
    return any(f.severity == FAILURE for f in findings)


def _as_of_argument(value: str) -> datetime:
    try:
        return parse_as_of(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from None


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="public_mirror_common.py",
        description="Internal shared snapshot evaluator for the public-mirror validators.",
    )
    parser.add_argument(
        "--as-of",
        type=_as_of_argument,
        metavar="UTC_INSTANT",
        help="Evaluation clock, for example 2026-11-17T12:00:00Z. Defaults to one sample of the system UTC clock.",
    )
    args = parser.parse_args(argv)
    as_of = args.as_of if args.as_of is not None else utc_now()
    findings = check_snapshot(PROJECT_ROOT, as_of)
    sys.stdout.write(json.dumps(findings_report(findings), ensure_ascii=True, separators=(",", ":")) + "\n")
    return 1 if has_failure(findings) else 0


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.exit(main())
