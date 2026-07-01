import '../../core/result/result.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/repositories/profile_extraction_repository.dart';

/// 轻量文本抽取 Mock：根据关键词返回示例成果草稿。
class MockProfileExtractionRepository implements ProfileExtractionRepository {
  const MockProfileExtractionRepository();

  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final text = rawText.toLowerCase();
    final competitions = <Competition>[];
    final research = <ResearchItem>[];

    if (text.contains('数学建模') || text.contains('建模')) {
      competitions.add(
        const Competition(
          name: '全国大学生数学建模竞赛',
          level: '国家级',
          award: '省一等奖',
          year: '2024',
        ),
      );
    }

    if (text.contains('acm') || text.contains('程序设计') || text.contains('竞赛')) {
      competitions.add(
        const Competition(
          name: 'ACM-ICPC 区域赛',
          level: '国际',
          award: '银牌',
          year: '2024',
        ),
      );
    }

    if (text.contains('论文') || text.contains('paper')) {
      research.add(
        const ResearchItem(
          type: ResearchType.paper,
          title: '基于深度学习的医学影像分割方法研究',
          role: '第一作者',
          venueOrStatus: 'EI 会议 / 已发表',
          year: '2024',
        ),
      );
    }

    if (text.contains('专利')) {
      research.add(
        const ResearchItem(
          type: ResearchType.patent,
          title: '一种图像增强处理方法及系统',
          role: '发明人',
          venueOrStatus: '已公开',
          year: '2024',
        ),
      );
    }

    if (text.contains('科研项目') || text.contains('项目') || text.contains('科研')) {
      research.add(
        const ResearchItem(
          type: ResearchType.project,
          title: '国家级大学生创新创业训练计划项目',
          role: '项目负责人',
          venueOrStatus: '已结题',
          year: '2023',
        ),
      );
    }

    return Success(
      AchievementDraft(competitions: competitions, research: research),
    );
  }
}
