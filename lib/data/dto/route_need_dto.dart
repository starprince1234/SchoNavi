import '../../domain/entities/recommendation.dart';
import 'api_envelope.dart';

/// 追问路由端点 `/chat/route` 上链的「上一轮推荐紧凑摘要」。
///
/// 只携带路由所需的最少字段（id / 姓名 / 学校 / 方向），刻意不复用
/// [RecommendationDto]——避免追问路由端点与完整推荐形状过度耦合。
/// 首轮无推荐时由调用方省略该字段。
class RecommendationRecapDto {
  const RecommendationRecapDto({
    required this.professorId,
    required this.name,
    required this.university,
    required this.researchFields,
  });

  final String professorId;
  final String name;
  final String university;
  final List<String> researchFields;

  factory RecommendationRecapDto.fromEntity(Recommendation r) {
    return RecommendationRecapDto(
      professorId: r.professorId,
      name: r.name,
      university: r.university,
      researchFields: r.researchFields,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'professor_id': professorId,
    'name': name,
    'university': university,
    'research_fields': researchFields,
  };
}

/// 追问路由响应的 `data` 部分：`{"need": true|false}`。
///
/// 薄类型化 DTO，让 [guardApi] 的 decode 返回 typed 对象（对齐
/// `RecommendationResultDto` 约定）。`need` 仅在显式为 `true` 时为真，
/// 缺省/类型错误由 [decodeEnvelope] 抛 [ServerException] 兜底。
class RouteNeedResponseDto {
  const RouteNeedResponseDto({required this.need});

  final bool need;

  factory RouteNeedResponseDto.fromJson(Map<String, dynamic> json) {
    return RouteNeedResponseDto(need: json['need'] == true);
  }
}
