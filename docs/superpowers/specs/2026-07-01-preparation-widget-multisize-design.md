# 备赛桌面小组件多尺寸与视觉升级 · 设计文档

- 日期：2026-07-01
- 分支：iter4rc2
- 关联提交：`25e0ac6 feat(preparation): 备赛提醒与桌面小组件`（已有单档小组件雏形）

## 1. 背景与动机

现有备赛桌面小组件（[PreparationWidgetProvider.kt](android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt)）仅两档布局：`compact`（<250dp）与 `expanded`（≥250dp），靠 `OPTION_APPWIDGET_MIN_WIDTH` 二选一。视觉为信息平铺（倒计时、阶段、任务、进度同字号），未充分利用 Android 12+ 的可调尺寸格子能力；轮换依赖 30 分钟一次的 `onUpdate`，用户实际感知不到"雨露均沾"。

此外发现真实 Bug：widget 调色板（`widget_surface`/`widget_primary`/…）**仅定义于 [values-night/colors.xml](android/app/src/main/res/values-night/colors.xml)**，[values/colors.xml](android/app/src/main/res/values/colors.xml) 缺失，浅色模式下引用未定义资源 —— 小组件从未在日间模式验证过。本次一并修复。

### 目标

1. **多尺寸**：提供 Micro（1×1/1×2）、Small（2×2）、Wide（4×2）、Hero（4×3）四档布局，按系统格子尺寸自适应。
2. **视觉升级**：冷调玻璃拟态，倒计时+进度双视觉为主锚点（Micro 退化为倒计时大字 + 进度细线）；跟随系统明暗模式。
3. **充分利用系统能力**：`targetCellWidth/Height` + `minResizeWidth/Height` + `resizeMode` 让用户长按拖拽边框自由调尺寸；`AlarmManager` 30s 间隔自动轮换多个进行中计划；保持一键 `requestPinAppWidget`。
4. **修复 Bug**：补齐 `values/colors.xml` 的 widget 调色板。

### 非目标（YAGNI）

- 不引入 `ViewFlipper` 轮播动画（启动器兼容性不一）。
- 不做 1×2 横向双计划并排（点击区域易误触，留待后续）。
- 不做点击区域分区直达任务（保持整卡点击进计划详情页）。
- 不做手动切换按钮（轮换纯自动）。
- 不更换 LLM 提供商、不引入新状态管理库。

## 2. 现状速览（受影响代码）

| 文件 | 现状 | 本次动作 |
|---|---|---|
| [PreparationWidgetProvider.kt](android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt) | compact/expanded 二选一渲染 | 改为四档尺寸分派 + 阶段轴着色 |
| [preparation_widget_compact.xml](android/app/src/main/res/layout/preparation_widget_compact.xml) | compact 布局 | 重作为 `preparation_widget_micro.xml` |
| [preparation_widget_expanded.xml](android/app/src/main/res/layout/preparation_widget_expanded.xml) | expanded 布局 | 拆为 `small.xml` / `wide.xml` / `hero.xml` |
| [preparation_widget_info.xml](android/app/src/main/res/xml/preparation_widget_info.xml) | minWidth 250 / targetCell 4×2 | 加 `minResizeWidth/Height`、`targetCellWidth/Height` 区间 |
| [values-night/colors.xml](android/app/src/main/res/values-night/colors.xml) | 唯一调色板来源 | 保留并微调 |
| [values/colors.xml](android/app/src/main/res/values/colors.xml) | 缺 widget 调色板 | **新增** widget 调色板（日间） |
| [ReminderStorage.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt) | 解析 snapshot v1 | 解析新增 `phases` 字段，升 schemaVersion=2 |
| [preparation_reminder.dart](lib/domain/entities/preparation_reminder.dart) | snapshot 实体 | 新增 `phases` 字段 + schemaVersion=2 |
| [preparation_reminder_builder.dart](lib/domain/services/preparation_reminder_builder.dart) | 构建 snapshot | 计算每阶段 status 并填入 |
| [PreparationWidgetProvider.kt](android/app/src/main/kotlin/com/example/scho_navi/PreparationWidgetProvider.kt) `rotate` | `onUpdate` 30min 轮换 | 新增 `WidgetRotationScheduler`（AlarmManager 30s） |
| [ReminderScheduler.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderScheduler.kt) | 通知调度 | 不动，新增独立的 `WidgetRotationReceiver` |
| [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) | 注册 WidgetProvider | 注册 `WidgetRotationReceiver` |
| [test/android_manifest_test.dart](test/android_manifest_test.dart) | 断言 manifest 集成 | 扩充断言新 receiver + 四档布局资源存在 |

## 3. 数据模型变更（snapshot 升级 schemaVersion=2）

### 3.1 Dart 实体扩展

