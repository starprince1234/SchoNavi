import '../../core/storage/local_store.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// 经 [LocalStore] 以单个 JSON 对象存取学生背景。
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store);

  static const String storageKey = 'user_profile.v1';

  final LocalStore _store;

  @override
  UserProfile load() {
    final json = _store.getJson(storageKey);
    if (json == null) return const UserProfile();
    return UserProfile(
      name: _str(json['name']),
      degreeStage: _str(json['degree_stage']),
      school: _str(json['school']),
      major: _str(json['major']),
      researchInterests:
          (json['research_interests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      highlights: _str(json['highlights']),
    );
  }

  @override
  Future<void> save(UserProfile profile) => _store.setJson(storageKey, {
    if (profile.name != null) 'name': profile.name,
    if (profile.degreeStage != null) 'degree_stage': profile.degreeStage,
    if (profile.school != null) 'school': profile.school,
    if (profile.major != null) 'major': profile.major,
    'research_interests': profile.researchInterests,
    if (profile.highlights != null) 'highlights': profile.highlights,
  });

  String? _str(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
