import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/completion_ring.dart';

class ProfileSummaryHeader extends StatelessWidget {
  const ProfileSummaryHeader({
    super.key,
    required this.profile,
    required this.onUseForReco,
  });

  final UserProfile profile;
  final VoidCallback onUseForReco;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 冷调深色 hero：slate-900 → indigo 深渐变，承载 cyan 完成度环。
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [AppColors.shadowGlow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompletionRing(value: profile.completion),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '档案完成度',
                      style: TextStyle(color: AppColors.inkDark, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '越完整 · 推荐越准',
                      style: TextStyle(
                        color: AppColors.cyanBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onUseForReco,
              child: const Text('用我的档案推荐'),
            ),
          ),
        ],
      ),
    );
  }
}
