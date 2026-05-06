"""Local SQLite store for detailed site-registry review records."""

from __future__ import annotations

import argparse
import json
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB_PATH = PROJECT_ROOT / "data" / "private" / "site-review.local.sqlite"
DEFAULT_INPUT_PATH = PROJECT_ROOT / "data" / "site-review.json"
DEFAULT_DECISIONS_PATH = PROJECT_ROOT / "data" / "site-review-decisions.local.json"
DEFAULT_OUTPUT_PATH = PROJECT_ROOT / "data" / "site-review-summary.json"

SUMMARY_FIELDS = (
    "registrySites",
    "reviewedRegistrySites",
    "needsReviewRegistrySites",
    "currentMapMarkers",
    "reviewedCurrentMapMarkers",
    "needsReviewCurrentMapMarkers",
    "matchedButUnreviewedCurrentMapMarkers",
    "highPriorityReviewItems",
    "mediumPriorityReviewItems",
    "lowPriorityReviewItems",
)

REVIEW_QUEUE_FIELDS = (
    "siteId",
    "siteName",
    "landmark",
    "arm",
    "assignmentStatus",
    "reviewPriority",
    "reviewReason",
    "matchMethod",
    "matchDistanceKm",
    "reportDate",
    "latitude",
    "longitude",
    "sourceMapUrl",
    "registryLatitude",
    "registryLongitude",
    "registryMapUrl",
    "recommendedReviewAction",
)

DECISION_STATUSES = (
    "needs-review",
    "approved-private",
    "approved-public",
    "rejected",
    "superseded",
)

DECISION_FIELDS = (
    "decisionId",
    "siteId",
    "landmark",
    "action",
    "proposedAssignmentStatus",
    "reviewer",
    "reviewedAt",
    "evidenceNote",
    "publicNote",
    "permissionToPublish",
)

DECISION_STATUS_BY_ACTION = {
    "keep-needs-review": "needs-review",
    "add-alias": "approved-private",
    "create-site": "approved-private",
    "promote-reviewed-local": "approved-public",
}

DEFAULT_DECISION_SUBJECT_TYPE = "site-registry-review"
DEFAULT_DECISION_SUBJECT_ID_PATTERN = "siteId::landmark"


