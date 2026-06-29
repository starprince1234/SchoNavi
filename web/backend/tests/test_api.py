from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_recommendations_shape_and_mock_fallback() -> None:
    response = client.post(
        "/api/recommendations",
        json={"prompt": "我想找医学影像和计算机视觉方向的导师，最好在上海，适合申请硕士。"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["session_id"]
    assert "query_understanding" in payload
    assert payload["recommendations"]
    assert payload["follow_up_questions"] == ["偏理论", "偏应用", "只看985", "适合硕士"]
    recommendation = payload["recommendations"][0]
    assert {"professor_id", "name", "research_fields", "reason", "limitations"} <= set(recommendation)


def test_recommendations_reject_empty_prompt() -> None:
    response = client.post("/api/recommendations", json={"prompt": "   "})
    assert response.status_code == 422


def test_professor_detail_supports_mock_id() -> None:
    response = client.get("/api/professors/p_001")
    assert response.status_code == 200
    payload = response.json()
    assert payload["professor_id"] == "p_001"
    assert payload["name"] == "张三"


def test_chat_messages_shape() -> None:
    response = client.post(
        "/api/chat/messages",
        json={
            "session_id": "s_test",
            "message": "为什么推荐这位导师？",
            "professor_id": "p_001",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["session_id"] == "s_test"
    assert payload["answer"]
    assert isinstance(payload["related_recommendations"], list)


def _assistant_body(plan_id: str = "pp_1", revision: int = 1, message: str = "往后挪") -> dict:
    return {
        "request_id": "req_test_1",
        "calendar_today": "2026-05-01",
        "base_plan_revision": revision,
        "plan_snapshot": {
            "id": plan_id,
            "revision": revision,
            "competition": {},
            "target_date": "2026-05-30",
        },
        "user_message": message,
    }


def test_plan_assistant_success_envelope() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(),
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["code"] == 0
    assert payload["message"] == "ok"
    data = payload["data"]
    assert data["request_id"] == "req_test_1"
    assert data["reply"]
    assert data["change_set"]["base_plan_revision"] == 1
    assert len(data["change_set"]["cards"]) == 2


def test_plan_assistant_rejects_empty_message() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(message="   "),
    )
    assert response.status_code == 422


def test_plan_assistant_rejects_plan_id_mismatch() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_other/assistant",
        json=_assistant_body(plan_id="pp_1"),
    )
    assert response.status_code == 422


def test_plan_assistant_rejects_revision_mismatch() -> None:
    response = client.post(
        "/api/v1/preparation-plans/pp_1/assistant",
        json=_assistant_body(revision=1) | {"base_plan_revision": 5},
    )
    assert response.status_code == 422

