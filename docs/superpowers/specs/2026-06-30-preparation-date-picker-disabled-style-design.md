# 备赛日期选择器置灰设计

- 日期：2026-06-30
- 主题：`PreparationDatePicker` 月历中"不能选"的日子视觉置灰并禁用点击
- 涉及文件：`lib/features/preparation/widgets/preparation_date_picker.dart`、`test/features/preparation/widgets/preparation_date_picker_test.dart`

## 背景与问题

`PreparationDatePicker`（底部弹层月历）被两处调用：

- `lib/features/preparation/pages/preparation_plan_form_page.dart:156`（表单页选比赛起止 / DDL+答辩）
- `lib/features/preparation/pages/preparation_plan_detail_page.dart:431`（详情页改 DDL）

当前 `_dayCell`（`preparation_date_picker.dart:260-284`）对落在 `[firstDate, lastDate]` 窗口外的日子把 `onTap` 置为 `null`，但**渲染样式与可选日子完全一致**（同样 `onSurface` 文本色、无底色）。用户看不出哪些能点、哪些不能点，产生"看起来能点但点不动"的误解。

此外，range / multiAnchor 模式存在"翻转 / 重置"隐式逻辑：

- range：选了 start 后点早于 start 的日子，会把新点变 start、原 start 变 end（翻转）。
- multiAnchor：选了 DDL 后点 DDL 之前的日子，会重置 DDL。

这些隐式逻辑让"哪些日子当前有效"更不直观。

## 目标

让月历中"不能选"的日子在视觉上一眼可辨，并禁用其点击，消除误解；同时把 range / multiAnchor 的翻转 / 重置逻辑改为"只允许合法选择"。

## 范围

- 仅改 `preparation_date_picker.dart` 与其测试。
- 调用方（表单页、详情页）零改动。
- 不引入新依赖。
- 详情页 `_DueDatePicker`（`preparation_plan_detail_page.dart:540`）用的是 Flutter 内置 `showDatePicker`，其禁用态由框架自带，不在本次改动内。

## 置灰规则

新增 `_isSelectable(DateTime day)` 判定，按 mode + 当前选择状态动态计算。

### 通用前置

`day` 必须在 `[firstDate, lastDate]` 闭区间内，否则一律不可选。

### single 模式

区间内所有日子均可选。

### range 模式

- 未选 start，或 start+end 都已选（准备开启新一轮）：区间内全可选。
- 只选了 start（等选 end）：`day >= start` 可选；`day < start` 置灰。
- 点 `day == start` 当天：取消 start（回到未选状态），等价于现有"重置"语义但更直观。
- 移除翻转逻辑（早于 start 的日子不再可点翻转）。

### multiAnchor 模式

- 未选 DDL：区间内全可选（含所有未来日）。
- 已选 DDL，未选 defense：
  - DDL 当天可点（取消 DDL 回未选）。
  - `day > DDL` 可选，选为 defense。
  - `day <= DDL` 且 `day != DDL` 置灰。
- 已选 DDL + defense：
  - DDL 当天可点（取消 DDL 并清 defense）。
  - defense 当天可点（取消 defense）。
  - 其余按"已选 DDL 未选 defense"规则。
- 移除"点早于 DDL 的日子重置 DDL"逻辑。

## 视觉样式

- 不可选日：文字色 `AppColors.inkFaint`（slate-500，`0xFF64748B`），无底色，`onTap=null`。
- 可选日：维持现状（`onSurface` 文字 / 选中 indigo 底白字 / span 内 indigoSoft 底）。
- 已选中态（selected / inSpan）渲染规则不变——这些日子必然可选，不会与置灰冲突。

## 测试

在 `test/features/preparation/widgets/preparation_date_picker_test.dart` 增补：

- range 模式选了 start=10 后，日期 5 的 `GestureDetector.onTap` 为 null（不可选）。
- multiAnchor 选了 DDL=20 后，日期 15 的 onTap 为 null，日期 20 的 onTap 非空（可取消）。
- 窗口外日子的 onTap 为 null。
- 既有 4 个测试仍绿。

## 不在范围内

- 表单页 `_validate` 的 `end < start` 校验文案保留（无害；置灰后该路径走不到，但作为防御保留）。
- 详情页内置 `showDatePicker` 不改。
