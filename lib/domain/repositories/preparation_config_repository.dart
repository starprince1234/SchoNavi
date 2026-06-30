import '../entities/preparation_config.dart';

abstract interface class PreparationConfigRepository {
  Future<PreparationConfig> fetch();
}
