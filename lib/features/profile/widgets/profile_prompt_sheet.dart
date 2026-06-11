import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';

Future<bool?> showProfilePromptSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '完善档案，推荐更准',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '花 1 分钟填写你的成绩、竞赛、科研背景，让推荐结合你的真实情况。资料仅保存在本机。',
            style: TextStyle(color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('去完善'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('先跳过'),
          ),
        ],
      ),
    ),
  );
}
