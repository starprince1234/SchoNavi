import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../core/error/app_exception.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/favorite_dto.dart';

class HttpFavoriteRepository implements FavoriteRepository {
  HttpFavoriteRepository(this._dio, {this.onSyncError});

  final Dio _dio;
  final void Function(AppException)? onSyncError;
  final StreamController<List<FavoriteItem>> _controller =
      StreamController<List<FavoriteItem>>.broadcast();
  List<FavoriteItem> _snapshot = const [];

  @override
  List<FavoriteItem> list() {
    _refresh();
    return _snapshot;
  }

  @override
  Stream<List<FavoriteItem>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  bool isFavorite(String professorId) =>
      _snapshot.any((item) => item.professorId == professorId);

  @override
  Future<void> add(FavoriteItem item) async {
    final result = await guardApi(
      () => _dio.put<dynamic>(
        '/api/v1/favorites/${item.professorId}',
        data: FavoriteItemDto.fromEntity(item).toJson(),
      ),
      (data) => FavoriteStatusDto.fromJson(asJsonObject(data)),
    );
    switch (result) {
      case Success<FavoriteStatusDto>(:final data):
        final saved = data.item?.toEntity() ?? item;
        _setSnapshot(
          [
            saved,
            ..._snapshot.where(
              (current) => current.professorId != item.professorId,
            ),
          ]..sort(_byNewest),
        );
      case Failure<FavoriteStatusDto>(:final error):
        throw error;
    }
  }

  @override
  Future<void> remove(String professorId) async {
    final result = await guardApi(
      () => _dio.delete<dynamic>('/api/v1/favorites/$professorId'),
      (_) => true,
    );
    if (result case Failure<bool>(:final error)) throw error;
    _setSnapshot(
      _snapshot
          .where((current) => current.professorId != professorId)
          .toList(growable: false),
    );
  }

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (isFavorite(item.professorId)) {
      await remove(item.professorId);
      return false;
    }
    await add(item);
    return true;
  }

  void dispose() => _controller.close();

  Future<void> _refresh() async {
    final result = await guardApi(
      () => _dio.get<dynamic>('/api/v1/favorites'),
      (data) => (data as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => FavoriteItemDto.fromJson(asJsonObject(item)).toEntity(),
          )
          .toList(growable: false),
    );
    if (result is Success<List<FavoriteItem>>) {
      _setSnapshot(result.data..sort(_byNewest));
    } else if (result case Failure<List<FavoriteItem>>(:final error)) {
      onSyncError?.call(error);
    }
  }

  void _setSnapshot(List<FavoriteItem> items) {
    _snapshot = List<FavoriteItem>.unmodifiable(items);
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  static int _byNewest(FavoriteItem a, FavoriteItem b) =>
      b.favoritedAt.compareTo(a.favoritedAt);
}
