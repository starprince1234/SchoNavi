# 推荐卡片精细化打磨 + 开屏延长设计

> 日期：2026-06-28
> 范围：`SwipeRecommendationCard`（导师横滑卡）、`QueryUnderstandingCard`（需求理解卡）、开屏动画 1800ms→2000ms
> 视觉力度：**B 档（中度精炼）**，左强调条保持全局 indigo 不变
> 展示方式：先 HTML 预览定稿视觉 → 落真实 Flutter 代码 → Flutter Web 真机验证

## 一、背景与体检结论

项目视觉语言为「冷调玻璃拟态」：slate 中性 + indigo 主强调 + cyan 数据强调，
`AppColors` 为单一令牌源，`BentoTile` 为卡片基底（实心冷面，长列表友好）。

### SwipeRecommendationCard 现状短板
1. 姓名/职称/学校三行层次扁平，扫一眼抓不到重点。
2. `MatchLevelChip` 是静态小药丸，无数据感（competition 卡已有百分比，导师卡没有）。
3. 研究方向字段胶囊是纯灰底 `panel`，与冷调强调语言割裂。
4. 推荐理由是裸文本，无视觉锚点。
5. 底部「访问主页/收藏」按钮行视觉权重偏弱。

### QueryUnderstandingCard 现状短板
1. 仍是裸 `Card`，未接入 Bento 体系，与导师卡视觉语言断层。
2. 标题 + 三行纯文本，像表单草稿，无层次。
3. 待确认项是 `· x` 纯文本，无警示色权重。
4. 缺少「AI 正在理解你」的语义暗示。

## 二、数据契约约束

- `Recommendation.matchScore` 为 `double?` 可选字段。导师推荐 mock 数据当前**未填**该字段，
  LLM/AI 源可能填。设计须让「有 score」「无 score」两种状态都好看：有则显示百分比 + mini 进度弧，
  无则退化为纯文字药丸（现状 MatchLevelChip）。
- `MatchLevel` 三档：high/medium/low，标签「高/中/低」。
- 卡片宿主：`RecommendationCarousel`（PageView，固定高度 250 + 文本缩放补偿）。
  改动不得突破该高度约束，`SwipeRecommendationCard` 仍需 `Spacer` 撑底。

## 三、SwipeRecommendationCard 视觉重构（B 档）

布局骨架不变（`BentoTile` + 4px indigo 左条 + 右内容），重构层次与色彩：

### 3.1 顶部信息分级
- 姓名 `titleMedium w700`（现状保留）。
- 职称降为 `labelSmall` 弱化，与姓名同行右侧或紧贴其下。
- 学校/学院提为带 `school_outlined` 图标（indigo）的单行 `bodySmall`。
- 形成「重—弱—中」节奏，替代现状三行扁平灰字。

### 3.2 匹配度数据胶囊（MatchLevelChip 升级）
- 当 `matchScore != null`：胶囊内追加百分比数字（如 `86%`），并在胶囊左侧画
  一个 mini 进度弧（CustomPaint，基于 score 0–1，strokeWidth≈2，半径≈10）。
  high 档弧用 indigo，medium 用 cyan，low 用 inkSoft。
- 当 `matchScore == null`：保持现状纯文字药丸「匹配度：高」。
- 胶囊背景沿用 MatchLevel 语义色（high=indigo 实色白字、medium=indigoSoft、low=panel）。

### 3.3 研究方向字段胶囊强调化
- `_CompactFields` 底色从 `panel` 灰改为 `indigoSoft`，文字 `indigoPressed`。
- 隐藏项 `+N` 改为 `cyanSoft` 底 / `cyan` 字。
- 使其成为「能力标签」而非占位灰块，与 indigo 强调语言统一。

### 3.4 推荐理由引述化
- 左侧加 3px `cyan` 竖条 + `format_quote` 微图标（14px，cyanSoft）。
- 文字 `bodyMedium`（现状），`maxLines: 2`（现状保留）。
- 把「为什么推你」从流水账变为有锚点的引述。

### 3.5 底部操作行强化
- 收藏按钮：按下态在 scale(0.85) 之外，加一层 `indigoSoft` 背景晕（AnimatedContainer）。
  已收藏态图标 `bookmark` 用 `indigo` 填色 + 外发光（`shadowGlow` 缩放版）。
- 「访问主页」TextButton 文字与图标改 `cyan` 强调色（现状默认色）。

