import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorite/pages/favorite_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/professor/pages/professor_page.dart';
import '../../features/recommendation/pages/recommendation_page.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            ScaffoldWithBottomNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (_, _) => const FavoritePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/recommendation',
        builder: (_, state) =>
            RecommendationPage(prompt: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/professor/:id',
        builder: (_, state) =>
            ProfessorPage(professorId: state.pathParameters['id']!),
      ),
    ],
  );
});
