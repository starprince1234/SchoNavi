from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from app.services.mock_provider import (
    mock_chat,
    mock_professor,
    mock_recommendations,
    normalize_professor_id,
)
from app.services.schemas import (
    ChatMessageResponse,
    ProfessorDetail,
    QueryUnderstanding,
    Recommendation,
    RecommendationResponse,
)


class AgentAdapter:
    def __init__(self, timeout_seconds: float | None = None) -> None:
        self.timeout_seconds = timeout_seconds or float(os.getenv("API_TIMEOUT_SECONDS", "18"))
        self.backend_agent_path = Path(os.getenv("BACKEND_AGENT_PATH", "backend_agent"))
        if not self.backend_agent_path.is_absolute():
            self.backend_agent_path = Path(__file__).resolve().parents[3] / self.backend_agent_path
        self.worker_path = Path(__file__).resolve().parent / "agent_worker.py"

    async def get_recommendations(self, prompt: str, session_id: str | None = None) -> RecommendationResponse:
        if not prompt.strip():
            raise ValueError("prompt must not be empty")
        if session_id:
            agent_result = self._call_agent({
                "action": "follow_up",
                "session_id": session_id,
                "message": prompt,
            })
        else:
            agent_result = self._call_agent({"action": "recommend", "prompt": prompt})
        if agent_result is not None:
            mapped = _map_recommendation_response(agent_result, fallback_session_id=session_id)
            if mapped.recommendations:
                return mapped
        return mock_recommendations(prompt, session_id)

    async def get_professor(self, professor_id: str) -> ProfessorDetail | None:
        agent_result = self._call_agent({"action": "professor", "professor_id": professor_id})
        if agent_result and agent_result.get("code") == 0 and agent_result.get("data"):
            return _map_professor(agent_result["data"])
        return mock_professor(professor_id)

    async def send_message(
        self,
        session_id: str,
        message: str,
        professor_id: str | None = None,
    ) -> ChatMessageResponse:
        if not message.strip():
            raise ValueError("message must not be empty")

        action = "similar" if professor_id and _asks_for_similar(message) else "follow_up"
        payload = {
            "action": action,
            "session_id": session_id,
            "message": message,
            "professor_id": professor_id,
        }
        agent_result = self._call_agent(payload)
        if agent_result is not None:
            related = _map_recommendation_response(agent_result, fallback_session_id=session_id).recommendations
            if related:
                return ChatMessageResponse(
                    session_id=session_id,
                    answer=_chat_answer(message, professor_id, bool(related)),
                    related_recommendations=related,
                )
        return mock_chat(session_id=session_id, message=message, professor_id=professor_id)

    def _call_agent(self, payload: dict[str, Any]) -> dict[str, Any] | None:
        if not self.backend_agent_path.exists():
            return None
        env = os.environ.copy()
        env.setdefault("PYTHONIOENCODING", "utf-8")
        try:
            completed = subprocess.run(
                [sys.executable, str(self.worker_path)],
                input=json.dumps(payload, ensure_ascii=False),
                capture_output=True,
                encoding="utf-8",
                cwd=str(self.backend_agent_path),
                env=env,
                timeout=self.timeout_seconds,
                check=False,
            )
        except Exception:
            return None
        if completed.returncode != 0 or not completed.stdout.strip():
            return None
        last_line = completed.stdout.strip().splitlines()[-1]
        try:
            envelope = json.loads(last_line)
        except json.JSONDecodeError:
            return None
        if not envelope.get("ok"):
            return None
        result = envelope.get("result")
        return result if isinstance(result, dict) else None


def _map_recommendation_response(
    agent_result: dict[str, Any],
    fallback_session_id: str | None = None,
) -> RecommendationResponse:
    data = agent_result.get("data") if agent_result.get("code") == 0 else None
    if not isinstance(data, dict):
        return RecommendationResponse(
            session_id=fallback_session_id or str(agent_result.get("request_id") or ""),
            query_understanding=QueryUnderstanding(),
            recommendations=[],
            follow_up_questions=[],
        )
    session_id = str(data.get("request_id") or agent_result.get("request_id") or fallback_session_id or "")
    recommendations = [
        _map_recommendation(item)
        for item in data.get("recommendations", [])
        if isinstance(item, dict)
    ]
    understanding = _map_query_understanding(data.get("query_understanding"))
    follow_up_questions = _string_list(data.get("follow_up_questions"))
    if not follow_up_questions and _needs_follow_up(understanding):
        follow_up_questions = ["偏理论", "偏应用", "只看985", "适合硕士"]
    return RecommendationResponse(
        session_id=session_id,
        query_understanding=understanding,
        recommendations=recommendations,
        follow_up_questions=follow_up_questions,
    )


