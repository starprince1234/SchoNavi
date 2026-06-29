from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.services.agent_adapter import AgentAdapter
from app.services.schemas import (
    ChatMessageRequest,
    ChatMessageResponse,
    PlanAssistantData,
    PlanAssistantEnvelope,
    PlanAssistantRequest,
    PlanChangeCardOut,
    PlanChangeSetOut,
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


@router.post(
    "/v1/preparation-plans/{plan_id}/assistant",
    response_model=PlanAssistantEnvelope,
)
async def plan_assistant(
    plan_id: str, request: PlanAssistantRequest
) -> PlanAssistantEnvelope:
    if not request.user_message.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="user_message 不能为空",
        )
    if plan_id != request.plan_snapshot.id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="plan_id 与 plan_snapshot.id 不一致",
        )
    if request.base_plan_revision != request.plan_snapshot.revision:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="base_plan_revision 与 plan_snapshot.revision 不一致",
        )
    return PlanAssistantEnvelope(
        data=PlanAssistantData(
            reply="我整理了两项可单独确认的调整。",
            change_set=PlanChangeSetOut(
                id="cs_backend_1",
                base_plan_revision=request.base_plan_revision,
                cards=[
                    PlanChangeCardOut(
                        id="cc_backend_move",
                        type="move_task",
                        summary="把【核心算法实现】移到 5 月 22 日",
                        rationale="避开期末考试周，同时仍早于提交 DDL。",
                    ),
                    PlanChangeCardOut(
                        id="cc_backend_add",
                        type="add_task",
                        summary="答辩准备阶段新增一次模拟答辩",
                        rationale="在正式答辩前预留复盘时间。",
                    ),
                ],
            ),
            request_id=request.request_id,
        )
    )

