from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional, Sequence

# Evaluation must not write: skip bytecode caches for the shared evaluator.
sys.dont_write_bytecode = True

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

try:
    import public_mirror_common
except Exception as exc:  # Any import problem must fail the gate, not crash it.
    public_mirror_common = None
    EVALUATOR_IMPORT_ERROR: Optional[str] = f"{type(exc).__name__}: {exc}"
else:
    EVALUATOR_IMPORT_ERROR = None

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


SHARED_SEVERITIES = {"warning", "failure"}


def apply_shared_findings(state: ValidationState, as_of: Optional[object]) -> None:
    """Run the shared snapshot evaluator and render its findings.

    Each finding is rendered as ``[code] subject: message`` in the existing
    warning or failure section. An unavailable or malformed evaluator fails.
    """

    if public_mirror_common is None:
        state.fail(
            "Shared snapshot evaluator is unavailable (scripts/public_mirror_common.py): "
            f"{EVALUATOR_IMPORT_ERROR}"
        )
        return
    check_snapshot = getattr(public_mirror_common, "check_snapshot", None)
    if not callable(check_snapshot) or as_of is None:
        state.fail(
            "Shared snapshot evaluator is incomplete: scripts/public_mirror_common.py must "
            "provide parse_as_of(), utc_now(), and check_snapshot()."
        )
        return
    try:
        findings = list(check_snapshot(PROJECT_ROOT, as_of))
    except Exception as exc:  # Fail closed on any evaluator error.
        state.fail(f"Shared snapshot evaluator raised {type(exc).__name__}: {exc}")
        return

    rendered = []
    for finding in findings:
        values = [getattr(finding, name, None) for name in ("severity", "code", "subject", "message")]
        if not all(isinstance(value, str) and value for value in values) or values[0] not in SHARED_SEVERITIES:
            state.fail(f"Shared snapshot evaluator returned a malformed finding: {finding!r}")
            return
        rendered.append(values)

    for severity, code, subject, message in rendered:
        line = f"[{code}] {subject}: {message}"
        if severity == "failure":
            state.fail(line)
        else:
            state.warn(line)


def load_json_quietly(relative_path: Path) -> object | None:
    # The shared evaluator reports missing or invalid snapshot JSON; this
    # reader only supplies native shape checks.
    try:
        return json.loads(project_path(relative_path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError):
        return None


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


def validate(as_of: Optional[object]) -> ValidationState:
    state = ValidationState()
    assert_required_files(state)
    assert_text_guards(state)

    tracked_files = load_tracked_files(state)
    assert_tracked_boundaries(state, tracked_files)
    assert_working_boundaries(state)

    apply_shared_findings(state, as_of)

    live_data = load_json_quietly(Path("data/live.json"))
    reviewed_field_observations = read_json(
        Path("data/reviewed-field-observations.json"), state
    )

    if isinstance(live_data, dict):
        assert_live_data_shape(state, live_data)

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


def parse_arguments(argv: Optional[Sequence[str]]) -> tuple[argparse.ArgumentParser, argparse.Namespace]:
    parser = argparse.ArgumentParser(
        description="Validate the Clear Lake Watch public mirror before review."
    )
    parser.add_argument(
        "--as-of",
        metavar="UTC_INSTANT",
        help=(
            "Evaluation clock for snapshot and source age, for example "
            "2026-11-17T12:00:00Z. Defaults to one sample of the system UTC clock."
        ),
    )
    return parser, parser.parse_args(argv)


def resolve_clock(parser: argparse.ArgumentParser, as_of_text: Optional[str]) -> Optional[object]:
    """Return one evaluation clock, or None when the evaluator cannot supply one.

    An explicit clock must be a UTC instant ending in Z or +00:00; anything
    else is an argument error (exit 2). Without one, the system UTC clock is
    sampled once.
    """

    if public_mirror_common is None:
        return None
    if as_of_text is None:
        utc_now = getattr(public_mirror_common, "utc_now", None)
        return utc_now() if callable(utc_now) else None
    parse_as_of = getattr(public_mirror_common, "parse_as_of", None)
    if not callable(parse_as_of):
        return None
    try:
        return parse_as_of(as_of_text)
    except ValueError as exc:
        parser.error(f"argument --as-of: {exc}")
    return None


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser, args = parse_arguments(argv)
    state = validate(resolve_clock(parser, args.as_of))
    emit_messages(state.warnings, "Warnings")
    emit_messages(state.failures, "Failures")

    if state.failures:
        print("Validation failed for Clear Lake Watch public mirror.")
        return 1

    print("Validation passed for Clear Lake Watch public mirror.")
    return 0


if __name__ == "__main__":
    sys.exit(main())