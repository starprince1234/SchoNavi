from __future__ import annotations

from pydantic import BaseModel, Field


class QueryUnderstanding(BaseModel):
    research_interests: list[str] = Field(default_factory=list)
    preferred_locations: list[str] = Field(default_factory=list)
    preferred_universities: list[str] = Field(default_factory=list)
    degree_stage: str | None = None
    uncertainties: list[str] = Field(default_factory=list)


class Recommendation(BaseModel):
    professor_id: str
    name: str
    university: str | None = None
    college: str | None = None
    title: str | None = None
    research_fields: list[str] = Field(default_factory=list)
    homepage_url: str | None = None
    match_level: str | None = None
    match_score: float | None = None
    reason: str
    limitations: list[str] = Field(default_factory=list)


class RecommendationRequest(BaseModel):
    prompt: str
    session_id: str | None = None


class RecommendationResponse(BaseModel):
    session_id: str
    query_understanding: QueryUnderstanding
    recommendations: list[Recommendation] = Field(default_factory=list)
    follow_up_questions: list[str] = Field(default_factory=list)


class ProfessorDetail(BaseModel):
    professor_id: str
    name: str
    university: str | None = None
    college: str | None = None
    title: str | None = None
    research_fields: list[str] = Field(default_factory=list)
    bio: str | None = None
    homepage_url: str | None = None
    source_url: str | None = None
    updated_at: str | None = None
    data_quality_score: float | None = None


class ChatMessageRequest(BaseModel):
    session_id: str
    message: str
    professor_id: str | None = None


class ChatMessageResponse(BaseModel):
    session_id: str
    answer: str
    related_recommendations: list[Recommendation] = Field(default_factory=list)


class PlanSnapshotTask(BaseModel):
    id: str
    title: str
    kind: str | None = None
    estimated_hours: int | None = None
    completed_at: str | None = None
    due_date: str | None = None


class PlanSnapshotPhase(BaseModel):
    key: str
    title: str | None = None
    start_date: str | None = None
    end_date: str | None = None
    tasks: list[PlanSnapshotTask] = Field(default_factory=list)


class PlanSnapshot(BaseModel):
    id: str
    revision: int
    competition: dict
    target_date: str
    timeline_type: str | None = None
    event_end_date: str | None = None
    defense_date: str | None = None
    phases: list[PlanSnapshotPhase] = Field(default_factory=list)


class AssistantHistoryItem(BaseModel):
    role: str
    content: str
    card_results: list[dict] = Field(default_factory=list)


class PlanAssistantRequest(BaseModel):
    request_id: str
    calendar_today: str
    base_plan_revision: int
    plan_snapshot: PlanSnapshot
    user_message: str
    history: list[AssistantHistoryItem] = Field(default_factory=list)


class PlanChangeCardOut(BaseModel):
    id: str
    type: str
    summary: str
    rationale: str
    status: str = "pending"


class PlanChangeSetOut(BaseModel):
    id: str
    base_plan_revision: int
    cards: list[PlanChangeCardOut] = Field(default_factory=list)


class PlanAssistantData(BaseModel):
    reply: str
    change_set: PlanChangeSetOut
    request_id: str


class PlanAssistantEnvelope(BaseModel):
    code: int = 0
    message: str = "ok"
    data: PlanAssistantData

