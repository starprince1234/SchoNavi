import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/professor.dart';

final professorProvider = FutureProvider.family<Professor, String>((
  ref,
  id,
) async {
  final repo = ref.watch(professorRepositoryProvider);
  final result = await repo.getProfessor(id);
  return switch (result) {
    Success(:final data) => data,
    Failure(:final error) => throw error,
  };
});
