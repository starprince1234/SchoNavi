import sqlite3
import json
from pathlib import Path
from typing import Any

from sqlmodel import Session, select

from app.core.config import get_settings
from app.models import Item, OrgUnit, init_db
from app.models.base import engine as target_engine

settings = get_settings()


def _resolve_path(path_value: str) -> Path:
    source = Path(path_value)
    if source.is_absolute():
        return source
    return Path.cwd() / source


def _source_db_path() -> Path:
    source = Path(settings.SCU_SOURCE_DB)
    if source.is_absolute():
        return source
    return Path.cwd() / source


def _source_db_paths() -> list[Path]:
    if settings.SOURCE_DBS:
        return [_resolve_path(part.strip()) for part in settings.SOURCE_DBS.split(",") if part.strip()]

    source_dir = _resolve_path(settings.SOURCE_DB_DIR)
    if source_dir.exists():
        return sorted(source_dir.glob(settings.SOURCE_DB_GLOB))

    legacy_path = _source_db_path()
    return [legacy_path] if legacy_path.exists() else []


def _connect_readonly(path: Path) -> sqlite3.Connection:
    try:
        return sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro&immutable=1", uri=True)
    except sqlite3.OperationalError as exc:
        raise sqlite3.OperationalError(f"unable to open source DB {path}: {exc}") from exc


def _text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _value(row: sqlite3.Row, column: str) -> Any:
    return row[column] if column in row.keys() else None


def _metadata(row: sqlite3.Row, source_name: str, entity_type: str) -> str:
    return json.dumps(
        {
            "email": _text(_value(row, "email")),
            "phone": _text(_value(row, "phone")),
            "homepage": _text(_value(row, "homepage")),
            "external_link": _text(_value(row, "external_link")),
            "enrollment_pref": _text(_value(row, "enrollment_pref")),
            "publications": _text(_value(row, "publications")),
            "source": source_name,
            "entity_type": entity_type,
        },
        ensure_ascii=False,
    )


def _table_exists(con: sqlite3.Connection, table_name: str) -> bool:
    row = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        (table_name,),
    ).fetchone()
    return row is not None


def _table_columns(con: sqlite3.Connection, table_name: str) -> set[str]:
    return {row[1] for row in con.execute(f"PRAGMA table_info({table_name})").fetchall()}


def _column_expr(columns: set[str], column: str) -> str:
    if column in columns:
        return f"t.{column} AS {column}"
    return f"NULL AS {column}"


def _fetch_entity_rows(con: sqlite3.Connection, table_name: str) -> list[sqlite3.Row]:
    if not _table_exists(con, table_name):
        return []
    columns = _table_columns(con, table_name)
    org_unit_expr = (
        "t.org_unit_name AS org_unit_name"
        if "org_unit_name" in columns
        else "o.name AS org_unit_name"
        if "org_unit_id" in columns and _table_exists(con, "org_units")
        else "NULL AS org_unit_name"
    )
    join_clause = (
        " LEFT JOIN org_units o ON t.org_unit_id = o.id"
        if "org_unit_id" in columns and "org_unit_name" not in columns and _table_exists(con, "org_units")
        else ""
    )
    return con.execute(
        f"""SELECT
                  t.id AS id,
                  t.name AS name,
                  {org_unit_expr},
                  {_column_expr(columns, "title")},
                  {_column_expr(columns, "research_areas")},
                  {_column_expr(columns, "email")},
                  {_column_expr(columns, "phone")},
                  {_column_expr(columns, "homepage")},
                  {_column_expr(columns, "external_link")},
                  {_column_expr(columns, "bio")},
                  {_column_expr(columns, "enrollment_pref")},
                  {_column_expr(columns, "publications")}
           FROM {table_name} t
           {join_clause}
           WHERE t.name IS NOT NULL AND TRIM(t.name) != ''"""
    ).fetchall()


