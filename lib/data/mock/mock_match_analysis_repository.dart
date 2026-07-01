import '../../core/result/result.dart';
import '../../domain/entities/match_analysis.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/match_analysis_repository.dart';

/// 离线兜底：模板拼装匹配分析，不调用大模型。
class MockMatchAnalysisRepository implements MatchAnalysisRepository {
  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final fields = professor.researchFields.isEmpty
        ? '该导师研究方向'
        : professor.researchFields.join('、');
    final overlap = profile.researchInterests
        .where(professor.researchFields.contains)
        .toList();

    final strengths = <String>[
      if (overlap.isNotEmpty)
        '你的研究兴趣与 ${overlap.join('、')} 有直接重合。'
      else if (profile.researchInterests.isNotEmpty)
        '你已明确研究兴趣，可进一步对照 ${professor.name}${professor.title} 的 $fields 梳理关联。'
      else
        '已选定具体导师，可围绕 $fields 快速建立准备清单。',
      if (profile.major != null) '你的 ${profile.major} 背景可作为理解相关研究问题的基础。',
    ];

    final gaps = <String>[
      if (profile.isEmpty)
        '当前学生背景为空，建议补充当前阶段、专业、研究兴趣和代表性经历。'
      else
        '建议继续补充能证明你适合 $fields 的项目、论文、课程或竞赛经历。',
      '导师招生要求、名额和近期课题仍需以学院官网或导师回复为准。',
    ];

    final suggestions = <String>[
      '阅读 ${professor.name}${professor.title} 近年与 $fields 相关的论文或项目介绍。',
      '准备一段 3-5 句话的背景说明，突出与导师方向最相关的经历。',
      '整理可发送给导师的材料清单，包括简历、成绩单和项目说明。',
    ];

    final hasOverlap = overlap.isNotEmpty;
    final dimensions = <MatchDimension>[
      MatchDimension(
        label: '方向契合',
        score: hasOverlap ? 88 : 62,
        comment: hasOverlap
            ? '你的兴趣与 ${overlap.join('、')} 直接重合。'
            : '与 $fields 有一定关联，建议进一步对照。',
      ),
      MatchDimension(
        label: '方法匹配',
        score: profile.major != null ? 74 : 60,
        comment: profile.major != null
            ? '你的 ${profile.major} 背景可支撑相关方法。'
            : '方法匹配度需结合你的具体技能判断。',
      ),
      const MatchDimension(label: '地域', score: 70, comment: '地域偏好需结合你的意向城市确认。'),
      MatchDimension(
        label: '学历目标',
        score: profile.degreeStage != null ? 72 : 58,
        comment: profile.degreeStage != null
            ? '你的目标阶段（${profile.degreeStage}）可与导师招生匹配。'
            : '建议补充目标阶段（硕/博）以评估。',
      ),
      const MatchDimension(
        label: '产出活跃',
        score: 68,
        comment: '导师近年产出与名额请以官网/回复为准。',
      ),
    ];

    return Success(
      MatchAnalysis(
        professorId: professor.id,
        summary: '这是一份基于已提供信息的 $fields 匹配分析，仅供准备沟通时参考。',
        strengths: strengths,
        gaps: gaps,
        suggestions: suggestions,
        dimensions: dimensions,
      ),
    );
  }
}
