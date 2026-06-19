from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Iterable


PROJECT_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_FILES = [
    Path(".nojekyll"),
    Path("README.md"),
    Path("index.html"),
    Path("project.html"),
    Path("methodology.html"),
    Path("styles.css"),
    Path("app.js"),
    Path("sw.js"),
    Path("manifest.webmanifest"),
    Path("scripts/dashboard-utils.js"),
    Path("scripts/public-mirror-link-validation.ps1"),
    Path("scripts/validate-public-mirror.ps1"),
    Path("data/live.json"),
    Path("data/reports.json"),
    Path("data/observations.json"),
    Path("data/sites.json"),
    Path("data/sites-normalized.json"),
    Path("data/site-review-summary.json"),
    Path("data/analytics.json"),
    Path("data/manifest.json"),
    Path("data/lake-shoreline.json"),
    Path("data/weather-context.json"),
    Path("data/reviewed-field-observations.json"),
    Path("docs/public-backlog.md"),
    Path("docs/public-snapshot-release-note-2026-05-13.md"),
    Path("docs/reviewer-demo-notes.md"),
    Path("docs/publication-review-checklist.md"),
    Path("docs/public-mirror-boundary.md"),
    Path("docs/flagship-maturity-plan.md"),
    Path("docs/scheduled-public-refresh-design.md"),
]

TEXT_GUARDS = {
    Path("README.md"): [
        "late-prototype / early-MVP",
        "not official public-health guidance",
        "static reviewed snapshot generated on May 5, 2026",
        "not live lake conditions",
        "docs/public-snapshot-release-note-2026-05-13.md",
    ],
    Path("index.html"): [
        "late prototype / early MVP",
        "Public Data Snapshot, Not Advisory Guidance",
        "What The Public Snapshot Files Are Showing",
    ],
    Path("project.html"): [
        "late prototype / early MVP",
        "not official public-health guidance",
    ],
    Path("methodology.html"): [
        "not official public-health direction",
    ],
    Path("docs/public-snapshot-release-note-2026-05-13.md"): [
        "Snapshot generated: May 5, 2026",
        "not official public-health guidance",
        "Static Snapshot Age Cue",
    ],
    Path("docs/reviewer-demo-notes.md"): [
        "static portfolio evidence, not current conditions",
        "not official public-health guidance",
    ],
    Path("docs/scheduled-public-refresh-design.md"): [
        "No unattended publication workflow is enabled",
        "The scheduled workflow must never publish",
    ],
}

EXPECTED_SOURCE_IDS = {
    "usgs-lake-level",
    "usgs-cole-creek-discharge",
    "fhabs-bloom-reports",
    "fhabs-results",
}

EXCLUDED_TRACKED_PATHS = [
    "docs/private",
    "docs/review-screenshots",
    "docs/trusted-review-request.md",
    "docs/trusted-review-feedback-log.md",
    "docs/communications-log.md",
    "data/private",
    "data/site-review.json",
    "portfolio-materials.html",
    "shortcuts",
    "server.pid",
    "server.out.log",
    "server.err.log",
]

DISALLOWED_WORKING_PATHS = [
    Path("geometry-preview.html"),
    Path("data/lake-shoreline-county-candidate.json"),
    Path("data/lake-shoreline-county-simplified-25ft.json"),
    Path("data/lake-shoreline-county-simplified-50ft.json"),
]


@dataclass
class ValidationState:
    failures: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)


def project_path(relative_path: Path) -> Path:
    return PROJECT_ROOT / relative_path


def read_text(relative_path: Path, state: ValidationState) -> str:
    path = project_path(relative_path)
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        state.fail(f"Missing required file: {relative_path.as_posix()}")
    except OSError as exc:
        state.fail(f"Unable to read {relative_path.as_posix()}: {exc}")
    return ""


