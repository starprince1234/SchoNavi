from __future__ import annotations

from copy import deepcopy
from time import time

from app.services.schemas import (
    ChatMessageResponse,
    ProfessorDetail,
    QueryUnderstanding,
    Recommendation,
    RecommendationResponse,
)


MOCK_PROFESSORS: list[ProfessorDetail] = [
    ProfessorDetail(
        professor_id="p_001",
        name="张三",
        university="上海交通大学",
        college="电子信息与电气工程学院",
        title="教授",
        research_fields=["医学影像", "计算机视觉", "深度学习"],
        bio="主要研究医学影像分析、计算机视觉与深度学习在临床场景中的应用。",
        homepage_url="https://example.edu.cn/zhangsan",
        source_url="https://example.edu.cn/zhangsan/source",
        updated_at="2026-06-01",
        data_quality_score=0.87,
    ),
    ProfessorDetail(
        professor_id="p_002",
        name="李娜",
        university="清华大学",
        college="计算机科学与技术系",
        title="副教授",
        research_fields=["自然语言处理", "大模型", "知识图谱"],
        bio="关注自然语言处理、知识增强大模型与可信人工智能。",
        homepage_url="https://example.edu.cn/lina",
        source_url="https://example.edu.cn/lina/source",
        updated_at="2026-05-20",
        data_quality_score=0.82,
    ),
    ProfessorDetail(
        professor_id="p_003",
        name="王伟",
        university="浙江大学",
        college="控制科学与工程学院",
        title="研究员",
        research_fields=["机器人", "强化学习", "智能控制"],
        bio="研究机器人感知决策、强化学习和智能控制系统。",
        homepage_url="https://example.edu.cn/wangwei",
        source_url="https://example.edu.cn/wangwei/source",
        updated_at="2026-04-18",
        data_quality_score=0.79,
    ),
]


def mock_recommendations(prompt: str, session_id: str | None = None) -> RecommendationResponse:
    prompt = prompt.strip()
    understood = _understand(prompt)
    ranked = _rank(prompt)
    recommendations = [
        _to_recommendation(professor, score=max(0.55, 0.92 - index * 0.09))
        for index, professor in enumerate(ranked)
    ]
    return RecommendationResponse(
        session_id=session_id or f"s_{int(time() * 1000)}",
        query_understanding=understood,
        recommendations=recommendations,
        follow_up_questions=[
            "偏理论",
            "偏应用",
            "只看985",
            "适合硕士",
        ],
    )


def mock_professor(professor_id: str) -> ProfessorDetail | None:
    normalized = normalize_professor_id(professor_id)
    for professor in MOCK_PROFESSORS:
        if professor.professor_id == normalized:
            return deepcopy(professor)
    return None


def mock_chat(
    session_id: str,
    message: str,
    professor_id: str | None = None,
) -> ChatMessageResponse:
    anchor = mock_professor(professor_id or "") if professor_id else None
    text = message.strip()
    related: list[Recommendation] = []

    if any(token in text for token in ["相似", "类似", "还有"]):
        related = [
            _to_recommendation(professor, 0.76)
            for professor in MOCK_PROFESSORS
            if professor.professor_id != normalize_professor_id(professor_id or "")
        ][:2]
        answer = "我按研究方向相近度和学院背景找了几位可继续比较的导师。"
    elif any(token in text for token in ["北京", "上海", "江浙沪", "地区", "只看"]):
        related = [_to_recommendation(professor, 0.74) for professor in _rank(text)[:2]]
        answer = "我已按你补充的地区偏好重新筛选，下面这些导师更接近新的限制条件。"
    elif anchor and any(token in text for token in ["为什么", "理由", "推荐"]):
        answer = (
            f"推荐{anchor.name}的主要依据是研究方向包含"
            f"{'、'.join(anchor.research_fields[:3])}，与当前需求有较高重合度。"
        )
    else:
        answer = "为了更准地帮你，可以补充研究方向、目标地区、申请阶段或偏理论/应用的偏好。"

    return ChatMessageResponse(
        session_id=session_id,
        answer=answer,
        related_recommendations=related,
    )


def normalize_professor_id(value: str | int | None) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if text.startswith("p_"):
        return text
    if text.isdigit():
        return f"p_{int(text):03d}"
    return text


def _to_recommendation(professor: ProfessorDetail, score: float) -> Recommendation:
    return Recommendation(
        professor_id=professor.professor_id,
        name=professor.name,
        university=professor.university,
        college=professor.college,
        title=professor.title,
        research_fields=professor.research_fields,
        homepage_url=professor.homepage_url,
        match_level="高" if score >= 0.8 else "中",
        match_score=round(score, 2),
        reason="公开资料显示其研究方向与用户需求相关，适合作为进一步了解对象。",
        limitations=["示例数据仅用于本地降级演示，请以学校官网信息为准"],
    )


def _rank(prompt: str) -> list[ProfessorDetail]:
    scores: list[tuple[int, ProfessorDetail]] = []
    for professor in MOCK_PROFESSORS:
        text = " ".join([
            professor.name,
            professor.university or "",
            professor.college or "",
            " ".join(professor.research_fields),
        ])
        score = sum(1 for token in _tokens(prompt) if token and token in text)
        scores.append((score, professor))
    return [professor for _, professor in sorted(scores, key=lambda item: item[0], reverse=True)]


def _understand(prompt: str) -> QueryUnderstanding:
    tokens = _tokens(prompt)
    research = [
        token
        for token in ["医学影像", "计算机视觉", "自然语言处理", "大模型", "知识图谱", "机器人", "人工智能"]
        if token in prompt
    ]
    locations = [token for token in ["北京", "上海", "江浙沪", "杭州", "南京", "浙江"] if token in prompt]
    universities = [token for token in ["清华", "清华大学", "上海交通大学", "浙江大学"] if token in prompt]
    degree_stage = None
    for stage in ["本科", "硕士", "博士", "研究生"]:
        if stage in prompt:
            degree_stage = stage
            break
    uncertainties = [] if research else ["未明确具体研究方向"]
    if len(tokens) < 2:
        uncertainties.append("需求描述较短，建议补充地区或申请阶段")
    return QueryUnderstanding(
        research_interests=research,
        preferred_locations=locations,
        preferred_universities=universities,
        degree_stage=degree_stage,
        uncertainties=uncertainties,
    )


def _tokens(prompt: str) -> list[str]:
    return [
        token
        for token in ["医学影像", "计算机视觉", "自然语言处理", "大模型", "知识图谱", "机器人", "北京", "上海", "江浙沪"]
        if token in prompt
    ]

