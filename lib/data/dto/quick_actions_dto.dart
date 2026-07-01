import 'route_need_dto.dart';

/// 请求体：`{"follow_up": "...", "last_recommendations": [...]}`。
///
/// `follow_up` 缺省/空字符串表示会话开始，后端按通用 chip 语义返回。
/// `last_recommendations` 首轮省略，后续轮由调用方 cap 到 5 条——
/// 复用 [RecommendationRecapDto]，与 `/chat/route` 同款摘要，避免端点间 DTO 重复。
class QuickActionsRequestDto {
  const QuickActionsRequestDto({
    required this.followUp,
    this.lastRecommendations,
  });

  final String followUp;
  final List<RecommendationRecapDto>? lastRecommendations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'follow_up': followUp,
    if (lastRecommendations != null)
      'last_recommendations': [
        for (final r in lastRecommendations!) r.toJson(),
      ],
  };
}

/// 响应 data：`{"quick_actions": ["换一批","偏应用",...]}`。
///
/// `quick_actions` 缺省/类型错误 → 视为空 `[]`（由 [fromJson] 兜底），不报错——
/// 对齐「后端返回空则不显示」。
class QuickActionsResponseDto {
  const QuickActionsResponseDto({required this.quickActions});

  final List<String> quickActions;

  factory QuickActionsResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['quick_actions'];
    return QuickActionsResponseDto(
      quickActions: list is List
          ? list
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}
