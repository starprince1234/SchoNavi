import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';

/// A reusable top AppBar for SchoNavi.
///
/// Shows the brand name "SchoNavi" on the top-left and a hamburger menu on the
/// top-right. The hamburger opens the [Scaffold]'s end drawer (the
/// comprehensive menu like ChatGPT).
class SchoNaviAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SchoNaviAppBar({
    super.key,
    this.backgroundColor,
  });

  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final appBarTheme = Theme.of(context).appBarTheme;

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Text(
        'SchoNavi',
        style: appBarTheme.titleTextStyle?.copyWith(
              color: AppColors.coral,
            ),
      ),
      actions: const [
        _AppMenuButton(),
      ],
    );
  }
}

class _AppMenuButton extends StatelessWidget {
  const _AppMenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '菜单',
      icon: const Icon(Icons.menu_outlined),
      onPressed: () {
        Haptics.light();
        Scaffold.of(context).openEndDrawer();
      },
    );
  }
}
