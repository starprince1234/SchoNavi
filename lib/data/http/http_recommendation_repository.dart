import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/profile_dtos.dart';
import '../dto/recommendation_dtos.dart';

class HttpRecommendationRepository implements RecommendationRepository {
  const HttpRecommendationRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/recommendations/mentors',
        data: <String, dynamic>{
          'prompt': prompt,
          'session_id': ?sessionId,
          if (profile != null && !profile.isEmpty)
            'profile': UserProfileDto.fromEntity(profile).toJson(),
        },
      ),
      (data) => RecommendationResultDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