[lib/domain/entities/preparation_reminder.dart](lib/domain/entities/preparation_reminder.dart)：

```dart
enum ReminderPhaseStatus { completed, active, upcoming }

class PreparationReminderPhaseSummary {
  const PreparationReminderPhaseSummary({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
  });
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final ReminderPhaseStatus status;

  Map<String, dynamic> toJson() => {
    'title': title,
    'startDate': _isoDay(startDate),
    'endDate': _isoDay(endDate),
    'status': status.name,
  };
}
```

`PreparationReminderPlanSummary` 新增 `phases: List<PreparationReminderPhaseSummary>`（默认空列表，向后兼容旧数据）。

`PreparationReminderSnapshot.schemaVersion` 由 `1` 升为 `2`。

### 3.2 Builder 计算阶段 status

[preparation_reminder_builder.dart](lib/domain/services/preparation_reminder_builder.dart) 的 `_summary` 复用已有 `_currentPhase` 逻辑，对每个 `plan.phases` 计算：

- `today > endDate` → `completed`
- `startDate <= today <= endDate` → `active`
- `today < startDate` → `upcoming`

阶段轴最多取前 5 段（Hero 容量上限），超出截断。少于 5 段按实际数量渲染。

### 3.3 Kotlin 解析升级

[ReminderStorage.kt](android/app/src/main/kotlin/com/example/scho_navi/ReminderStorage.kt)：

- `ReminderPlan` 增加 `phases: List<ReminderPhase>`。
- `loadSnapshot` 接受 `schemaVersion` 1 或 2：v1 缺 `phases` 字段时按空列表处理（向后兼容已安装用户）。
- 新增 `data class ReminderPhase(title, startDate, endDate, status: String)`。

## 4. 尺寸分派与布局规格

### 4.1 尺寸分派逻辑

`PreparationWidgetProvider.render` 读取 `AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH` / `OPTION_APPWIDGET_MIN_HEIGHT`，按"最小可用尺寸"分档（任一维度低于阈值即视为更小档）：

| 条件（取最先匹配） | Layout | 系统格子典型 |
|---|---|---|
| min_width < 180 **或** min_height < 110 | `preparation_widget_micro` | 1×1, 1×2, 2×1 |
| min_width < 250（且高度 ≥ 110） | `preparation_widget_small` | 2×2 |
| min_height < 180（且宽度 ≥ 250） | `preparation_widget_wide` | 4×2, 3×2 |
| min_width ≥ 250 **且** min_height ≥ 180 | `preparation_widget_hero` | 4×3, 4×4, 3×3 |

判按上表自上而下顺序匹配，命中即停。`onAppWidgetOptionsChanged`（用户拖拽边框）触发重渲染，实时切档。

### 4.2 widget_info.xml

```xml
<appwidget-provider
    android:description="@string/preparation_widget_description"
    android:initialLayout="@layout/preparation_widget_small"
    android:minWidth="120dp"
    android:minHeight="100dp"
    android:minResizeWidth="100dp"
    android:minResizeHeight="100dp"
    android:maxResizeWidth="480dp"
    android:maxResizeHeight="420dp"
    android:previewLayout="@layout/preparation_widget_hero"
    android:resizeMode="horizontal|vertical"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
```

`minWidth` 从 250 降到 120 以支持 Micro；`minResizeWidth/Height=100dp` 让用户能拖到最小格；`targetCellWidth/Height=2` 默认放置为 2×2（Small），用户可拖大到 4×3（Hero）。

### 4.3 四档布局内容规格

所有档共用：圆角 22dp 玻璃面背景（`preparation_widget_background.xml` 微调：日间半透明白叠冷渐变、夜间深 slate 半透明）、`widget_root` 点击跳 `/preparation-plans/{planId}`、空态走 `widget_empty_group`。

#### Micro（`preparation_widget_micro.xml`）
- 顶行：竞赛名（14sp bold，单行省略）
- 主视觉：`D-XX` 倒计时（28sp bold，indigo 主色）
- 底部：4dp 高进度细线（indigo→cyan 渐变）+ `6/10` 极小字（9sp）

#### Small（`preparation_widget_small.xml`，沿用 expanded 骨架精简）
- 顶行：竞赛名 + `1/3` position chip
- 倒计时行：`D-12`（20sp）+ 当前阶段名（11sp 次色）
- 下一任务行：`刷完 5 道动规`（12sp bold）+ 截止（10sp）
- 底部：进度条 + `6/10 · 60%` + 🔥 streak（10sp accent）

#### Wide（`preparation_widget_wide.xml`）
- 左栏（38%）：竞赛名 + position、`D-12`、当前阶段、🔥 streak
- 右栏：分隔线 + 下一任务 + 截止 + 进度环（54dp，indigo→cyan 渐变 stroke）+ `60%` `6/10 完成`

