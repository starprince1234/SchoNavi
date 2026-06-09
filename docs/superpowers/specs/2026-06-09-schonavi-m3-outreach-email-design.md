# SchoNavi M3 · 套磁邮件生成设计

- 版本：v1（2026-06-09，首稿——M3 实现前可再细化）
- 关系：引用 `2026-06-09-schonavi-m1-llm-core-design.md`（`LlmClient`/接地/DI 切换）。
- 前置：M1 已落地。M2 可选（邮件正文可流式，但不强依赖）。

---

## 1. 目标与价值

从导师详情页**一键生成个性化套磁邮件草稿**：模型据【导师方向 + 学生背景】生成可编辑、可复制的中文邮件（主题 + 正文）。这是关键词 App 完全做不到的**生成式内容**，AIGC 味最足、答辩最惊艳，直接服务「创新性 / 大模型应用能力」。

**非目标**：真发邮件（只生成草稿 + 复制/分享）；多语言（先中文，英文留后续）。

---

## 2. 新增领域模型

```dart
// domain/entities/user_profile.dart —— 学生背景，本地持久化，M3/M5 共用
class UserProfile {
  const UserProfile({
    this.name, this.degreeStage, this.school, this.major,
    this.researchInterests = const [], this.highlights,
  });
  final String? name;          // 称呼用
  final String? degreeStage;   // 本科/硕士在读 等
  final String? school;        // 现就读学校
  final String? major;         // 专业
  final List<String> researchInterests;
  final String? highlights;    // 自述：成果/项目/绩点等（自由文本）
  bool get isEmpty => /* 全空判断 */ ;
}

// domain/entities/email_draft.dart —— 生成结果
class EmailDraft {
  const EmailDraft({required this.subject, required this.body});
  final String subject;
  final String body;
}
```

## 3. 新增仓储接口

```dart
// domain/repositories/profile_repository.dart —— 本地（同收藏/历史模式）
abstract interface class ProfileRepository {
  UserProfile load();
  Future<void> save(UserProfile profile);
}

// domain/repositories/outreach_email_repository.dart —— 远程类（走 Result）
abstract interface class OutreachEmailRepository {
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  });
}
```

- `LocalProfileRepository`：经 `LocalStore` 存 JSON（参照 `LocalFavoriteRepository`）。
- `AiOutreachEmailRepository`：用 `LlmClient.complete(jsonMode:true)` 生成 `{subject, body}`；接地——导师事实取自传入 `Professor`，学生信息只用 `profile`，**不编造未提供的成果**。
- `MockOutreachEmailRepository`：模板拼装（离线兜底/测试）。

## 4. 交互流程

详情页新增「生成套磁邮件」按钮 →
1. 若 `profile.isEmpty` → 弹背景填写 sheet（姓名/阶段/学校/专业/方向/自述），保存到本地（下次复用）。
2. 调 `generate(...)` → loading →
3. 邮件草稿页：可编辑的**主题**与**正文**两个输入框 + 「复制」「重新生成」「保存背景」。复制用系统剪贴板。
- 新增 feature 目录 `features/email/`（`pages/email_page.dart` + `providers/email_provider.dart` + 背景 sheet widget）。路由 `/email?pid=<professorId>`。

## 5. Prompt 设计（要点）

system：你是帮学生撰写**套磁邮件**的助手。据【导师】与【学生背景】生成中文邮件，输出 JSON `{subject, body}`（json）。规则：礼貌专业、200-350 字；正文含"自我介绍→为何对该导师方向感兴趣（结合其研究方向）→自身相关基础（仅用学生提供的信息，不得编造）→请求（了解招生/读研读博机会）→礼貌结尾"；不要填写真实联系方式占位符以外的虚构事实；称呼用导师姓名+职称。
user：`【导师】{name,title,university,college,researchFields,bio}\n【学生背景】{profile 各字段}`。

## 6. DI

```dart
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(ref.watch(localStoreProvider)));

final outreachEmailRepositoryProvider = Provider<OutreachEmailRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock: return MockOutreachEmailRepository();
    case DataSource.ai:   return AiOutreachEmailRepository(ref.watch(llmClientProvider));
    case DataSource.http: throw UnimplementedError('V1.0');
  }
});
```

## 7. 测试策略（TDD）

| 测试 | 覆盖 |
|---|---|
| `local_profile_repository_test` | 存/取往返；空 profile 默认值 |
| `ai_outreach_email_repository_test` | 假 LlmClient 返回 `{subject,body}` JSON → 解析；坏 JSON → Failure；接地（仅用 profile 字段，prompt 含导师方向） |
| `mock_outreach_email_repository_test` | 模板含导师名/方向 |
| `email_provider_test` | 无 profile→提示填写；生成 loading/done/error；重新生成 |
| `email_page_test`（widget） | 显示可编辑主题/正文；复制回调；保存背景 |
| `email_entry_point_test` | 详情页按钮跳 `/email?pid=` |
| `email_repository_provider_test` | 默认 mock 接线 |

## 8. 偏差/开放问题

1. **正文是否流式**：M3 默认非流式（一次出全文，便于编辑）；接 M2 后可对正文做流式预览，作为增强。
2. **UserProfile 复用**：M3 引入并本地持久化，M5 背景匹配复用同一 profile，避免重复录入。
3. **英文邮件**：先不做，留 V1.0（多语言）。
