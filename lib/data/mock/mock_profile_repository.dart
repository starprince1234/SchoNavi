import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// 内存学生档案仓储，模拟后端档案接口。
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository();

  UserProfile _profile = const UserProfile();

  @override
  UserProfile load() => _profile;

  @override
  Future<UserProfile> refresh() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _profile = profile;
  }

  @override
  Future<void> clear() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _profile = const UserProfile();
  }
}
