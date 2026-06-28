// lib/domain/repositories/preparation_template_provider.dart
import '../entities/preparation_template.dart';

/// 模板来源抽象：v1 仅 Local 实现可用，远程（D6）留空未实现。
abstract interface class PreparationTemplateProvider {
  /// 按 [category]（赛类）与 [competitionId]（赛事）加载合并后的备考模板。
  Future<PreparationTemplate> load({String? category, String? competitionId});
}
