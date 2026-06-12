import '../../core/result/result.dart';
import '../entities/comparison_report.dart';
import '../entities/professor.dart';

/// 多导师横向对比（远程类，走 Result）。
abstract interface class ComparisonRepository {
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  });
}
