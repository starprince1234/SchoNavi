import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

class ProfileSectionTile extends StatelessWidget {
  const ProfileSectionTile({
    super.key,
    required this.title,
    required this.summary,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String summary;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoTile(
        onTap: onTap,
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        shadow: null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            Text(
              summary,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(width: 6),
            done
                ? const Icon(Icons.check_circle, size: 18, color: AppColors.match)
                : const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
