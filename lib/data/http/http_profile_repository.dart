import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/profile_dtos.dart';

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._dio);

  final Dio _dio;
  UserProfile _snapshot = const UserProfile();

  @override
  UserProfile load() {
    _refresh();
    return _snapshot;
  }

  @override
  Future<void> save(UserProfile profile) async {
    final saved = await guardApi(
      () => _dio.put<dynamic>(
        '/api/v1/profile',
        data: UserProfileDto.fromEntity(profile).toJson(),
      ),
      (data) => UserProfileDto.fromJson(asJsonObject(data)).toEntity(),
    );
    if (saved is Success<UserProfile>) {
      _snapshot = saved.data;
    } else {
      _snapshot = profile;
    }
  }

  @override
  Future<void> clear() async {
    await guardApi(
      () => _dio.delete<dynamic>('/api/v1/profile'),
      (_) => true,
    );
    _snapshot = const UserProfile();
  }

  Future<void> _refresh() async {
    final result = await guardApi(
      () => _dio.get<dynamic>('/api/v1/profile'),
      (data) => UserProfileDto.fromJson(asJsonObject(data)).toEntity(),
    );
    if (result is Success<UserProfile>) _snapshot = result.data;
  }
}
