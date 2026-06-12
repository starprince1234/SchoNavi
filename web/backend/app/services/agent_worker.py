from __future__ import annotations

import asyncio
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


def _emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def _agent_root() -> Path:
    configured = os.getenv("BACKEND_AGENT_PATH")
    if configured:
        return Path(configured).resolve()
    cwd_candidate = Path.cwd()
    if (cwd_candidate / "app").exists():
        return cwd_candidate
    return Path(__file__).resolve().parents[3] / "backend_agent"


def _normalize_id(value: str | int | None) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if text.startswith("p_"):
        text = text[2:]
    match = re.search(r"\d+", text)
    return int(match.group(0)) if match else None


async def _run(payload: dict[str, Any]) -> dict[str, Any]:
    root = _agent_root()
    sys.path.insert(0, str(root))

    from sqlmodel import Session, select

    from app.models.base import engine, init_db
    from app.models.item import Item
    from app.models.org_unit import OrgUnit
    from app.services.evidence_assembler import assemble_recommendation_evidence
    from app.services.recommendation_service import RecommendationService

    init_db()
    action = payload.get("action")
    service = RecommendationService()

    if action == "recommend":
        return await service.recommend(query=payload.get("prompt", ""), top_k=10)

    if action == "follow_up":
        return await service.follow_up(
            previous_request_id=payload.get("session_id", ""),
            query=payload.get("message", ""),
            top_k=10,
        )

    if action == "similar":
        professor_id = _normalize_id(payload.get("professor_id"))
        return await service.recommend(query=f"similar:{professor_id}", top_k=5)

    if action == "professor":
        item_id = _normalize_id(payload.get("professor_id"))
        if item_id is None:
            return {"code": 40404, "message": "导师不存在", "data": None}
        with Session(engine) as session:
            item = session.exec(select(Item).where(Item.id == item_id)).first()
            if item is None:
                return {"code": 40404, "message": "导师不存在", "data": None}
            org_unit = None
            if item.org_unit:
                org_unit = session.exec(select(OrgUnit).where(OrgUnit.name == item.org_unit)).first()
            return {"code": 0, "message": "success", "data": assemble_recommendation_evidence(item, org_unit)}

    return {"code": 40001, "message": "未知操作", "data": None}


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        result = asyncio.run(_run(payload))
        _emit({"ok": True, "result": result})
    except Exception as exc:
        _emit({"ok": False, "error": str(exc)})


if __name__ == "__main__":
    main()
