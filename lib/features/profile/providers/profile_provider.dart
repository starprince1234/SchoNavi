import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/api_error_reporter.dart';
import '../../../domain/entities/user_profile.dart';

/// 全局当前学生档案。向导/中心通过它编辑，推荐/套磁/匹配读它。
class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final repo = ref.read(profileRepositoryProvider);
    Future<void>.microtask(() async {
      try {
        final refreshed = await repo.refresh();
        if (ref.mounted) state = refreshed;
      } catch (error, stackTrace) {
        ref
            .read(apiErrorReporterProvider.notifier)
            .report('个人资料同步失败', error, stackTrace);
      }
    });
    return repo.load();
  }

  Future<void> refresh() async {
    state = await ref.read(profileRepositoryProvider).refresh();
  }

  Future<void> save(UserProfile profile) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.save(profile);
    state = repo.load();
  }
}

final profileProvider = NotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);
