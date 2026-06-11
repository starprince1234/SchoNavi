import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/haptics.dart';

class ScaffoldWithBottomNav extends StatefulWidget {
  const ScaffoldWithBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithBottomNav> createState() => _ScaffoldWithBottomNavState();
}

class _ScaffoldWithBottomNavState extends State<ScaffoldWithBottomNav> {
  final Map<int, bool> _scaling = {0: false, 1: false, 2: false};

  void _onTabSelected(int index) {
    Haptics.selection();
    setState(() => _scaling[index] = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _scaling[index] = false);
    });
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: AnimatedScale(
              scale: _scaling[0]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.search_outlined),
            ),
            selectedIcon: AnimatedScale(
              scale: _scaling[0]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.search),
            ),
            label: '首页',
          ),
          NavigationDestination(
            icon: AnimatedScale(
              scale: _scaling[1]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.bookmark_border),
            ),
            selectedIcon: AnimatedScale(
              scale: _scaling[1]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.bookmark),
            ),
            label: '收藏',
          ),
          NavigationDestination(
            icon: AnimatedScale(
              scale: _scaling[2]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.history),
            ),
            selectedIcon: AnimatedScale(
              scale: _scaling[2]! ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.history),
            ),
            label: '历史',
          ),
        ],
      ),
    );
  }
}
