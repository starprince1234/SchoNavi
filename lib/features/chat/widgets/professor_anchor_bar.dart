import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/fork_ref.dart';

/// fork 追问页顶部常驻的教授锚点条（方案 A，sticky）。
///
/// 仅在 [ChatState.forkAnchor] 非 null 时渲染。点击回详情页。
class ProfessorAnchorBar extends StatelessWidget {
  const ProfessorAnchorBar({
    super.key,
    required this.anchor,
    required this.onTap,
  });

  final ForkRef anchor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle =
        anchor.college == null || anchor.college!.isEmpty
            ? anchor.university
            : '${anchor.university} · ${anchor.college}';
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.indigo,
                child: Text(
                  anchor.avatarLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${anchor.professorName} 教授',
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '追问中',
                  style: textTheme.labelSmall?.copyWith(color: AppColors.indigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
