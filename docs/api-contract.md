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

### Identity and ownership

- The first anonymous request calls `POST /identity/anonymous`.
- Mobile clients persist the returned bearer token in secure storage and send
  `Authorization: Bearer <token>`.
- Same-origin Web clients use the `HttpOnly`, `Secure`, `SameSite=Lax`
  `scho_anonymous` cookie set by the same endpoint.
- Chat ownership always comes from the authenticated identity. An `owner_id`
  supplied by a request body is ignored/rejected; it is never an authorization
  source.
- Missing or invalid identity returns `401`. A session owned by another
  identity is not exposed and returns `404`.

### Conversation identifiers and concurrency

`session_id`, `turn_id`, `message_id`, `attempt_id`, and `request_id` are
independent UUIDv7 values. Their strings carry no parent/child semantics.
Conversation mutations use `expected_revision`; a mismatch fails rather than
silently overwriting newer state. Creating a turn or attempt also requires
`Idempotency-Key: <request_id>`, and the header must equal the JSON
`request_id`.

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

### POST `/identity/anonymous`

Creates an installation-level anonymous identity. Response data:

```json
{
  "owner_id": "0197...",
  "access_token": "random-secret-token"
}
```

If a valid `scho_anonymous` cookie or bearer token already exists, the endpoint
reuses that owner. Cookie-authenticated Web calls return an empty
`access_token`; Web code must rely on the HttpOnly cookie rather than copying a
bearer into browser storage.

### Conversation sessions

`ConversationSession`:

```json
{
  "id": "0197...",
  "kind": "general",
  "root_session_id": "0197...",
  "source_session_id": null,
  "source_turn_id": null,
  "professor_id": null,
  "revision": 0,
  "title": null,
  "created_at": "2026-06-27T08:00:00Z",
  "updated_at": "2026-06-27T08:00:00Z",
  "deleted_at": null,
  "legacy_context_incomplete": false
}
```

`kind` is `general`, `professor`, or `fork`. Only a `fork` has
`source_session_id` and `source_turn_id`. A professor-anchored conversation
without a valid recommendation source is a `professor` session, never a fake
fork.

- `POST /chat/sessions` creates a `general` or `professor` session. Body:
  `{ "kind": "general", "professor_id": null }`.
- `GET /chat/sessions` returns `{ "items": ConversationSession[] }`, excluding
  fork sessions and deleted sessions.
- `GET /chat/sessions/{id}` returns `{ session, turns, messages }`.
- `GET /chat/sessions/{id}/turns` returns `{ turns, messages }`.
- For a `fork`, both read endpoints return only turns and messages created in
  that fork. The inherited source prefix remains server-side model context and
  is never projected into the fork's visible history.
- `GET /chat/sessions/{rootId}/forks` returns
  `{ "items": ConversationSession[] }`.
- `DELETE /chat/sessions/{id}` transactionally deletes the session. Deleting a
  root also deletes its forks, turns, attempts, messages, summaries, and cache;
  deleting a fork does not affect the root.

### POST `/chat/sessions/{sourceId}/forks`

Request:

```json
{ "source_turn_id": "0197...", "professor_id": "p_001" }
```

The source turn must be a completed recommendation turn containing the named
professor. `(sourceId, source_turn_id, professor_id)` is unique per owner, so
concurrent duplicates return the same fork. The fork context is permanently
bounded to the source conversation prefix ending at `source_turn_id`.

### POST `/chat/sessions/{id}/turns`

Headers: `Authorization` and `Idempotency-Key` are required. Request:

```json
{
  "text": "为什么推荐这位导师？",
  "request_id": "0197...",
  "expected_revision": 3
}
```

Response is `text/event-stream`. Every event carries `session_id`, `turn_id`,
`attempt_id`, and `revision`; clients must discard events that do not match the
current operation.

```text
event: ack
data: {"session_id":"...","turn_id":"...","attempt_id":"...","revision":3}

event: route
data: {"session_id":"...","turn_id":"...","attempt_id":"...","revision":3,"route":"conversation"}

event: delta
data: {"session_id":"...","turn_id":"...","attempt_id":"...","revision":3,"text":"主要依据是"}

event: completed
data: {"session_id":"...","turn_id":"...","attempt_id":"...","revision":4,"session":{},"message":{},"quick_actions":[]}

event: error
data: {"session_id":"...","turn_id":"...","attempt_id":"...","revision":3,"code":"revision_conflict","message":"会话已更新"}
```

