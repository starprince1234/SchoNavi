import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/email_draft.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/outreach_email_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/email_draft_dto.dart';
import '../dto/profile_dtos.dart';

class HttpOutreachEmailRepository implements OutreachEmailRepository {
  const HttpOutreachEmailRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/professors/${professor.id}/outreach-email',
        data: <String, dynamic>{
          'profile': UserProfileDto.fromEntity(profile).toJson(),
        },
      ),
      (data) => EmailDraftDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
