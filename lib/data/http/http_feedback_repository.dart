import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/feedback_dto.dart';

/// 反馈提交 HTTP 实现:`POST /api/v1/feedback`。
///
/// 响应遵循项目统一信封 `{ code, message, data }`,复用 [guardApi]。
/// 失败一律返回 [Failure],由调用方决定提示文案。
class HttpFeedbackRepository implements FeedbackRepository {
  HttpFeedbackRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<void>> submit(Feedback feedback) {
    return guardApi<void>(
      () => _dio.post<dynamic>(
        '/api/v1/feedback',
        data: FeedbackDto.fromEntity(feedback).toJson(),
      ),
      (_) {},
    );
  }
}