def resolve_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return PROJECT_ROOT / path


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat()


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS site_review_runs (
          run_id INTEGER PRIMARY KEY AUTOINCREMENT,
          generated_at TEXT NOT NULL,
          source_sites TEXT,
          source_live TEXT,
          imported_at TEXT NOT NULL,
          registry_sites INTEGER NOT NULL,
          reviewed_registry_sites INTEGER NOT NULL,
          needs_review_registry_sites INTEGER NOT NULL,
          current_map_markers INTEGER NOT NULL,
          reviewed_current_map_markers INTEGER NOT NULL,
          needs_review_current_map_markers INTEGER NOT NULL,
          matched_but_unreviewed_current_map_markers INTEGER NOT NULL,
          high_priority_review_items INTEGER NOT NULL,
          medium_priority_review_items INTEGER NOT NULL,
          low_priority_review_items INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS site_review_queue (
          run_id INTEGER NOT NULL,
          row_number INTEGER NOT NULL,
          site_id TEXT,
          site_name TEXT,
          landmark TEXT,
          arm TEXT,
          assignment_status TEXT,
          review_priority TEXT,
          review_reason TEXT,
          match_method TEXT,
          match_distance_km REAL,
          report_date TEXT,
          latitude REAL,
          longitude REAL,
          source_map_url TEXT,
          registry_latitude REAL,
          registry_longitude REAL,
          registry_map_url TEXT,
          recommended_review_action TEXT,
          raw_json TEXT NOT NULL,
          PRIMARY KEY (run_id, row_number),
          FOREIGN KEY (run_id) REFERENCES site_review_runs(run_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS site_review_markers_by_site (
          run_id INTEGER NOT NULL,
          row_number INTEGER NOT NULL,
          site_id TEXT,
          site_name TEXT,
          arm TEXT,
          assignment_status TEXT,
          report_count INTEGER,
          latest_report_date TEXT,
          match_methods_json TEXT NOT NULL,
          landmarks_json TEXT NOT NULL,
          raw_json TEXT NOT NULL,
          PRIMARY KEY (run_id, row_number),
          FOREIGN KEY (run_id) REFERENCES site_review_runs(run_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS review_decisions (
          decision_id TEXT PRIMARY KEY,
          subject_type TEXT NOT NULL,
          subject_id TEXT NOT NULL,
          source_run_id INTEGER,
          decision_status TEXT NOT NULL CHECK (
            decision_status IN (
              'needs-review',
              'approved-private',
              'approved-public',
              'rejected',
              'superseded'
            )
          ),
          reviewer TEXT,
          reviewed_at TEXT,
          evidence_note TEXT,
          public_note TEXT,
          permission_to_publish INTEGER NOT NULL DEFAULT 0 CHECK (
            permission_to_publish IN (0, 1)
          ),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          raw_json TEXT,
          FOREIGN KEY (source_run_id) REFERENCES site_review_runs(run_id)
        );

        CREATE INDEX IF NOT EXISTS idx_review_decisions_subject
        ON review_decisions (subject_type, subject_id);
        """
    )
    connection.commit()


def as_int(value: Any, field: str) -> int:
    if value is None:
        raise ValueError(f"Missing numeric summary field: {field}")
    return int(value)


def load_site_review(input_path: Path) -> dict[str, Any]:
    with input_path.open("r", encoding="utf-8-sig") as file:
        data = json.load(file)

    if not data.get("generatedAt"):
        raise ValueError("site-review input must include generatedAt.")
    if not isinstance(data.get("summary"), dict):
        raise ValueError("site-review input must include summary object.")
    if not isinstance(data.get("reviewQueue"), list):
        raise ValueError("site-review input must include reviewQueue list.")
    if not isinstance(data.get("markersBySite"), list):
        raise ValueError("site-review input must include markersBySite list.")

    for field in SUMMARY_FIELDS:
        as_int(data["summary"].get(field), field)

    for index, item in enumerate(data["reviewQueue"], start=1):
        missing = [field for field in REVIEW_QUEUE_FIELDS if field not in item]
        if missing:
            raise ValueError(f"reviewQueue row {index} is missing: {', '.join(missing)}")

    return data


def load_decisions(input_path: Path) -> dict[str, Any]:
    with input_path.open("r", encoding="utf-8-sig") as file:
        data = json.load(file)

    if data.get("schemaVersion") != 1:
        raise ValueError("Decision file must use schemaVersion 1.")
    if not isinstance(data.get("decisions"), list):
        raise ValueError("Decision file must include decisions list.")

    for index, decision in enumerate(data["decisions"], start=1):
        missing = [field for field in DECISION_FIELDS if field not in decision]
        if missing:
            raise ValueError(f"decision row {index} is missing: {', '.join(missing)}")
        if not decision.get("decisionId"):
            raise ValueError(f"decision row {index} must include decisionId.")
        if decision.get("action") not in DECISION_STATUS_BY_ACTION:
            raise ValueError(
                f"decision '{decision.get('decisionId')}' uses unsupported action "
                f"'{decision.get('action')}'."
            )
        if decision.get("action") == "promote-reviewed-local" and not decision.get(
            "permissionToPublish"
        ):
            raise ValueError(
                f"decision '{decision.get('decisionId')}' cannot promote to "
                "reviewed-local without permissionToPublish true."
            )
        if decision.get("action") == "add-alias" and not decision.get("proposedAlias"):
            raise ValueError(
                f"decision '{decision.get('decisionId')}' must include proposedAlias "
                "for add-alias."
            )

    return data


def build_decision_subject_id(decision: dict[str, Any]) -> str:
    return f"{decision['siteId']}::{decision['landmark']}"


def insert_decisions(
    connection: sqlite3.Connection,
    data: dict[str, Any],
    subject_type: str,
) -> int:
    source_run_id = latest_run_id(connection)
    timestamp = now_iso()

    for decision in data["decisions"]:
        decision_status = DECISION_STATUS_BY_ACTION[decision["action"]]
        connection.execute(
            """
            INSERT INTO review_decisions (
              decision_id, subject_type, subject_id, source_run_id,
              decision_status, reviewer, reviewed_at, evidence_note, public_note,
              permission_to_publish, created_at, updated_at, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(decision_id) DO UPDATE SET
              subject_type = excluded.subject_type,
              subject_id = excluded.subject_id,
              source_run_id = excluded.source_run_id,
              decision_status = excluded.decision_status,
              reviewer = excluded.reviewer,
              reviewed_at = excluded.reviewed_at,
              evidence_note = excluded.evidence_note,
              public_note = excluded.public_note,
              permission_to_publish = excluded.permission_to_publish,
              updated_at = excluded.updated_at,
              raw_json = excluded.raw_json
            """,
            (
                decision["decisionId"],
                subject_type,
                build_decision_subject_id(decision),
                source_run_id,
                decision_status,
                decision.get("reviewer"),
                decision.get("reviewedAt"),
                decision.get("evidenceNote"),
                decision.get("publicNote"),
                1 if decision.get("permissionToPublish") else 0,
                timestamp,
                timestamp,
                json.dumps(decision, ensure_ascii=True, sort_keys=True),
            ),
        )

    connection.commit()
    return len(data["decisions"])


def insert_run(connection: sqlite3.Connection, data: dict[str, Any]) -> int:
    summary = data["summary"]
    source_files = data.get("sourceFiles", {})
    imported_at = now_iso()
    cursor = connection.execute(
        """
        INSERT INTO site_review_runs (
          generated_at, source_sites, source_live, imported_at,
          registry_sites, reviewed_registry_sites, needs_review_registry_sites,
          current_map_markers, reviewed_current_map_markers,
          needs_review_current_map_markers,
          matched_but_unreviewed_current_map_markers,
          high_priority_review_items, medium_priority_review_items,
          low_priority_review_items
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            data["generatedAt"],
            source_files.get("sites"),
            source_files.get("live"),
            imported_at,
            as_int(summary.get("registrySites"), "registrySites"),
            as_int(summary.get("reviewedRegistrySites"), "reviewedRegistrySites"),
            as_int(summary.get("needsReviewRegistrySites"), "needsReviewRegistrySites"),
            as_int(summary.get("currentMapMarkers"), "currentMapMarkers"),
            as_int(summary.get("reviewedCurrentMapMarkers"), "reviewedCurrentMapMarkers"),
            as_int(summary.get("needsReviewCurrentMapMarkers"), "needsReviewCurrentMapMarkers"),
            as_int(
                summary.get("matchedButUnreviewedCurrentMapMarkers"),
                "matchedButUnreviewedCurrentMapMarkers",
            ),
            as_int(summary.get("highPriorityReviewItems"), "highPriorityReviewItems"),
            as_int(summary.get("mediumPriorityReviewItems"), "mediumPriorityReviewItems"),
            as_int(summary.get("lowPriorityReviewItems"), "lowPriorityReviewItems"),
        ),
    )
    run_id = int(cursor.lastrowid)

    for index, item in enumerate(data["reviewQueue"], start=1):
        connection.execute(
            """
            INSERT INTO site_review_queue (
              run_id, row_number, site_id, site_name, landmark, arm,
              assignment_status, review_priority, review_reason, match_method,
              match_distance_km, report_date, latitude, longitude, source_map_url,
              registry_latitude, registry_longitude, registry_map_url,
              recommended_review_action, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                index,
                item.get("siteId"),
                item.get("siteName"),
                item.get("landmark"),
                item.get("arm"),
                item.get("assignmentStatus"),
                item.get("reviewPriority"),
                item.get("reviewReason"),
                item.get("matchMethod"),
                item.get("matchDistanceKm"),
                item.get("reportDate"),
                item.get("latitude"),
                item.get("longitude"),
                item.get("sourceMapUrl"),
                item.get("registryLatitude"),
                item.get("registryLongitude"),
                item.get("registryMapUrl"),
                item.get("recommendedReviewAction"),
                json.dumps(item, ensure_ascii=True, sort_keys=True),
            ),
        )

    for index, item in enumerate(data["markersBySite"], start=1):
        connection.execute(
            """
            INSERT INTO site_review_markers_by_site (
              run_id, row_number, site_id, site_name, arm, assignment_status,
              report_count, latest_report_date, match_methods_json,
              landmarks_json, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                index,
                item.get("siteId"),
                item.get("siteName"),
                item.get("arm"),
                item.get("assignmentStatus"),
                item.get("reportCount"),
                item.get("latestReportDate"),
                json.dumps(item.get("matchMethods", []), ensure_ascii=True),
                json.dumps(item.get("landmarks", []), ensure_ascii=True),
                json.dumps(item, ensure_ascii=True, sort_keys=True),
            ),
        )

    connection.commit()
    return run_id


def latest_run_id(connection: sqlite3.Connection) -> int:
    row = connection.execute(
        "SELECT run_id FROM site_review_runs ORDER BY run_id DESC LIMIT 1"
    ).fetchone()
    if row is None:
        raise ValueError("No site-review runs are stored in SQLite yet.")
    return int(row["run_id"])


def row_to_summary(row: sqlite3.Row) -> dict[str, int]:
    return {
        "registrySites": row["registry_sites"],
        "reviewedRegistrySites": row["reviewed_registry_sites"],
        "needsReviewRegistrySites": row["needs_review_registry_sites"],
        "currentMapMarkers": row["current_map_markers"],
        "reviewedCurrentMapMarkers": row["reviewed_current_map_markers"],
        "needsReviewCurrentMapMarkers": row["needs_review_current_map_markers"],
        "matchedButUnreviewedCurrentMapMarkers": row[
            "matched_but_unreviewed_current_map_markers"
        ],
        "highPriorityReviewItems": row["high_priority_review_items"],
        "mediumPriorityReviewItems": row["medium_priority_review_items"],
        "lowPriorityReviewItems": row["low_priority_review_items"],
    }


def validate_database(connection: sqlite3.Connection) -> tuple[int, int, int, int]:
    run_id = latest_run_id(connection)
    run = connection.execute(
        "SELECT * FROM site_review_runs WHERE run_id = ?",
        (run_id,),
    ).fetchone()
    queue_count = connection.execute(
        "SELECT COUNT(*) AS count FROM site_review_queue WHERE run_id = ?",
        (run_id,),
    ).fetchone()["count"]
    marker_site_count = connection.execute(
        "SELECT COUNT(*) AS count FROM site_review_markers_by_site WHERE run_id = ?",
        (run_id,),
    ).fetchone()["count"]
    decision_count = connection.execute(
        "SELECT COUNT(*) AS count FROM review_decisions"
    ).fetchone()["count"]
    priority_counts = dict(
        connection.execute(
            """
            SELECT review_priority, COUNT(*) AS count
            FROM site_review_queue
            WHERE run_id = ?
            GROUP BY review_priority
            """,
            (run_id,),
        ).fetchall()
    )

    if int(queue_count) != int(run["current_map_markers"]):
        raise ValueError("Stored site-review queue count does not match current_map_markers.")
    if int(priority_counts.get("high", 0)) != int(run["high_priority_review_items"]):
        raise ValueError("Stored high-priority count does not match run summary.")
    if int(priority_counts.get("medium", 0)) != int(run["medium_priority_review_items"]):
        raise ValueError("Stored medium-priority count does not match run summary.")
    if int(priority_counts.get("low", 0)) != int(run["low_priority_review_items"]):
        raise ValueError("Stored low-priority count does not match run summary.")

    invalid_decision_count = connection.execute(
        """
        SELECT COUNT(*) AS count
        FROM review_decisions
        WHERE decision_status NOT IN ({})
           OR permission_to_publish NOT IN (0, 1)
        """.format(", ".join("?" for _ in DECISION_STATUSES)),
        DECISION_STATUSES,
    ).fetchone()["count"]
    if int(invalid_decision_count) != 0:
        raise ValueError("Stored review decisions include invalid status or permission values.")

    return run_id, int(queue_count), int(marker_site_count), int(decision_count)


def build_public_summary(connection: sqlite3.Connection) -> dict[str, Any]:
    run_id = latest_run_id(connection)
    run = connection.execute(
        "SELECT * FROM site_review_runs WHERE run_id = ?",
        (run_id,),
    ).fetchone()
    summary = row_to_summary(run)
    return {
        "schemaVersion": "site-review-summary-v0",
        "generatedAt": run["generated_at"],
        "source": "sanitized aggregate from local SQLite site-review store",
        "summary": summary,
        "priorityCounts": {
            "high": summary["highPriorityReviewItems"],
            "medium": summary["mediumPriorityReviewItems"],
            "low": summary["lowPriorityReviewItems"],
        },
        "publicNotes": [
            "This public summary reports aggregate site-registry review status only.",
            "Detailed review queues, reviewer notes, draft corrections, and unpublished decisions belong in private review artifacts.",
            "Counts do not certify site locations, arm assignments, or public-health status.",
        ],
        "links": {
            "publicMethodology": ".\\methodology.html",
            "reviewWorkflow": ".\\docs\\site-registry-decision-workflow.md",
        },
    }


def command_init(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
    print(f"Initialized site-review SQLite store: {db_path.relative_to(PROJECT_ROOT)}")


def command_import_json(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    input_path = resolve_path(args.input)
    data = load_site_review(input_path)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        run_id = insert_run(connection, data)
    print(f"Imported site-review run: {run_id}")
    print(f"Detailed records stored in: {db_path.relative_to(PROJECT_ROOT)}")


def command_validate(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        run_id, queue_count, marker_site_count, decision_count = validate_database(
            connection
        )
    print("Site-review SQLite validation passed.")
    print(f"Latest run: {run_id}")
    print(f"Detailed queue records: {queue_count}")
    print(f"Marker-by-site records: {marker_site_count}")
    print(f"Review decision records: {decision_count}")


def command_import_decisions(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    input_path = resolve_path(args.input)
    data = load_decisions(input_path)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        count = insert_decisions(connection, data, args.subject_type)
    print(f"Imported review decisions: {count}")
    print(f"Subject type: {args.subject_type}")
    print(f"Detailed records stored in: {db_path.relative_to(PROJECT_ROOT)}")


def command_export_summary(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    output_path = resolve_path(args.output)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        validate_database(connection)
        payload = build_public_summary(connection)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)
        file.write("\n")
    print(f"Wrote public site-review summary: {output_path.relative_to(PROJECT_ROOT)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage local SQLite site-registry review records."
    )
    parser.add_argument(
        "--db",
        default=str(DEFAULT_DB_PATH.relative_to(PROJECT_ROOT)),
        help="Path to the ignored local SQLite site-review database.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="Create the SQLite schema.")
    init_parser.set_defaults(func=command_init)

    import_parser = subparsers.add_parser("import-json", help="Import detailed site-review JSON.")
    import_parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT_PATH.relative_to(PROJECT_ROOT)),
        help="Path to detailed generated site-review JSON.",
    )
    import_parser.set_defaults(func=command_import_json)

    validate_parser = subparsers.add_parser("validate", help="Validate the SQLite records.")
    validate_parser.set_defaults(func=command_validate)

    decisions_parser = subparsers.add_parser(
        "import-decisions",
        help="Import existing site-review decision JSON into review_decisions.",
    )
    decisions_parser.add_argument(
        "--input",
        default=str(DEFAULT_DECISIONS_PATH.relative_to(PROJECT_ROOT)),
        help="Path to existing private site-review decision JSON.",
    )
    decisions_parser.add_argument(
        "--subject-type",
        default=DEFAULT_DECISION_SUBJECT_TYPE,
        help="Reusable review decision subject type.",
    )
    decisions_parser.set_defaults(func=command_import_decisions)

    export_parser = subparsers.add_parser(
        "export-summary",
        help="Export the public aggregate site-review summary.",
    )
    export_parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT_PATH.relative_to(PROJECT_ROOT)),
        help="Path to public-safe site-review summary JSON.",
    )
    export_parser.set_defaults(func=command_export_summary)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
