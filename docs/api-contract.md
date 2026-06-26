# SchoNavi API Contract

This contract is the source of truth for future backend development. Flutter
domain entities and repository interfaces are the upstream model; the backend
must return these shapes through `/api/v1` endpoints.

## Conventions

- Base path: `/api/v1`
- Content type: `application/json; charset=utf-8`
- Field names: `snake_case`
- Time fields: ISO-8601 strings
- Success envelope:

```json
{ "code": 0, "message": "ok", "data": {} }
```

- Error envelope:

```json
{ "code": 40001, "message": "输入内容不合法", "data": null }
```

- Paginated list:

```json
{ "items": [], "page": 1, "page_size": 20, "total": 0 }
```

Common error codes:

| Code | HTTP | Meaning |
|---:|---:|---|
| `40001` | 400 | Invalid request |
| `40101` | 401 | Unauthorized |
| `40301` | 403 | Forbidden |
| `40401` | 404 | Resource not found |
| `42201` | 422 | Validation failed |
| `42901` | 429 | Rate limited |
| `50001` | 500 | Server error |

The backend may identify the current anonymous/user profile from its own
context. If explicit user binding is needed, accept optional header
`X-Client-User-Id`.

## Shared Models

### UserProfile

```json
{
  "name": "王同学",
  "gender": "undisclosed",
  "degree_stage": "本科",
  "target_degree": "申请硕士",
  "school": "四川大学",
  "major": "计算机科学与技术",
  "research_interests": ["计算机视觉", "医学影像"],
  "highlights": "有一段医学影像项目经历",
  "score": { "gpa": 3.8, "scale": 4.0, "rank": "前 10%" },
  "competitions": [
    { "name": "中国大学生计算机设计大赛", "level": "国家级", "award": "二等奖", "year": "2025" }
  ],
  "research": [
    { "type": "project", "title": "医学影像分割项目", "role": "负责人", "venue_or_status": "结题", "year": "2025" }
  ]
}
```

Enums:

- `gender`: `male`, `female`, `other`, `undisclosed`
- `research.type`: `paper`, `project`, `patent`, `other`

### Recommendation

```json
{
  "professor_id": "p_001",
  "name": "张三",
  "university": "上海交通大学",
  "college": "电子信息与电气工程学院",
  "title": "教授",
  "research_fields": ["医学影像", "计算机视觉"],
  "homepage_url": "https://example.edu.cn/zhangsan",
  "match_level": "高",
  "match_score": 0.92,
  "reason": "研究方向与用户需求高度相关。",
  "limitations": ["招生信息以学校官网为准"]
}
```

`match_level` values: `高`, `中`, `低`.

## Endpoints

### GET `/home/prompts`

Query:

- `mode`: `mentor` or `competition`

Response data:

```json
[
  { "text": "我想找计算机视觉方向的导师，最好在北京。" }
]
```

### POST `/recommendations/mentors`

Request:

```json
{
  "prompt": "我想找医学影像和计算机视觉方向的导师。",
  "session_id": "s_123",
  "profile": {}
}
```

`session_id` and `profile` are optional.

Response data:

```json
{
  "session_id": "s_123",
  "query_understanding": {
    "research_interests": ["医学影像", "计算机视觉"],
    "preferred_locations": ["上海"],
    "preferred_universities": [],
    "degree_stage": "硕士",
    "uncertainties": ["未明确偏理论还是应用"]
  },
  "recommendations": [],
  "follow_up_questions": ["偏理论", "偏应用", "只看985", "适合硕士"]
}
```

`follow_up_questions` is a legacy field name. Values should be short quick-action
labels for UI chips, not full questions.

### POST `/recommendations/competitions`

Request:

```json
{
  "prompt": "推荐近期可报名的人工智能竞赛。",
  "session_id": "c_123",
  "profile": {}
}
```

Response data:

```json
{
  "session_id": "c_123",
  "understanding": {
    "directions": ["人工智能"],
    "categories": ["计算机类"],
    "timing_preferences": ["近期可报名"],
    "team_preferences": ["团队赛"],
    "uncertainties": ["未明确可投入时间"]
  },
  "recommendations": [
    {
      "id": "comp_ai_creative",
      "name": "人工智能创新应用大赛",
      "category": "计算机类",
      "level": "国家级",
      "tags": ["AI", "应用"],
      "team_size": "1-5人",
      "signup_time": "以官网通知为准",
      "contest_time": "以官网通知为准",
      "format": "作品赛",
      "organizer": "主办方",
      "official_url": "https://example.com",
      "reason": "方向匹配。",
      "preparation_tips": ["先确定应用场景"],
      "limitations": ["以官网最新通知为准"],
      "match_score": 0.86
    }
  ],
  "follow_up_questions": ["算法赛", "作品赛", "团队赛", "近期可报"]
}
```

`follow_up_questions` is a legacy field name. Values should be short quick-action
labels for UI chips, not full questions.

### GET `/professors/{professor_id}`

Response data:

```json
{
  "professor_id": "p_001",
  "name": "张三",
  "university": "上海交通大学",
  "college": "电子信息与电气工程学院",
  "title": "教授",
  "research_fields": ["医学影像", "计算机视觉"],
  "bio": "主要研究医学影像分析。",
  "homepage_url": "https://example.edu.cn/zhangsan",
  "source_url": "https://example.edu.cn/zhangsan/source",
  "updated_at": "2026-06-01",
  "data_quality_score": 0.87
}
```

