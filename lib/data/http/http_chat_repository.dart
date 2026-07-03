import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/error_diagnostics.dart';
import '../../core/ids/uuid_v7.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/entities/fork_ref.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/chat_repository.dart';
import 'api_request_id_interceptor.dart';
import '../dto/api_envelope.dart';
import '../dto/chat_dto.dart';
import '../dto/chat_message_dto.dart';

class HttpChatRepository implements ChatRepository {
  HttpChatRepository(this._dio, {UuidV7? ids}) : _ids = ids ?? UuidV7();

  final Dio _dio;
  final UuidV7 _ids;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/chat/messages',
        data: <String, dynamic>{
          'session_id': sessionId,
          'message': message,
          'professor_id': ?professorId,
        },
      ),
      (data) => ChatMessageResponseDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }

  @override
  Future<void> seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) async {
    // HTTP 透传后端：上下文由后端会话维护，客户端无需本地注入。
  }

  @override
  Future<void> persistMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    // HTTP 透传后端：可见历史由后端会话维护，客户端无需本地持久化。
    // 未来对接可走 POST /api/v1/chat/sessions/{id}/messages。
  }

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) async* {
    const path = '/api/v1/chat/stream';
    final requestId = _ids.generate();
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        queryParameters: <String, dynamic>{
          'session_id': sessionId,
          'message': message,
          'professor_id': ?professorId,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {apiRequestIdHeader: requestId},
        ),
      );
      final resolvedRequestId =
          response.headers.value('x-request-id') ?? requestId;
      final body = response.data;
      if (body == null) {
        throw ServerException(
          diagnostics: _streamDiagnostics(
            requestId: resolvedRequestId,
            path: path,
            exceptionType: 'EmptyStreamResponse',
            cause: '响应流为空',
          ),
        );
      }

      var event = 'message';
      final dataLines = <String>[];
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.startsWith('event:')) {
          event = line.substring('event:'.length).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring('data:'.length).trimLeft());
          continue;
        }
        if (line.isEmpty && dataLines.isNotEmpty) {
          final rawData = dataLines.join('\n');
          final payload = jsonDecode(rawData);
          dataLines.clear();
          if (payload is! Map) {
            throw const FormatException('SSE data is not a JSON object');
          }
          final json = Map<String, dynamic>.from(payload);
          switch (event) {
            case 'delta':
              yield json['text']?.toString() ?? '';
              break;
            case 'error':
              throw ValidationException(
                json['message']?.toString() ?? '服务异常，请稍后重试',
                diagnostics: _streamDiagnostics(
                  requestId: resolvedRequestId,
                  path: path,
                  backendCode: json['code']?.toString(),
                  backendMessage: json['message']?.toString(),
                  exceptionType: 'ChatStreamException',
                  responsePreview: sanitizedResponsePreview(json),
                ),
              );
            case 'done':
            case 'related_recommendations':
            default:
              break;
          }
          event = 'message';
        }
      }
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException catch (error) {
      throw ValidationException(
        '服务返回格式异常：${error.message.isEmpty ? 'SSE 数据解析失败' : error.message}',
        diagnostics: _streamDiagnostics(
          requestId: requestId,
          path: path,
          exceptionType: error.runtimeType.toString(),
          cause: error.message,
        ),
      );
    } catch (error, stackTrace) {
      throw normalizeAppException(error, stackTrace).withDiagnostics(
        ErrorDiagnostics(
          requestId: requestId,
          method: 'GET',
          path: path,
          occurredAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) => guardApi(() async {
    final source = await _dio.get<dynamic>(
      '/api/v1/chat/sessions/$sourceSessionId',
    );
    final aggregate = asJsonObject(decodeEnvelope(source.data, (data) => data));
    String? sourceTurnId;
    final messages = aggregate['messages'] as List<dynamic>? ?? const [];
    for (final raw in messages.reversed) {
      if (raw is! Map) continue;
      final message = Map<String, dynamic>.from(raw);
      final recommendations =
          message['related_recommendations'] as List<dynamic>? ?? const [];
      if (recommendations.whereType<Map>().any(
        (item) => item['professor_id']?.toString() == professorId,
      )) {
        sourceTurnId = message['turn_id']?.toString();
        break;
      }
    }
    if (sourceTurnId == null || sourceTurnId.isEmpty) {
      throw const ValidationException('所选导师不属于可追问的推荐轮次');
    }
    return _dio.post<dynamic>(
      '/api/v1/chat/sessions/$sourceSessionId/forks',
      data: {'source_turn_id': sourceTurnId, 'professor_id': professorId},
    );
  }, (data) => asJsonObject(data)['id']?.toString() ?? '');

  @override
  Future<Result<List<ChatMessage>>> loadHistory({required String sessionId}) =>
      guardApi(
        () => _dio.get<dynamic>('/api/v1/chat/sessions/$sessionId'),
        (data) => (asJsonObject(data)['messages'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((raw) {
              final json = Map<String, dynamic>.from(raw);
              _requiredDateTime(json['created_at'], 'message.created_at');
              return ChatMessageDto.fromJson(
                json,
              ).toEntity(json['id']?.toString() ?? '');
            })
            .toList(growable: false),
      );

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) => guardApi(
    () => _dio.get<dynamic>('/api/v1/chat/sessions/$mainSessionId/forks'),
    (data) {
      final items = asJsonObject(data)['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map>()
          .map((raw) {
            final json = Map<String, dynamic>.from(raw);
            final professorId = json['professor_id']?.toString() ?? '';
            return ForkRef(
              forkId: json['id']?.toString() ?? '',
              mainSessionId:
                  json['root_session_id']?.toString() ?? mainSessionId,
              professorId: professorId,
              professorName: professorId.isEmpty ? '该导师' : professorId,
              university: '',
              college: null,
              createdAt: _requiredDateTime(json['created_at'], 'created_at'),
            );
          })
          .toList(growable: false);
    },
  );

  @override
  Future<Result<void>> deleteFork({required String forkId}) => guardApi(
    () => _dio.delete<dynamic>('/api/v1/chat/sessions/$forkId'),
    (_) {},
  );
}

ErrorDiagnostics _streamDiagnostics({
  required String requestId,
  required String path,
  String? backendCode,
  String? backendMessage,
  String? exceptionType,
  String? cause,
  String? responsePreview,
}) {
  return ErrorDiagnostics(
    requestId: requestId,
    method: 'GET',
    path: path,
    backendCode: backendCode,
    backendMessage: backendMessage,
    exceptionType: exceptionType,
    cause: cause,
    responsePreview: responsePreview,
    occurredAt: DateTime.now(),
  );
}

DateTime _requiredDateTime(Object? value, String field) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    throw FormatException('missing $field');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('invalid $field: $raw');
  return parsed;
}
