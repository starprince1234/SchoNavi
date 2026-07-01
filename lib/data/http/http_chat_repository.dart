import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/entities/fork_ref.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/chat_dto.dart';
import '../dto/chat_message_dto.dart';

class HttpChatRepository implements ChatRepository {
  const HttpChatRepository(this._dio);

  final Dio _dio;

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
    try {
      final response = await _dio.get<ResponseBody>(
        '/api/v1/chat/stream',
        queryParameters: <String, dynamic>{
          'session_id': sessionId,
          'message': message,
          'professor_id': ?professorId,
        },
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) throw const ServerException();

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
          final payload = jsonDecode(dataLines.join('\n'));
          dataLines.clear();
          if (payload is! Map<String, dynamic>) continue;
          switch (event) {
            case 'delta':
              yield payload['text']?.toString() ?? '';
              break;
            case 'error':
              throw ValidationException(
                payload['message']?.toString() ?? '服务异常，请稍后重试',
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
    } catch (_) {
      throw const ServerException();
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

DateTime _requiredDateTime(Object? value, String field) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    throw FormatException('missing $field');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('invalid $field: $raw');
  return parsed;
}