### POST `/chat/messages`

Request:

```json
{
  "session_id": "s_123",
  "message": "为什么推荐这位导师？",
  "professor_id": "p_001"
}
```

Response data:

```json
{
  "session_id": "s_123",
  "answer": "主要依据是研究方向匹配。",
  "related_recommendations": []
}
```

### GET `/chat/stream`

Query:

- `session_id`: required
- `message`: required
- `professor_id`: optional

Response content type: `text/event-stream`

Events:

```text
event: delta
data: {"text":"主要依据是"}

event: related_recommendations
data: {"items":[]}

event: done
data: {"session_id":"s_123"}

event: error
data: {"code":50001,"message":"服务异常，请稍后重试"}
```

### POST `/chat/route`

Decide whether a follow-up message needs a new round of recommendations (produce cards) or is a plain question about already-recommended mentors.

Request:

```json
{
  "follow_up": "只看上海的导师",
  "session_id": "s_123",
  "last_recommendations": [
    {
      "professor_id": "p_001",
      "name": "张三",
      "university": "上海交通大学",
      "research_fields": ["医学影像", "计算机视觉"]
    }
  ]
}
```

`follow_up` is required. `session_id` and `last_recommendations` are optional;
omit `last_recommendations` on the first turn (no prior recommendation). The
recap carries only routing-relevant fields — see `RecommendationRecap`.

Response data:

```json
{ "need": true }
```

`need` is a JSON boolean. The client degrades to `false` on any failure (non-zero
code, malformed `data`, network/timeout) — "宁可少产卡，不阻断对话".

`RecommendationRecap`:

```json
{
  "professor_id": "p_001",
  "name": "张三",
  "university": "上海交通大学",
  "research_fields": ["医学影像", "计算机视觉"]
}
```

### POST `/professors/compare`

Request:

```json
{ "professor_ids": ["p_001", "p_002"] }
```

Response data:

```json
{
  "professor_ids": ["p_001", "p_002"],
  "professors": [],
  "rows": [
    { "dimension": "研究方向匹配", "cells": { "p_001": "偏医学影像", "p_002": "偏大模型" } }
  ],
  "summary": "两位导师方向不同。",
  "suggestion": "若更看重医学影像可优先了解 p_001。"
}
```

### POST `/professors/{professor_id}/match-analysis`

Request:

```json
{ "profile": {} }
```

Response data:

```json
{
  "professor_id": "p_001",
  "summary": "方向较契合。",
  "strengths": ["项目经历相关"],
  "gaps": ["需要补充论文阅读"],
  "suggestions": ["阅读导师近三年论文"],
  "dimensions": [
    { "label": "方向契合", "score": 82, "comment": "研究兴趣接近。" }
  ]
}
```

### POST `/professors/{professor_id}/outreach-email`

Request:

```json
{ "profile": {} }
```

Response data:

```json
{ "subject": "关于医学影像方向研究生申请的咨询", "body": "张三教授您好..." }
```

### POST `/profile/achievements/extract`

Request:

```json
{ "raw_text": "我参加过数学建模竞赛，获得省级一等奖。" }
```

Response data:

```json
{
  "competitions": [{ "name": "数学建模竞赛", "level": "省级", "award": "一等奖" }],
  "research": []
}
```

### Profile

- `GET /profile`: returns `UserProfile`
- `PUT /profile`: request body is `UserProfile`, returns `UserProfile`
- `DELETE /profile`: returns `{ "cleared": true }`

### Favorites

- `GET /favorites`: returns `FavoriteItem[]`
- `PUT /favorites/{professor_id}`: request body is `FavoriteItem`, returns `{ "favorited": true, "item": FavoriteItem }`
- `DELETE /favorites/{professor_id}`: returns `{ "favorited": false }`

`FavoriteItem`:

```json
{
  "professor_id": "p_001",
  "name": "张三",
  "university": "上海交通大学",
  "college": "电子信息与电气工程学院",
  "title": "教授",
  "research_fields": ["医学影像"],
  "homepage_url": "https://example.edu.cn",
  "favorited_at": "2026-06-15T10:00:00Z"
}
```

### History

Search history is persisted by the backend in HTTP mode. The Flutter client
generates history snapshots after successful mentor or competition
recommendations and submits the complete `SearchHistoryItem`.

`SearchHistoryItem`:

```json
{
  "type": "mentor",
  "session_id": "s_123",
  "prompt": "医学影像 上海",
  "created_at": "2026-06-15T10:00:00.000Z",
  "summary": "方向：医学影像 / 地区：上海",
  "research_interests": ["医学影像"],
  "preferred_locations": ["上海"],
  "recommendation_count": 3
}
```

`type` values: `mentor`, `competition`.

#### GET `/history`

Response data is the full search history list, newest first preferred:

```json
[
  {
    "type": "mentor",
    "session_id": "s_123",
    "prompt": "医学影像 上海",
    "created_at": "2026-06-15T10:00:00.000Z",
    "summary": "方向：医学影像 / 地区：上海",
    "research_interests": ["医学影像"],
    "preferred_locations": ["上海"],
    "recommendation_count": 3
  }
]
```

#### POST `/history`

Request body is `SearchHistoryItem`. Response data is the saved
`SearchHistoryItem`; the backend may normalize or de-duplicate by `session_id`.

#### DELETE `/history/{session_id}`

Response data:

```json
{ "removed": true }
```

#### DELETE `/history`

Response data:

```json
{ "cleared": true }
```
