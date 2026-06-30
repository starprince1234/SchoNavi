import '../entities/home_config.dart';

abstract interface class HomeConfigRepository {
  Future<HomeConfig> fetchConfig(String mode);
}
