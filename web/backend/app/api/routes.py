from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.services.agent_adapter import AgentAdapter
from app.services.schemas import (
    ChatMessageRequest,
    ChatMessageResponse,
    ProfessorDetail,
    RecommendationRequest,
    RecommendationResponse,
)

router = APIRouter()
adapter = AgentAdapter()


@router.post("/recommendations", response_model=RecommendationResponse)
async def get_recommendations(request: RecommendationRequest) -> RecommendationResponse:
    if not request.prompt.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="prompt 不能为空",
        )
    return await adapter.get_recommendations(
        prompt=request.prompt,
        session_id=request.session_id,
    )


@router.get("/professors/{professor_id}", response_model=ProfessorDetail)
async def get_professor(professor_id: str) -> ProfessorDetail:
    professor = await adapter.get_professor(professor_id)
    if professor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="导师不存在")
    return professor


@router.post("/chat/messages", response_model=ChatMessageResponse)
async def send_message(request: ChatMessageRequest) -> ChatMessageResponse:
    if not request.session_id.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="session_id 不能为空",
        )
    if not request.message.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="message 不能为空",
        )
    return await adapter.send_message(
        session_id=request.session_id,
        message=request.message,
        professor_id=request.professor_id,
    )

