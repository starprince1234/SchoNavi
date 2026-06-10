import '../entities/user_profile.dart';

/// 本地学生背景存取。
abstract interface class ProfileRepository {
  UserProfile load();
  Future<void> save(UserProfile profile);
}
