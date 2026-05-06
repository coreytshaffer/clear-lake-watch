"""Local SQLite review store for Clear Lake Watch field/microscopy records."""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from contextlib import closing
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PACKAGE_SRC = (
    PROJECT_ROOT.parent
    / "environmental-monitoring-schemas"
    / "src"
)
if not SCHEMA_PACKAGE_SRC.exists():
    raise RuntimeError(
        "Missing sibling schema package at "
        f"{SCHEMA_PACKAGE_SRC}. Clone or place environmental-monitoring-schemas "
        "next to the Clear-Lake-Watch repository."
    )
if str(SCHEMA_PACKAGE_SRC) not in sys.path:
    sys.path.insert(0, str(SCHEMA_PACKAGE_SRC))

from environmental_monitoring_schemas.field_microscopy import (  # noqa: E402
    FORBIDDEN_PUBLIC_FIELDS,
    build_public_export,
    load_intake_records,
    validate_database_review_state,
)

DEFAULT_DB_PATH = PROJECT_ROOT / "data" / "private" / "field-microscopy.local.sqlite"
DEFAULT_INPUT_PATH = PROJECT_ROOT / "data" / "private" / "field-microscopy-intake.local.json"
DEFAULT_OUTPUT_PATH = PROJECT_ROOT / "data" / "reviewed-field-observations.json"
EXAMPLE_INPUT_PATH = PROJECT_ROOT / "data" / "field-microscopy-intake.example.json"


