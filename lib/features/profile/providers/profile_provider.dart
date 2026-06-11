import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/user_profile.dart';

/// 全局当前学生档案。向导/中心通过它编辑，推荐/套磁/匹配读它。
class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.read(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(profileRepositoryProvider).save(profile);
  }
}

final profileProvider = NotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);
