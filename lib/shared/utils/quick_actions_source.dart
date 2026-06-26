import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';

/// 快捷操作（输入框上方 chip）的后端来源。
///
/// 返回 [Result] 以区分「失败」与「成功但空」——失败由调用方降级到硬编码
/// 兜底常量，成功空则不显示 chip（对齐 spec 降级规则：宁可少 chip，
/// 不阻断对话）。语义对称 [RecommendationNeedClassifier]，但后者在实现
/// 内部塌缩为 bool，这里把「失败 vs 空」的区分交回调用方。
abstract interface class QuickActionsSource {
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  });
}
