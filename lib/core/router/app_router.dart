import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/pages/home_page.dart';
import '../../features/professor/pages/professor_page.dart';
import '../../features/recommendation/pages/recommendation_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
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
