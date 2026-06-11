import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/providers/profile_provider.dart';

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo([this._stored = const UserProfile()]);

  UserProfile _stored;

  @override
  UserProfile load() => _stored;

  @override
  Future<void> save(UserProfile profile) async => _stored = profile;
}

void main() {
  test('build 从仓储读初值', () {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(const UserProfile(name: '张三')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(profileProvider).name, '张三');
  });

  test('save 更新 state 并落盘', () async {
    final fake = _FakeProfileRepo();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container
        .read(profileProvider.notifier)
        .save(const UserProfile(name: '李四'));

    expect(container.read(profileProvider).name, '李四');
    expect(fake.load().name, '李四');
  });
}
