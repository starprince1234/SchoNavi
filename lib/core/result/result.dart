import '../error/app_exception.dart';

/// 仓储层统一返回类型：成功携带数据，失败携带 [AppException]。
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppException error;
}
