import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.value,
    this.size = 56,
    this.ringColor = AppColors.cyanBright,
    this.trackColor = const Color(0x33FFFFFF),
    this.textColor = AppColors.cyanBright,
  });

  final double value;
  final double size;
  final Color ringColor;
  final Color trackColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Text(
              '${(v * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
