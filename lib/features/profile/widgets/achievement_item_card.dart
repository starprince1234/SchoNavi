import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

class AchievementItemCard extends StatelessWidget {
  const AchievementItemCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onDelete,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoTile(
      onTap: onTap,
      color: scheme.surface,
      border: Border.all(color: scheme.outline),
      shadow: null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
	                    child: Text(
	                      subtitle!,
	                      style: TextStyle(
	                        fontSize: 12,
	                        color: scheme.onSurfaceVariant,
	                      ),
	                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: '删除',
            onPressed: () {
              Haptics.light();
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