#### Hero（`preparation_widget_hero.xml`）
- 顶行：竞赛名 + position + 🔥 streak（含"今天已推进"）
- 主视觉：`D-12`（46sp bold）+ "距目标 12 天" + 右侧 72dp 进度环（环内 `60%`）
- **阶段轴**：最多 5 段 5dp 横条，按 status 着色（completed/active=渐变、upcoming=track 色），下方阶段名行（active 段 indigo 高亮）
- 底行：`下一项 · 刷完 5 道动规` + 截止

### 4.4 调色板补齐（values/colors.xml）

新增日间 widget 调色板（与 `AppColors` 对齐）：

```xml
<color name="widget_surface">#FFFFFF</color>
<color name="widget_border">#E2E8F0</color>
<color name="widget_primary">#4F46E5</color>      <!-- indigo -->
<color name="widget_secondary">#0891B2</color>     <!-- cyan -->
<color name="widget_accent">#C2410C</color>        <!-- streak 暖橙日间 -->
<color name="widget_text_primary">#0F172A</color>
<color name="widget_text_secondary">#475569</color>
<color name="widget_chip">#E0E7FF</color>
<color name="widget_progress_track">#E2E8F0</color>
```

夜间（values-night）保留现有，仅 `widget_accent` 由 `#FDBA74` 保持。进度渐变用 `GradientDrawable`（`preparation_widget_progress.xml` 新增）替代纯色 `progressTint`。

## 5. 自动轮换机制（AlarmManager 30s）

### 5.1 新增 WidgetRotationScheduler

新文件 `WidgetRotationScheduler.kt` + `WidgetRotationReceiver`：

- `WidgetRotationScheduler.start(context)` / `stop(context)`：用 `AlarmManager.setRepeating(RTC, now+30s, 30_000ms, pi)` 排定。`RTC`（非 `_WAKEUP`）避免唤醒设备 —— 屏幕灭时不必轮换，亮屏后自然刷新。
- `WidgetRotationReceiver.onReceive`：发送 `ACTION_ROTATE` 广播给 `PreparationWidgetProvider`（**非** 现有 `ACTION_REFRESH`）。
- 触发点：
  - `MainActivity` `syncSnapshot` 成功后，按阈值 `start`/`stop`（见下）
  - `MainActivity.onCreate` 若 snapshot 非空则 `start`
  - `onDeleted` 删到无 widget 时 `stop`
- 阈值：`snapshot.plans.size <= 1` 时 `stop`（单计划无轮换意义），`> 1` 时 `start`。

### 5.2 ACTION_ROTATE 与 ACTION_REFRESH 分流

`PreparationWidgetProvider` 现有 `ACTION_REFRESH` 在 `onReceive` 里调 `render(..., rotate = false)`（数据变更刷新，不轮换索引）。新增 `ACTION_ROTATE`：

- `onReceive` 收到 `ACTION_ROTATE` → 对每个 widget id 调 `render(..., rotate = true)`（`rotate=true` 时 `(previous + 1) % size` 推进索引）。
- `ACTION_REFRESH`（外部数据变更、`refreshAll`）保持 `rotate = false`。
- `rotate = (previous + 1) % size` 仅在 `snapshot.plans.size > 1` 时推进；`size <= 1` 时保持索引 0（与 §5.1 `stop` 阈值一致，双保险）。

`refreshAll(context)` 仍发 `ACTION_REFRESH`（数据变更用），不用于轮换。

### 5.3 系统约束遵守

- `setRepeating` 在 Android 12+ 仍可用（非 Doze-whitehole，但 30s 间隔对前台可见 widget 可接受）。若需更严格可用 `setExactAndAllowWhileIdle` 但会触发权限提示，本次不采用。
- 无需新增权限（`AlarmManager` 不需声明权限，`setRepeating` 普通权限）。

## 6. 视觉与资源文件清单

新增/修改的 Android 资源：

- `res/layout/preparation_widget_micro.xml`（新，由 compact 改名重做）
- `res/layout/preparation_widget_small.xml`（新，由 expanded 精简）
- `res/layout/preparation_widget_wide.xml`（新）
- `res/layout/preparation_widget_hero.xml`（新）
- 删除 `preparation_widget_compact.xml`、`preparation_widget_expanded.xml`（被上述替代）
- `res/drawable/preparation_widget_background.xml`（微调：日夜间分版或用 `?android:attr/colorBackground` 配合主题）
- `res/drawable/preparation_widget_progress.xml`（新，`GradientDrawable` indigo→cyan 横向）
- `res/drawable/preparation_widget_phase_done.xml` / `_active.xml` / `_upcoming.xml`（新，阶段轴分段着色）
- `res/drawable/ic_widget_streak.xml`（保留，色调跟随）
- `res/values/colors.xml`（补 widget 日间调色板）
- `res/values-night/colors.xml`（保留微调）
- `res/xml/preparation_widget_info.xml`（按 §4.2 更新）
- `res/values/strings.xml`（`preparation_widget_description` 更新为"四档尺寸 · 倒计时 · 进度 · 阶段轴"）

