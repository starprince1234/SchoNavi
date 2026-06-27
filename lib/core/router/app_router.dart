import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/pages/chat_page.dart';
import '../../features/compare/pages/compare_page.dart';
import '../../features/competition_recommendation/pages/competition_recommendation_page.dart';
import '../../features/email/pages/email_page.dart';
import '../../features/favorite/pages/favorite_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/match/pages/match_page.dart';
import '../../features/onboarding/pages/onboarding_page.dart';
import '../../features/professor/pages/professor_page.dart';
import '../../features/recommendation/pages/recommendation_page.dart';
import '../../features/profile/pages/privacy_agreement_page.dart';
import '../../features/profile/pages/profile_intro_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/profile_wizard_page.dart';
import '../../features/splash/pages/splash_page.dart';
import '../../features/settings/pages/settings_page.dart';

import '../di/providers.dart';
import '../motion/page_transition.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // splash 豁免：动画页不参与 onboarding 重定向，否则未读引导用户会被
      // 直接跳走、动画无法播放。
      if (state.matchedLocation == '/splash') return null;
      final seen =
          ref.read(localStoreProvider).getBool(OnboardingPage.seenKey) ?? false;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!seen && !atOnboarding) return '/onboarding';
      if (seen && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const ProfilePage()),
      ),
      GoRoute(
        path: '/favorites',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const FavoritePage()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const HistoryPage()),
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
        path: '/competition-recommendation',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: CompetitionRecommendationPage(
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
            sessionId: state.uri.queryParameters['sid'],
            professorId: state.uri.queryParameters['pid'],
            initialPrompt: state.uri.queryParameters['q'],
            forkMode: state.uri.queryParameters['fork'] == 'true',
            mainSessionId: state.uri.queryParameters['msid'],
            forkId: state.uri.queryParameters['fid'],
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
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/profile/privacy',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const PrivacyAgreementPage()),
      ),
      GoRoute(
        path: '/profile/intro',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const ProfileIntroPage()),
      ),
      GoRoute(
        path: '/profile/wizard',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const ProfileWizardPage()),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
    ],
  );
});