def resolve_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return PROJECT_ROOT / path


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS field_microscopy_records (
          record_id TEXT PRIMARY KEY,
          record_type TEXT NOT NULL CHECK (record_type = 'field-microscopy'),
          created_at TEXT,
          updated_at TEXT,
          created_by TEXT,
          sample_date_time TEXT,
          collector_name TEXT,
          collector_organization TEXT,
          collection_program TEXT,
          custody_id TEXT,
          custody_notes TEXT,
          site_id TEXT,
          site_name TEXT,
          latitude REAL,
          longitude REAL,
          gps_precision_meters REAL,
          coordinate_source TEXT,
          lake_arm TEXT,
          location_privacy_class TEXT,
          sample_type TEXT,
          collection_method TEXT,
          preservation_method TEXT,
          field_notes TEXT,
          microscope_method TEXT,
          magnification TEXT,
          preparation_method TEXT,
          taxon_name TEXT,
          taxon_rank TEXT,
          identification_confidence TEXT,
          abundance_estimate TEXT,
          photo_or_voucher_reference TEXT,
          qa_status TEXT NOT NULL,
          qa_reviewer TEXT,
          qa_reviewed_at TEXT,
          qa_notes TEXT,
          permission_to_publish INTEGER NOT NULL DEFAULT 0,
          public_location_precision TEXT,
          public_summary TEXT,
          raw_json TEXT NOT NULL,
          imported_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_field_microscopy_review
          ON field_microscopy_records (qa_status, permission_to_publish);
        """
    )
    connection.commit()


def upsert_records(connection: sqlite3.Connection, records: list[dict[str, Any]]) -> None:
    from environmental_monitoring_schemas.field_microscopy import now_iso

    imported_at = now_iso()
    for record in records:
        connection.execute(
            """
            INSERT INTO field_microscopy_records (
              record_id, record_type, created_at, updated_at, created_by,
              sample_date_time, collector_name, collector_organization,
              collection_program, custody_id, custody_notes, site_id, site_name,
              latitude, longitude, gps_precision_meters, coordinate_source,
              lake_arm, location_privacy_class, sample_type, collection_method,
              preservation_method, field_notes, microscope_method, magnification,
              preparation_method, taxon_name, taxon_rank, identification_confidence,
              abundance_estimate, photo_or_voucher_reference, qa_status, qa_reviewer,
              qa_reviewed_at, qa_notes, permission_to_publish, public_location_precision,
              public_summary, raw_json, imported_at
            ) VALUES (
              :record_id, :record_type, :created_at, :updated_at, :created_by,
              :sample_date_time, :collector_name, :collector_organization,
              :collection_program, :custody_id, :custody_notes, :site_id, :site_name,
              :latitude, :longitude, :gps_precision_meters, :coordinate_source,
              :lake_arm, :location_privacy_class, :sample_type, :collection_method,
              :preservation_method, :field_notes, :microscope_method, :magnification,
              :preparation_method, :taxon_name, :taxon_rank, :identification_confidence,
              :abundance_estimate, :photo_or_voucher_reference, :qa_status, :qa_reviewer,
              :qa_reviewed_at, :qa_notes, :permission_to_publish, :public_location_precision,
              :public_summary, :raw_json, :imported_at
            )
            ON CONFLICT(record_id) DO UPDATE SET
              record_type = excluded.record_type,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at,
              created_by = excluded.created_by,
              sample_date_time = excluded.sample_date_time,
              collector_name = excluded.collector_name,
              collector_organization = excluded.collector_organization,
              collection_program = excluded.collection_program,
              custody_id = excluded.custody_id,
              custody_notes = excluded.custody_notes,
              site_id = excluded.site_id,
              site_name = excluded.site_name,
              latitude = excluded.latitude,
              longitude = excluded.longitude,
              gps_precision_meters = excluded.gps_precision_meters,
              coordinate_source = excluded.coordinate_source,
              lake_arm = excluded.lake_arm,
              location_privacy_class = excluded.location_privacy_class,
              sample_type = excluded.sample_type,
              collection_method = excluded.collection_method,
              preservation_method = excluded.preservation_method,
              field_notes = excluded.field_notes,
              microscope_method = excluded.microscope_method,
              magnification = excluded.magnification,
              preparation_method = excluded.preparation_method,
              taxon_name = excluded.taxon_name,
              taxon_rank = excluded.taxon_rank,
              identification_confidence = excluded.identification_confidence,
              abundance_estimate = excluded.abundance_estimate,
              photo_or_voucher_reference = excluded.photo_or_voucher_reference,
              qa_status = excluded.qa_status,
              qa_reviewer = excluded.qa_reviewer,
              qa_reviewed_at = excluded.qa_reviewed_at,
              qa_notes = excluded.qa_notes,
              permission_to_publish = excluded.permission_to_publish,
              public_location_precision = excluded.public_location_precision,
              public_summary = excluded.public_summary,
              raw_json = excluded.raw_json,
              imported_at = excluded.imported_at
            """,
            {
                "record_id": record["recordId"],
                "record_type": record["recordType"],
                "created_at": record["createdAt"],
                "updated_at": record["updatedAt"],
                "created_by": record["createdBy"],
                "sample_date_time": record["sampleDateTime"],
                "collector_name": record["collectorName"],
                "collector_organization": record["collectorOrganization"],
                "collection_program": record["collectionProgram"],
                "custody_id": record["custodyId"],
                "custody_notes": record["custodyNotes"],
                "site_id": record["siteId"],
                "site_name": record["siteName"],
                "latitude": record["latitude"],
                "longitude": record["longitude"],
                "gps_precision_meters": record["gpsPrecisionMeters"],
                "coordinate_source": record["coordinateSource"],
                "lake_arm": record["lakeArm"],
                "location_privacy_class": record["locationPrivacyClass"],
                "sample_type": record["sampleType"],
                "collection_method": record["collectionMethod"],
                "preservation_method": record["preservationMethod"],
                "field_notes": record["fieldNotes"],
                "microscope_method": record["microscopeMethod"],
                "magnification": record["magnification"],
                "preparation_method": record["preparationMethod"],
                "taxon_name": record["taxonName"],
                "taxon_rank": record["taxonRank"],
                "identification_confidence": record["identificationConfidence"],
                "abundance_estimate": record["abundanceEstimate"],
                "photo_or_voucher_reference": record["photoOrVoucherReference"],
                "qa_status": record["qaStatus"],
                "qa_reviewer": record["qaReviewer"],
                "qa_reviewed_at": record["qaReviewedAt"],
                "qa_notes": record["qaNotes"],
                "permission_to_publish": 1 if record["permissionToPublish"] else 0,
                "public_location_precision": record["publicLocationPrecision"],
                "public_summary": record["publicSummary"],
                "raw_json": json.dumps(record, ensure_ascii=True, sort_keys=True),
                "imported_at": imported_at,
            },
        )
    connection.commit()


def fetch_public_records(connection: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = connection.execute(
        """
        SELECT
          record_id, site_id, site_name, lake_arm, sample_date_time, sample_type,
          taxon_name, identification_confidence, abundance_estimate, qa_status,
          public_location_precision, public_summary
        FROM field_microscopy_records
        WHERE qa_status = 'approved-public'
          AND permission_to_publish = 1
        ORDER BY sample_date_time, record_id
        """
    ).fetchall()

    return [
        {
            "recordId": row["record_id"],
            "sourceFamily": "field-microscopy",
            "publicSiteId": row["site_id"],
            "publicSiteName": row["site_name"],
            "publicLakeArm": row["lake_arm"],
            "sampleDateTime": row["sample_date_time"],
            "observationType": row["sample_type"],
            "taxonName": row["taxon_name"],
            "identificationConfidence": row["identification_confidence"],
            "abundanceEstimate": row["abundance_estimate"],
            "publicQaStatus": row["qa_status"],
            "publicLocationPrecision": row["public_location_precision"],
            "publicSummary": row["public_summary"],
        }
        for row in rows
    ]


def export_public_records(connection: sqlite3.Connection, output_path: Path) -> int:
    records = fetch_public_records(connection)
    payload = build_public_export(records)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)
        file.write("\n")
    return len(records)


def validate_database(connection: sqlite3.Connection) -> tuple[int, int]:
    rows = connection.execute(
        """
        SELECT
          record_id, qa_status, permission_to_publish,
          public_location_precision, public_summary
        FROM field_microscopy_records
        ORDER BY record_id
        """
    ).fetchall()

    normalized_rows = [dict(row) for row in rows]
    return validate_database_review_state(normalized_rows)


def assert_no_private_fields(output_path: Path) -> int:
    from environmental_monitoring_schemas.field_microscopy import assert_no_private_fields

    with output_path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    return assert_no_private_fields(data)


def command_init(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
    print(f"Initialized SQLite review store: {db_path.relative_to(PROJECT_ROOT)}")


def command_import_json(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    input_path = resolve_path(args.input)
    records = load_intake_records(input_path)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        upsert_records(connection, records)
    print(f"Imported records: {len(records)}")
    print(f"SQLite review store: {db_path.relative_to(PROJECT_ROOT)}")


def command_validate(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        record_count, publishable_count = validate_database(connection)
    print("SQLite field/microscopy review store validation passed.")
    print(f"Records checked: {record_count}")
    print(f"Publishable records: {publishable_count}")


def command_export_public(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    output_path = resolve_path(args.output)
    with closing(connect(db_path)) as connection:
        initialize_database(connection)
        record_count, _ = validate_database(connection)
        exported_count = export_public_records(connection, output_path)

    print(f"Records checked: {record_count}")
    print(f"Exported public records: {exported_count}")
    print(f"Public export: {output_path.relative_to(PROJECT_ROOT)}")


def command_smoke_cycle(args: argparse.Namespace) -> None:
    db_path = resolve_path(args.db)
    if db_path == DEFAULT_DB_PATH:
        db_path = PROJECT_ROOT / "data" / "private" / "field-microscopy-sqlite-smoke.local.sqlite"
    output_path = resolve_path(args.output)
    working_input_path = db_path.with_suffix(".smoke-input.json")

    try:
        with EXAMPLE_INPUT_PATH.open("r", encoding="utf-8") as file:
            sample = json.load(file)

        sample["status"] = "private-local"
        record = sample["records"][0]
        record["recordId"] = "field-micro-sqlite-smoke-001"
        record["sampleDateTime"] = "2026-05-05T09:00:00-07:00"
        record["siteId"] = "example-public-site"
        record["siteName"] = "Example public-safe site"
        record["lakeArm"] = "Lower Arm"
        record["qaStatus"] = "approved-public"
        record["qaReviewedAt"] = "2026-05-05T10:00:00-07:00"
        record["permissionToPublish"] = True
        record["publicLocationPrecision"] = "site generalized"
        record["publicSummary"] = "Synthetic SQLite review-cycle record."

        working_input_path.parent.mkdir(parents=True, exist_ok=True)
        with working_input_path.open("w", encoding="utf-8") as file:
            json.dump(sample, file, indent=2)
            file.write("\n")

        records = load_intake_records(working_input_path)
        with closing(connect(db_path)) as connection:
            initialize_database(connection)
            upsert_records(connection, records)
            record_count, publishable_count = validate_database(connection)
            export_public_records(connection, output_path)

        exported_count = assert_no_private_fields(output_path)
        if exported_count != 1:
            raise ValueError(f"Expected one exported smoke record, found {exported_count}.")

        print("SQLite field/microscopy smoke cycle passed.")
        print(f"Records checked: {record_count}")
        print(f"Publishable records: {publishable_count}")
        print(f"Private fields checked for exclusion: {len(FORBIDDEN_PUBLIC_FIELDS)}")
    finally:
        for path in (working_input_path, output_path, db_path):
            if path.exists():
                path.unlink()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage the local SQLite field/microscopy review store."
    )
    parser.add_argument(
        "--db",
        default=str(DEFAULT_DB_PATH.relative_to(PROJECT_ROOT)),
        help="Path to the local SQLite review database.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="Create the SQLite schema.")
    init_parser.set_defaults(func=command_init)

    import_parser = subparsers.add_parser("import-json", help="Import private JSON intake records.")
    import_parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT_PATH.relative_to(PROJECT_ROOT)),
        help="Path to private field/microscopy intake JSON.",
    )
    import_parser.set_defaults(func=command_import_json)

    validate_parser = subparsers.add_parser("validate", help="Validate SQLite review records.")
    validate_parser.set_defaults(func=command_validate)

    export_parser = subparsers.add_parser("export-public", help="Export reviewed public records.")
    export_parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT_PATH.relative_to(PROJECT_ROOT)),
        help="Path to public-safe reviewed observations JSON.",
    )
    export_parser.set_defaults(func=command_export_public)

    smoke_parser = subparsers.add_parser("smoke-cycle", help="Run a synthetic SQLite review cycle.")
    smoke_parser.add_argument(
        "--output",
        default="data/private/reviewed-field-observations-sqlite-smoke.local.json",
        help="Temporary public export path for the smoke check.",
    )
    smoke_parser.set_defaults(func=command_smoke_cycle)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