def _map_recommendation(item: dict[str, Any]) -> Recommendation:
    score = _number(item.get("match_score", item.get("score")))
    professor_id = _professor_id(item.get("professor_id", item.get("item_id")))
    research_fields = _string_list(item.get("research_fields"))
    if not research_fields:
        research_fields = _split_text(item.get("research_areas"))
    limitations = _string_list(item.get("limitations"))
    reason = str(item.get("reason") or "该导师与当前需求存在研究方向或机构背景上的相关性。")
    return Recommendation(
        professor_id=professor_id,
        name=str(item.get("name") or item.get("title") or "未知导师"),
        university=_optional_text(item.get("university")),
        college=_optional_text(item.get("college") or item.get("org_unit") or item.get("category")),
        title=_optional_text(item.get("academic_title") or item.get("title_label") or item.get("tags")),
        research_fields=research_fields,
        homepage_url=_optional_text(item.get("homepage_url")),
        match_level=_optional_text(item.get("match_level")) or _match_level(score),
        match_score=score,
        reason=reason,
        limitations=limitations,
    )


def _map_professor(item: dict[str, Any]) -> ProfessorDetail:
    score = _number(item.get("data_quality_score") or item.get("quality_score"))
    return ProfessorDetail(
        professor_id=_professor_id(item.get("professor_id", item.get("item_id"))),
        name=str(item.get("name") or item.get("title") or "未知导师"),
        university=_optional_text(item.get("university")),
        college=_optional_text(item.get("college") or item.get("org_unit") or item.get("category")),
        title=_optional_text(item.get("academic_title") or item.get("title_label") or item.get("tags")),
        research_fields=_string_list(item.get("research_fields")) or _split_text(item.get("research_areas")),
        bio=_optional_text(item.get("bio") or item.get("summary") or item.get("description")),
        homepage_url=_optional_text(item.get("homepage_url")),
        source_url=_optional_text(item.get("source_url")),
        updated_at=_optional_text(item.get("updated_at")),
        data_quality_score=score,
    )


def _map_query_understanding(data: Any) -> QueryUnderstanding:
    if not isinstance(data, dict):
        return QueryUnderstanding()
    nested = data.get("query_understanding")
    if isinstance(nested, dict):
        data = nested
    return QueryUnderstanding(
        research_interests=_string_list(data.get("research_interests") or data.get("tags") or data.get("keywords")),
        preferred_locations=_string_list(data.get("preferred_locations")),
        preferred_universities=_string_list(data.get("preferred_universities")),
        degree_stage=_optional_text(data.get("degree_stage")),
        uncertainties=_string_list(data.get("uncertainties")),
    )


def _professor_id(value: Any) -> str:
    return normalize_professor_id(value)


def _optional_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    return _split_text(value)


def _split_text(value: Any) -> list[str]:
    if value is None:
        return []
    import re

    return [part.strip() for part in re.split(r"[/、，,;；\n]+", str(value)) if part.strip()]


def _number(value: Any) -> float | None:
    try:
        if value is None:
            return None
        return round(float(value), 4)
    except (TypeError, ValueError):
        return None


def _match_level(score: float | None) -> str | None:
    if score is None:
        return None
    if score >= 0.8:
        return "高"
    if score >= 0.5:
        return "中"
    return "低"


def _needs_follow_up(understanding: QueryUnderstanding) -> bool:
    return bool(understanding.uncertainties) or not understanding.research_interests


def _asks_for_similar(message: str) -> bool:
    return any(token in message for token in ["相似", "类似", "还有", "同方向"])


def _chat_answer(message: str, professor_id: str | None, has_related: bool) -> str:
    if professor_id and any(token in message for token in ["为什么", "理由", "推荐"]):
        return "推荐依据主要来自研究方向匹配、公开资料完整度和与当前需求的语义相关性。"
    if has_related:
        return "我根据你补充的条件重新收窄了推荐范围，下面是可继续比较的导师。"
    return "我已记录你的补充条件，可以继续说明地区、研究方向或申请阶段来提高匹配度。"