### 进度环实现约束

`RemoteViews` 不支持任意 `Canvas` 绘制。进度环用 `ProgressBar` 的 `style="?android:attr/progressBarStyleHorizontal"` + 旋转 270° 的 `LayeredDrawable` 模拟环形（或用 `Android 12+` 的 `RemoteViews.setViewVisibility` 切换预设环形 drawable）。Wide/Hero 的进度环具体实现：用 `preparation_widget_ring_60.xml` 等**预渲染百分比档位** drawable（每 10% 一档，0/10/.../100 共 11 个 vector），按 progress 选档 `setImageViewBitmap`。这是 widget 内画环的标准做法，避免运行时绘制。

## 7. 测试策略

### 7.1 Flutter 单元测试

- `test/domain/preparation_reminder_builder_test.dart`：扩充用例
  - 多阶段计划的 `phases` status 计算（completed/active/upcoming）
  - 阶段数 > 5 时截断为 5
  - 旧 snapshot（v1 schema）反序列化 `phases` 为空列表
- `test/data/local/preparation_reminder_store_test.dart`：snapshot toJson 含 `phases` + `schemaVersion=2`

### 7.2 Android manifest / 资源测试

- `test/android_manifest_test.dart` 扩充：
  - `WidgetRotationReceiver` 已注册
  - 四档 layout 文件存在（用 `File` 读 `android/app/src/main/res/layout/preparation_widget_*.xml`）
  - `values/colors.xml` 含 `widget_surface`（回归 Bug）
  - `preparation_widget_info.xml` 含 `minResizeWidth`、`targetCellWidth`

### 7.3 视觉人工验证

CLAUDE.md 要求 UI 改动需运行 App 验证。本次为原生 widget，需：
- `flutter run` 安装 App → 同步一个含 2+ 计划的 snapshot
- 长按桌面添加 SchoNavi 小组件 → 拖拽边框在 1×1 / 2×2 / 4×2 / 4×3 间切换，确认四档正确切档
- 切换系统明暗模式，确认两套调色板
- 等待 30s 确认自动轮换到下一计划

若本地无设备/模拟器，明确说明"未做实机验证"。

## 8. 实现顺序（供 writing-plans 参考）

1. 修 Bug：补 `values/colors.xml` widget 调色板（最小独立改动，先解隐患）
2. 数据层：扩展 `PreparationReminderPhaseSummary` + builder + store 测试（Dart 侧先绿）
3. Kotlin 解析：`ReminderStorage` 升 schemaVersion=2 + `ReminderPlan.phases` 解析
4. 四档 layout XML + drawable 资源
5. `PreparationWidgetProvider` 尺寸分派 + 阶段轴着色 + 空态
6. `WidgetRotationScheduler` + `WidgetRotationReceiver` + manifest 注册
7. `widget_info.xml` 更新
8. 测试扩充 + 人工验证

## 9. 风险与回退

- **风险**：`setRepeating` 30s 在部分国产 ROM（MIUI/EMUI）被限制为最小间隔。**缓解**：若 `setRepeating` 失效，退化为 30min `onUpdate` 轮换（现状），不影响功能只影响体验。
- **风险**：进度环预渲染 drawable 工作量大（11 档 × 渐变）。**缓解**：先用横条 ProgressBar 上线，进度环作为 Wide/Hero 的"视觉加分项"可后续补；spec 标注为 P1。
- **回退**：Dart 侧仅扩展 snapshot 字段（向后兼容 v1，旧数据 `phases` 缺失按空列表解析，不破坏既有备赛/提醒业务）；原生侧为资源 + Kotlin 改动。回退即还原 layout 文件、`widget_info.xml` 与 Kotlin 新增文件，snapshot v2 字段保留无害。

## 10. 验收标准

- [ ] 四档 layout 在对应尺寸下正确渲染，无内容溢出/截断
- [ ] 用户长按拖拽 widget 边框能实时切档
- [ ] 系统明暗切换后调色板正确（无未定义资源报错）
- [ ] 多计划（≥2）时 30s 内自动轮换；单计划不轮换
- [ ] 空态（无进行中计划）显示"还没有进行中的备赛计划"
- [ ] 点击任意档跳转对应计划详情页
- [ ] `flutter test` 全绿（新增 builder/store 测试通过）
- [ ] `test/android_manifest_test.dart` 扩充断言通过
- [ ] `dart format --set-exit-if-changed lib test` 无变更
