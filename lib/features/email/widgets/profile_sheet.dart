import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';

/// 弹出背景填写底部 sheet；保存返回 [UserProfile]，取消返回 null。
Future<UserProfile?> showProfileSheet(
  BuildContext context,
  UserProfile initial,
) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ProfileSheet(initial: initial),
    ),
  );
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.initial});

  final UserProfile initial;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name ?? '',
  );
  late final TextEditingController _degree = TextEditingController(
    text: widget.initial.degreeStage ?? '',
  );
  late final TextEditingController _school = TextEditingController(
    text: widget.initial.school ?? '',
  );
  late final TextEditingController _major = TextEditingController(
    text: widget.initial.major ?? '',
  );
  late final TextEditingController _interests = TextEditingController(
    text: widget.initial.researchInterests.join('、'),
  );
  late final TextEditingController _highlights = TextEditingController(
    text: widget.initial.highlights ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _degree.dispose();
    _school.dispose();
    _major.dispose();
    _interests.dispose();
    _highlights.dispose();
    super.dispose();
  }

  void _save() {
    final interests = _interests.text
        .split(RegExp(r'[，,、\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      UserProfile(
        name: _trimOrNull(_name.text),
        degreeStage: _trimOrNull(_degree.text),
        school: _trimOrNull(_school.text),
        major: _trimOrNull(_major.text),
        researchInterests: interests,
        highlights: _trimOrNull(_highlights.text),
      ),
    );
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('完善个人背景', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('用于生成更贴合你的套磁邮件，仅保存在本机。'),
          const SizedBox(height: 12),
          _field(_name, '称呼 / 姓名', 'profile-name'),
          _field(_degree, '当前阶段（如 本科在读 / 硕士在读）', 'profile-degree'),
          _field(_school, '现就读学校', 'profile-school'),
          _field(_major, '专业', 'profile-major'),
          _field(_interests, '研究兴趣（顿号或逗号分隔）', 'profile-interests'),
          _field(
            _highlights,
            '自述：成果 / 项目 / 绩点等',
            'profile-highlights',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: Key(key),
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}