`route` is `recommendation`, `conversation`, or `forkReroute`.
`completed.message.related_recommendations` and the final session descriptor
are authoritative and must not be discarded by the client.

### Attempts, cancellation, and feedback

- `POST /chat/turns/{turnId}/attempts` regenerates an existing turn without
  adding another user message. Body:
  `{ "session_id": "...", "request_id": "...", "expected_revision": 4 }`.
  It returns the same SSE event grammar as turn submission.
- `POST /chat/attempts/{attemptId}/cancel` persists the active attempt as
  `interrupted`; partial text is not represented as completed.
- `PATCH /chat/messages/{messageId}/feedback` persists
  `{ "feedback": "like" }`, `{ "feedback": "dislike" }`, or
  `{ "feedback": "none" }`.

The server is authoritative in HTTP mode and constructs model context from
stored conversation state. Clients may cache completed aggregates for offline
reading, but do not queue offline sends.

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

> Legacy compatibility endpoint. New clients use the session/turn endpoints
> above.

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

### POST `/chat/quick-actions`

Generate short quick-action chip labels for the input bar above the composer. Called on conversation start and after each conversational turn's stream completes (recommendation turns already carry `follow_up_questions` in their result).

Request:

```json
{
  "follow_up": "只看上海的导师",
  "last_recommendations": [
    {
      "professor_id": "p_001",
      "name": "张三",
      "university": "清华大学",
      "research_fields": ["计算机视觉", "医学影像"]
    }
  ]
}
```

`follow_up` is required (empty string on conversation start). `last_recommendations` is optional; omit on the first turn (no prior recommendation). The recap carries only routing-relevant fields — see `RecommendationRecap` (same shape as `/chat/route`), capped to 5 entries by the client.

Response data:

```json
{
  "quick_actions": ["换一批", "偏应用", "只看985", "适合博士"]
}
```

`quick_actions` should be 1-4 short action labels (≤8 CJK chars each), operation phrases only — no full questions, no question marks, no interrogative prefixes like "你/是否/请问". On empty/missing `quick_actions`, the client hides the chips for that turn. On transport failure, the client falls back to a hardcoded default set.

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

### POST `/preparation-plans/generate`

Generate personalized optional tasks and advice for a competition preparation plan.

Request:

```json
{
  "competition": {
    "id": "comp_ai_creative",
    "name": "人工智能创新应用大赛",
    "category": "计算机类",
    "rules_summary": {
      "signup_time": "2026-07-01 ~ 2026-09-01",
      "contest_time": "2026-10-01 ~ 2026-11-01",
      "team_size": "1-5人",
      "format": "作品赛",
      "organizer": "主办方",
      "official_url": "https://example.com"
    }
  },
  "target_date": "2026-10-01T00:00:00Z",
  "weekly_commitment": "hours6to10",
  "experience_level": "intermediate",
  "phase_keys": ["research", "team_building", "prototyping", "polishing", "submission"],
  "user_profile": {}
}
```

`weekly_commitment` values: `hours3to5`, `hours6to10`, `hours11to15`,
`hours16plus`.

`experience_level` values: `beginner`, `intermediate`, `experienced`.

`phase_keys` is the client-side allowed phase key set. The server must only
return phases whose `key` is in this set.

`user_profile` is optional and follows the `UserProfile` shape.

Response data:

```json
{
  "phases": [
    {
      "key": "research",
      "optional_tasks": [
        { "template_key": "read_rules", "title": "仔细阅读官方规则", "estimated_hours": 2 },
        { "title": "收集往届优秀作品", "estimated_hours": 3 }
      ],
      "personalized_advice": "建议重点理解评分维度。"
    }
  ],
  "global_advice": "整体时间较紧，建议优先完成核心功能。"
}
```

`optional_tasks` contains at most 3 items per phase. `template_key` is optional;
when present it must be unique within the phase. `estimated_hours` is a number.

Common errors: `40001` invalid request, `42201` validation failed, `50001`
server error.

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

These legacy history endpoints now store competition searches only. Mentor
conversation history is derived exclusively from `/chat/sessions`; clients
must not write a second mentor-session index through `/history`.

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

New writes use `type = competition`. `mentor` is accepted only while reading or
migrating old data.

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
