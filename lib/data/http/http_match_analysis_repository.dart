import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/match_analysis.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/match_analysis_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/match_analysis_dto.dart';
import '../dto/profile_dtos.dart';

class HttpMatchAnalysisRepository implements MatchAnalysisRepository {
  const HttpMatchAnalysisRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/professors/${professor.id}/match-analysis',
        data: <String, dynamic>{
          'profile': UserProfileDto.fromEntity(profile).toJson(),
        },
      ),
      (data) => MatchAnalysisDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}

