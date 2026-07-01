import '../../core/storage/local_store.dart';
import '../../domain/entities/academic_score.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// 经 [LocalStore] 以单个 JSON 对象存取学生背景（加性扩展，旧 JSON 兼容）。
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store);

  static const String storageKey = 'user_profile.v1';

  final LocalStore _store;

  @override
  UserProfile load() {
    final json = _store.getJson(storageKey);
    if (json == null) return const UserProfile();
    final scoreJson = json['score'];
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
      gender: _genderFrom(json['gender'] as String?),
      targetDegree: _str(json['target_degree']),
      score: scoreJson is Map<String, dynamic>
          ? AcademicScore.fromJson(scoreJson)
          : null,
      competitions: _list(json['competitions'], Competition.fromJson),
      research: _list(json['research'], ResearchItem.fromJson),
    );
  }

  @override
  Future<UserProfile> refresh() async => load();

  @override
  Future<void> save(UserProfile profile) => _store.setJson(storageKey, {
    if (profile.name != null) 'name': profile.name,
    if (profile.degreeStage != null) 'degree_stage': profile.degreeStage,
    if (profile.school != null) 'school': profile.school,
    if (profile.major != null) 'major': profile.major,
    'research_interests': profile.researchInterests,
    if (profile.highlights != null) 'highlights': profile.highlights,
    if (profile.gender != null) 'gender': profile.gender!.name,
    if (profile.targetDegree != null) 'target_degree': profile.targetDegree,
    if (profile.score != null && !profile.score!.isEmpty)
      'score': profile.score!.toJson(),
    if (profile.competitions.isNotEmpty)
      'competitions': [for (final c in profile.competitions) c.toJson()],
    if (profile.research.isNotEmpty)
      'research': [for (final r in profile.research) r.toJson()],
  });

  @override
  Future<void> clear() => _store.remove(storageKey);

  String? _str(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  Gender? _genderFrom(String? raw) {
    for (final g in Gender.values) {
      if (g.name == raw) return g;
    }
    return null;
  }

  List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) from) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(from)
          .toList();
}
