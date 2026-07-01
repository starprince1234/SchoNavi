import 'preparation_plan.dart';

/// 水平档位选择来源：AI 判断被用户接受 / 用户手动覆盖。
enum DiagnosisSelectionSource { aiAccepted, manualOverride }

/// 某竞赛类目的水平诊断画像（spec §2.5）。
///
/// 一次 AI 水平诊断的结果快照，按规范化类目 key 存储，供备赛计划生成时引用。
class LevelDiagnosis {
  const LevelDiagnosis({
    required this.categoryKey,
    required this.diagnosedLevel,
    required this.effectiveLevel,
    required this.source,
    required this.rationale,
    this.suggestion,
    required this.diagnosedAt,
    required this.answers,
  });

  /// 规范化类目 key（由 CompetitionCategoryNormalizer 产出）。
  final String categoryKey;

  /// AI 原始判断档位。
  final ExperienceLevel diagnosedLevel;

  /// 用户最终确认的档位。
  final ExperienceLevel effectiveLevel;

  final DiagnosisSelectionSource source;

  final String rationale;
  final String? suggestion;

  /// 审计时间（UTC RFC 3339 date-time）。
  final DateTime diagnosedAt;

  /// 2 问答答案快照。
  final Map<String, String> answers;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'categoryKey': categoryKey,
    'diagnosedLevel': diagnosedLevel.name,
    'effectiveLevel': effectiveLevel.name,
    'source': source.name,
    'rationale': rationale,
    'suggestion': suggestion,
    'diagnosedAt': diagnosedAt.toIso8601String(),
    'answers': answers,
  };

  static LevelDiagnosis? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    try {
      final diagnosed = ExperienceLevel.values.byName(
        map['diagnosedLevel'] as String? ?? '',
      );
      final effective = ExperienceLevel.values.byName(
        map['effectiveLevel'] as String? ?? '',
      );
      final source = DiagnosisSelectionSource.values.byName(
        map['source'] as String? ?? '',
      );
      final rawAnswers = map['answers'];
      final answers = <String, String>{};
      if (rawAnswers is Map) {
        rawAnswers.forEach((k, v) => answers[k.toString()] = v.toString());
      }
      return LevelDiagnosis(
        categoryKey: map['categoryKey'] as String? ?? '',
        diagnosedLevel: diagnosed,
        effectiveLevel: effective,
        source: source,
        rationale: map['rationale'] as String? ?? '',
        suggestion: map['suggestion'] as String?,
        diagnosedAt:
            DateTime.tryParse(map['diagnosedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        answers: answers,
      );
    } catch (_) {
      return null;
    }
  }
}