def import_source_db(source_path: Path) -> dict[str, int | str]:
    """Import professor-like entities from one raw SQLite source DB into app.db."""
    init_db()
    if not source_path.exists():
        raise FileNotFoundError(f"Source DB not found: {source_path}")

    source_name = source_path.name
    con = _connect_readonly(source_path)
    con.row_factory = sqlite3.Row
    try:
        org_units = (
            con.execute(
                "SELECT id, name, url, kind, status FROM org_units WHERE COALESCE(status, 'active') = 'active'"
            ).fetchall()
            if _table_exists(con, "org_units")
            else []
        )
        entity_rows = {
            "professor": _fetch_entity_rows(con, "professors"),
            "academician": _fetch_entity_rows(con, "academicians"),
        }
    finally:
        con.close()

    imported_org_units = 0
    imported_items = 0
    updated_items = 0

    with Session(target_engine) as session:
        existing_org_names = {org.name for org in session.exec(select(OrgUnit)).all()}
        for row in org_units:
            name = _text(row["name"])
            if not name or name in existing_org_names:
                continue
            session.add(
                OrgUnit(
                    name=name,
                    url=_text(row["url"]) or "",
                    kind=_text(row["kind"]),
                    status=_text(row["status"]) or "active",
                )
            )
            existing_org_names.add(name)
            imported_org_units += 1

        existing_by_source_key = {
            (item.source_id, item.source_entity_type, item.source_pk): item
            for item in session.exec(select(Item).where(Item.source_pk.is_not(None))).all()
        }
        existing_by_external_id = {
            item.external_id: item
            for item in session.exec(select(Item).where(Item.external_id.is_not(None))).all()
        }

        for entity_type, rows in entity_rows.items():
            for row in rows:
                name = _text(_value(row, "name"))
                if not name:
                    continue
                source_pk = str(_value(row, "id"))
                external_id = f"{source_name}:{entity_type}:{source_pk}"
                source_key = (source_name, entity_type, source_pk)
                item = existing_by_source_key.get(source_key) or existing_by_external_id.get(external_id)
                is_new = item is None
                if item is None:
                    item = Item(external_id=external_id, title=name)
                    session.add(item)

                org_unit = _text(_value(row, "org_unit_name"))
                item.external_id = external_id
                item.entity_id = external_id
                item.source_id = source_name
                item.source_entity_type = entity_type
                item.source_pk = source_pk
                item.source_external_id = source_pk
                item.title = name
                item.category = org_unit
                item.description = _text(_value(row, "bio"))
                item.research_areas = _text(_value(row, "research_areas"))
                item.org_unit = org_unit
                item.tags = _text(_value(row, "title"))
                item.metadata_json = _metadata(row, source_name, entity_type)
                item.is_active = True
                if item.popularity is None:
                    item.popularity = 0.5

                existing_by_source_key[source_key] = item
                existing_by_external_id[external_id] = item
                if is_new:
                    imported_items += 1
                else:
                    updated_items += 1

        session.commit()

    source_items = sum(len(rows) for rows in entity_rows.values())
    result: dict[str, int | str] = {
        "source": source_name,
        "source_items": source_items,
        "source_org_units": len(org_units),
        "imported_org_units": imported_org_units,
        "imported_items": imported_items,
        "updated_items": updated_items,
    }
    print(result)
    return result


def import_all_sources() -> dict[str, object]:
    """Import every configured raw SQLite source DB."""
    source_paths = _source_db_paths()
    if not source_paths:
        raise FileNotFoundError(
            f"No source DBs found in {settings.SOURCE_DB_DIR!r} matching {settings.SOURCE_DB_GLOB!r}"
        )

    sources = [import_source_db(path) for path in source_paths]
    return {
        "sources": sources,
        "source_count": len(sources),
        "imported_items": sum(int(source["imported_items"]) for source in sources),
        "updated_items": sum(int(source["updated_items"]) for source in sources),
        "imported_org_units": sum(int(source["imported_org_units"]) for source in sources),
    }


def import_scu_data() -> dict[str, int | str]:
    """Import professor and org_unit data from scu.edu.cn.db into app.db."""
    return import_source_db(_source_db_path())


if __name__ == "__main__":
    import_all_sources()
