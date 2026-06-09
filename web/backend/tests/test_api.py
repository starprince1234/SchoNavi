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

