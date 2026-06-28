// lib/data/local/local_preparation_template_provider.dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/preparation_template.dart';
import '../../domain/repositories/preparation_template_provider.dart';
import '../fixtures/preparation_templates.dart';

/// 本地备考模板提供者：
/// 以 [defaultPreparationTemplate] 为基础，
/// 叠加 `category_templates.json`（按赛类）与 `competition_overrides.json`（按赛事）。
///
/// 合并规则：JSON 阶段按 `key` 匹配基础阶段，其 `required_tasks` / `optional_tasks`
/// **追加**到对应阶段列表（按 `templateKey` 去重）。未知阶段键丢弃。
///
/// 任意一层 JSON 加载/解析失败 → 仅降级为已合并的部分（最坏退回纯 Dart 默认），不抛错。
class LocalPreparationTemplateProvider implements PreparationTemplateProvider {
  LocalPreparationTemplateProvider({required this.bundle});

  final AssetBundle bundle;

  static const String _categoryPath =
      'assets/preparation_templates/category_templates.json';
  static const String _competitionPath =
      'assets/preparation_templates/competition_overrides.json';

  @override
  Future<PreparationTemplate> load({
    String? category,
    String? competitionId,
  }) async {
    final base = defaultPreparationTemplate();

    // 以 Dart 默认为基础，复制各阶段任务列表（后续只追加、去重）。
    final byKey = <String, PreparationTemplatePhase>{
      for (final p in base.phases) p.key: p,
    };
    final mergedRequired = <String, List<PreparationTemplateTask>>{
      for (final p in base.phases) p.key: [...p.requiredTasks],
    };
    final mergedOptional = <String, List<PreparationTemplateTask>>{
      for (final p in base.phases) p.key: [...p.optionalTasks],
    };

    // 将已解码 JSON 根中指定 entryKey 的赛类/赛事条目合并进阶段任务表。
    void applyEntry(Map<String, dynamic> root, String entryKey) {
      final entry = root[entryKey];
      if (entry is! Map<String, dynamic>) return;
      final phases = (entry['phases'] as List?) ?? const [];
      for (final phase in phases) {
        if (phase is! Map<String, dynamic>) continue;
        final key = phase['key'];
        if (key is! String || !byKey.containsKey(key)) continue; // 未知阶段丢弃
        for (final t in (phase['required_tasks'] as List?) ?? const []) {
          if (t is! Map<String, dynamic>) continue;
          final task = PreparationTemplateTask.fromJson(t);
          if (!mergedRequired[key]!.any((x) => x.templateKey == task.templateKey)) {
            mergedRequired[key]!.add(task);
          }
        }
        for (final t in (phase['optional_tasks'] as List?) ?? const []) {
          if (t is! Map<String, dynamic>) continue;
          final task = PreparationTemplateTask.fromJson(t);
          if (!mergedOptional[key]!.any((x) => x.templateKey == task.templateKey)) {
            mergedOptional[key]!.add(task);
          }
        }
      }
    }

    // 赛类叠加（独立 try/catch，失败降级）。
    if (category != null) {
      try {
        final root =
            jsonDecode(await bundle.loadString(_categoryPath)) as Map<String, dynamic>;
        applyEntry(root, category);
      } catch (_) {
        // 降级：忽略赛类 JSON
      }
    }

    // 赛事覆盖叠加（独立 try/catch，失败降级）。
    if (competitionId != null) {
      try {
        final root = jsonDecode(await bundle.loadString(_competitionPath))
            as Map<String, dynamic>;
        applyEntry(root, competitionId);
      } catch (_) {
        // 降级：忽略赛事 JSON
      }
    }

    return PreparationTemplate(
      phases: base.phases
          .map((p) => PreparationTemplatePhase(
                key: p.key,
                title: p.title,
                weight: p.weight,
                requiredTasks: mergedRequired[p.key]!,
                optionalTasks: mergedOptional[p.key]!,
              ))
          .toList(),
    );
  }
}