## 四、QueryUnderstandingCard 视觉重构（B 档）

### 4.1 接入 Bento 体系
- 裸 `Card` → `BentoTile`（实心冷面，borderRadius 18，shadowCool）。
- 统一与导师卡视觉语言。

### 4.2 AI 语义头
- 标题行加 `auto_awesome` 图标（indigo）+ 「我理解到的需求」`titleMedium`。
- 暗示「AI 正在理解你」。

### 4.3 结构化键值网格
- 三行纯文本 → 键值行：左侧 `labelSmall` 键（研究方向/地域偏好/学历阶段），
  右侧 `bodySmall` 值，中间对齐。键用 `inkSoft`，值用 `ink`。
- 「暂无信息」用 `inkFaint` 弱化，避免与有值行同等权重。

### 4.4 待确认项（本次不做）
- 「待确认」警示胶囊本次不做（暂不需要跨校联培等复杂待确认功能）。
  `uncertainties` 字段仍保留渲染，但退回现状的 `· x` 纯文本，不升级为 danger 胶囊。
  仅做 §4.1–4.3。

### 4.5 竞赛版（本次不改）
- `CompetitionQueryUnderstandingCard` 本次保持现状，不在打磨范围内。
  后续如需统一两版视觉，再单独开 spec。

## 五、开屏动画延长（1800ms → 2000ms）

### 5.1 时长调整
- `SplashPage._ticker` duration：`1800ms → 2000ms`。
- 类文档注释 `1.8s` → `2.0s`。

### 5.2 三段绘制节奏重平衡（保持叙事完整性）
原节奏：圆角方底 [0.0,0.30]、帆叶 [0.20,0.70]、航向线 [0.60,0.90]、字标 [0.75,1.0]。
延长 200ms 后，若不调区间，帆叶生长会显得仓促、结尾留白偏长。重平衡为：
- 圆角方底：[0.0, 0.28]（入场稍快收尾）
- 帆叶：[0.18, 0.68]（生长区间略前置，节奏更从容）
- 航向线：[0.58, 0.88]
- 字标：[0.72, 1.0]
- fade-out：200ms 不变（isCompleted 后）。

### 5.3 测试影响
- `splash_page_test.dart` 断言「初始渲染 logo + 字标存在」「点按跳过→completed」
  「GestureDetector 存在」——均与时长无关，不受影响。
- `splash_logo_painter_test.dart` 若断言具体 progress→绘制对应关系，需同步更新区间常量。
  实现后跑测试确认。

## 六、展示与验证流程

1. **HTML 预览**：忠实复刻冷调玻璃拟态（slate/indigo/cyan、blur、shadow），
   呈现 SwipeRecommendationCard 与 QueryUnderstandingCard 的 B 档定稿视觉，
   含「有 matchScore / 无 matchScore」两态、light/dark。浏览器秒开，快速迭代。
2. **落真实 Flutter 代码**：将定稿同步到 `swipe_recommendation_card.dart`、
   `match_level_chip.dart`、`query_understanding_card.dart`、
   `competition_query_understanding_card.dart`、`splash_page.dart`、`splash_logo_painter.dart`。
3. **Flutter Web 真机验证**：`flutter run -d chrome`，处理 drift/secure_storage web 配置，
   热重载微调，截图确认真实渲染与 HTML 预览一致。

## 七、测试策略

- `swipe_recommendation_card_test.dart`：现有 6 个断言（姓名/职称/学校/匹配度文案/
  onTap/收藏不冒泡/已收藏 tooltip/访问主页/长内容不溢出）须全绿。新增：
  - `matchScore != null` 时渲染百分比 + 进度弧（CustomPaint 存在）。
  - 研究方向字段胶囊底色为 indigoSoft。
- `query_understanding_card_test.dart`：新增/更新键值渲染、待确认 danger 胶囊。
- splash 测试同步区间常量后全绿。
- 全量 `flutter test` 收尾。

## 八、不做的事（YAGNI）

- 不改 `ProfessorCard`（结果页完整卡，本次范围外）。
- 不改 `CompetitionCard` 及 `CompetitionQueryUnderstandingCard`（本次范围外）。
- 不启用 frosted 毛玻璃（C 档，与长列表性能约定冲突）。
- 不改左强调条配色（用户明确拒绝变色）。
- 不改 `RecommendationCarousel` 高度/分页逻辑。
