import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/pages/chat_page.dart';
import '../../features/compare/pages/compare_page.dart';
import '../../features/email/pages/email_page.dart';
import '../../features/favorite/pages/favorite_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/match/pages/match_page.dart';
import '../../features/professor/pages/professor_page.dart';
import '../../features/recommendation/pages/recommendation_page.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../motion/page_transition.dart';

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
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: RecommendationPage(
            prompt: state.uri.queryParameters['q'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/professor/:id',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ProfessorPage(professorId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ChatPage(
            sessionId: state.uri.queryParameters['sid'] ?? '',
            professorId: state.uri.queryParameters['pid'],
          ),
        ),
      ),
      GoRoute(
        path: '/email',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: EmailPage(professorId: state.uri.queryParameters['pid'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/compare',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ComparePage(
            ids: (state.uri.queryParameters['ids'] ?? '')
                .split(',')
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList(),
          ),
        ),
      ),
      GoRoute(
        path: '/match',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: MatchPage(professorId: state.uri.queryParameters['pid'] ?? ''),
        ),
      ),
    ],
  );
});
