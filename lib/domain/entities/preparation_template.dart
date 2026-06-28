// lib/domain/entities/preparation_template.dart
class PreparationTemplateTask {
  const PreparationTemplateTask({required this.templateKey, required this.title, required this.estimatedHours});
  final String templateKey;
  final String title;
  final double estimatedHours;
  factory PreparationTemplateTask.fromJson(Map<String, dynamic> j) =>
      PreparationTemplateTask(
        templateKey: j['template_key'] as String,
        title: j['title'] as String,
        estimatedHours: (j['estimated_hours'] as num).toDouble(),
      );
}

class PreparationTemplatePhase {
  const PreparationTemplatePhase({
    required this.key, required this.title, required this.weight,
    required this.requiredTasks, required this.optionalTasks,
  });
  final String key;
  final String title;
  final double weight; // 建议时长占比
  final List<PreparationTemplateTask> requiredTasks;
  final List<PreparationTemplateTask> optionalTasks;
  factory PreparationTemplatePhase.fromJson(Map<String, dynamic> j) =>
      PreparationTemplatePhase(
        key: j['key'] as String,
        title: j['title'] as String,
        weight: (j['weight'] as num).toDouble(),
        requiredTasks: (j['required_tasks'] as List).map((e) =>
            PreparationTemplateTask.fromJson(e as Map<String, dynamic>)).toList(),
        optionalTasks: ((j['optional_tasks'] as List?) ?? const [])
            .map((e) => PreparationTemplateTask.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class PreparationTemplate {
  const PreparationTemplate({required this.phases});
  final List<PreparationTemplatePhase> phases;
}
