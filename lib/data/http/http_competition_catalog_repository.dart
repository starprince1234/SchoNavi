import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/recommended_competition.dart';
import '../../domain/repositories/competition_catalog_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/competition_recommendation_dtos.dart';

class HttpCompetitionCatalogRepository extends CompetitionCatalogRepository {
  HttpCompetitionCatalogRepository(this._dio);

  final Dio _dio;
  final Map<String, RecommendedCompetition> _cache = {};

  @override
  RecommendedCompetition? findById(String id) => _cache[id];

  @override
  Future<RecommendedCompetition?> fetchById(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final result = await guardApi(
      () => _dio.get<dynamic>('/api/v1/competitions/$id'),
      (data) =>
          RecommendedCompetitionDto.fromJson(asJsonObject(data)).toEntity(),
    );
    return switch (result) {
      Success(:final data) => _cache[id] = data,
      Failure(:final error) => throw error,
    };
  }

  @override
  Future<List<RecommendedCompetition>> list() async {
    final result = await guardApi(
      () => _dio.get<dynamic>('/api/v1/competitions'),
      (data) => (data as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => RecommendedCompetitionDto.fromJson(
              asJsonObject(item),
            ).toEntity(),
          )
          .toList(growable: false),
    );
    return switch (result) {
      Success(:final data) => () {
        _cache
          ..clear()
          ..addEntries(data.map((item) => MapEntry(item.id, item)));
        return data;
      }(),
      Failure(:final error) => throw error,
    };
  }
}