def read_json(relative_path: Path, state: ValidationState) -> object | None:
    content = read_text(relative_path, state)
    if not content:
        return None
    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        state.fail(f"Invalid JSON in {relative_path.as_posix()}: {exc}")
        return None


def assert_required_files(state: ValidationState) -> None:
    for relative_path in REQUIRED_FILES:
        if not project_path(relative_path).is_file():
            state.fail(f"Missing required file: {relative_path.as_posix()}")


def assert_text_guards(state: ValidationState) -> None:
    for relative_path, needles in TEXT_GUARDS.items():
        text = read_text(relative_path, state)
        for needle in needles:
            if needle not in text:
                state.fail(
                    f"{relative_path.as_posix()} is missing required text: {needle}"
                )


def parse_date_like(value: str) -> datetime:
    normalized = value.replace("Z", "+00:00")
    return datetime.fromisoformat(normalized)


def load_tracked_files(state: ValidationState) -> set[str]:
    try:
        result = subprocess.run(
            ["git", "ls-files"],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        state.warn(f"Unable to inspect tracked files with git ls-files: {exc}")
        return set()
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def assert_tracked_boundaries(state: ValidationState, tracked_files: set[str]) -> None:
    if not tracked_files:
        return

    for excluded_path in EXCLUDED_TRACKED_PATHS:
        normalized = excluded_path.replace("\\", "/")
        for tracked_path in tracked_files:
            if tracked_path == normalized or tracked_path.startswith(f"{normalized}/"):
                state.fail(
                    "Public mirror must not track excluded review/private/local "
                    f"artifact: {normalized}"
                )
                break

    for tracked_path in tracked_files:
        if tracked_path.startswith("data/") and tracked_path.endswith(".local.json"):
            state.fail(f"Public mirror must not track local/private file: {tracked_path}")
        if tracked_path.endswith(".local.sqlite"):
            state.fail(f"Public mirror must not track local/private file: {tracked_path}")


def assert_working_boundaries(state: ValidationState) -> None:
    for relative_path in DISALLOWED_WORKING_PATHS:
        if project_path(relative_path).exists():
            state.fail(
                "Public mirror must not expose unverified county GIS review artifact: "
                f"{relative_path.as_posix()}"
            )


def assert_manifest_freshness(
    state: ValidationState, manifest: dict, live_data: dict
) -> None:
    try:
        manifest_generated_at = parse_date_like(str(manifest["generatedAt"]))
        live_generated_at = parse_date_like(str(live_data["generatedAt"]))
    except (KeyError, TypeError, ValueError) as exc:
        state.fail(f"Unable to parse manifest or live snapshot timestamps: {exc}")
        return

    gap_minutes = abs((manifest_generated_at - live_generated_at).total_seconds()) / 60
    if gap_minutes > 5:
        state.fail(
            "Manifest and live snapshot appear to come from different refresh passes. "
            f"Gap: {gap_minutes:.2f} minutes."
        )

    max_source_age_days = int(manifest.get("sourceFreshnessMaxAgeDays", 14))
    sources = manifest.get("sources")
    if not isinstance(sources, list):
        state.fail("Manifest sources must be a list.")
        return

    source_ids = {
        source.get("id")
        for source in sources
        if isinstance(source, dict) and source.get("id")
    }
    missing_ids = sorted(EXPECTED_SOURCE_IDS - source_ids)
    for source_id in missing_ids:
        state.fail(f"Manifest is missing expected source: {source_id}")

    today = date.today()
    snapshot_age_days = (today - manifest_generated_at.date()).days
    if snapshot_age_days > max_source_age_days:
        state.warn(
            "Dashboard snapshot is "
            f"{snapshot_age_days} days old, which exceeds "
            f"sourceFreshnessMaxAgeDays={max_source_age_days}. "
            "Keep static-snapshot language visible."
        )

    if manifest.get("status") == "ok":
        non_ok_sources = [
            source.get("id", "unknown")
            for source in sources
            if isinstance(source, dict) and source.get("status") != "ok"
        ]
        if non_ok_sources:
            state.fail(
                "Manifest status is ok, but one or more sources are not ok: "
                + ", ".join(non_ok_sources)
            )

    for source in sources:
        if not isinstance(source, dict):
            state.fail("Manifest source entry must be an object.")
            continue
        source_id = str(source.get("id", "unknown"))
        status = source.get("status")
        row_count = source.get("rowCount")
        latest_observation = source.get("latestObservationDate")

        if not status:
            state.fail(f"Manifest source {source_id} is missing status.")
        if not isinstance(row_count, (int, float)) or row_count <= 0:
            state.fail(f"Manifest source {source_id} must have a positive rowCount.")
        if not latest_observation:
            state.fail(f"Manifest source {source_id} is missing latestObservationDate.")
            continue

        try:
            latest_observation_date = parse_date_like(str(latest_observation)).date()
        except ValueError:
            latest_observation_date = datetime.fromisoformat(
                f"{latest_observation}T00:00:00"
            ).date()

        age_days = (manifest_generated_at.date() - latest_observation_date).days
        if age_days < 0:
            state.fail(
                f"Manifest source {source_id} has a latestObservationDate after "
                "the manifest generatedAt."
            )
        elif age_days > max_source_age_days:
            state.warn(
                f"Manifest source {source_id} latest observation is {age_days} days "
                "older than the dashboard snapshot; keep stale-source language visible."
            )


def assert_live_data_shape(state: ValidationState, live_data: dict) -> None:
    for key in ("liveCards", "mapMarkers", "dataProducts"):
        value = live_data.get(key)
        if not isinstance(value, list) or not value:
            state.fail(f"Live snapshot must include a non-empty {key} list.")


def assert_reviewed_field_observations(state: ValidationState, reviewed_data: dict) -> None:
    records = reviewed_data.get("records")
    if not isinstance(records, list):
        state.fail("Reviewed field observations must expose a records list.")
        return

    private_needles = {
        "collectorName",
        "qaNotes",
        "custodyNotes",
        "photoOrVoucherReference",
        "latitude",
        "longitude",
    }
    for record in records:
        serialized = json.dumps(record, sort_keys=True)
        for private_needle in private_needles:
            if private_needle in serialized:
                record_id = (
                    record.get("recordId", "unknown")
                    if isinstance(record, dict)
                    else "unknown"
                )
                state.fail(
                    "Reviewed public field observation "
                    f"{record_id} includes private or sensitive field: {private_needle}"
                )


def validate() -> ValidationState:
    state = ValidationState()
    assert_required_files(state)
    assert_text_guards(state)

    tracked_files = load_tracked_files(state)
    assert_tracked_boundaries(state, tracked_files)
    assert_working_boundaries(state)

    manifest = read_json(Path("data/manifest.json"), state)
    live_data = read_json(Path("data/live.json"), state)
    reviewed_field_observations = read_json(
        Path("data/reviewed-field-observations.json"), state
    )

    if isinstance(manifest, dict) and isinstance(live_data, dict):
        assert_manifest_freshness(state, manifest, live_data)
        assert_live_data_shape(state, live_data)
    else:
        state.fail("Manifest or live snapshot JSON is missing required object structure.")

    if isinstance(reviewed_field_observations, dict):
        assert_reviewed_field_observations(state, reviewed_field_observations)
    else:
        state.fail("Reviewed field observations JSON is missing required object structure.")

    return state


def emit_messages(messages: Iterable[str], label: str) -> None:
    messages = list(messages)
    if not messages:
        return
    print(f"{label}:")
    for message in messages:
        print(f"  - {message}")


def main() -> int:
    state = validate()
    emit_messages(state.warnings, "Warnings")
    emit_messages(state.failures, "Failures")

    if state.failures:
        print("Validation failed for Clear Lake Watch public mirror.")
        return 1

    print("Validation passed for Clear Lake Watch public mirror.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
