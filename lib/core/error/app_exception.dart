/// 全应用统一异常基类，承载用户可读中文文案。
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  /// 把 HTTP 状态码映射为对应异常（供网络层使用）。
  static AppException fromStatusCode(int code) {
    switch (code) {
      case 400:
        return const BadRequestException();
      case 401:
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 429:
        return const RateLimitException();
      case >= 500 && <= 599:
        return const ServerException();
      default:
        return const UnknownException();
    }
  }

  @override
  String toString() => '$runtimeType($message)';
}

class NetworkException extends AppException {
  const NetworkException() : super('当前网络不可用，请检查网络后重试');
}

class TimeoutException extends AppException {
  const TimeoutException() : super('请求超时，请点击重试');
}

class BadRequestException extends AppException {
  const BadRequestException() : super('输入内容不合法');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('请先登录');
}

class ForbiddenException extends AppException {
  const ForbiddenException() : super('暂无权限');
}

class NotFoundException extends AppException {
  const NotFoundException() : super('信息不存在');
}

class RateLimitException extends AppException {
  const RateLimitException() : super('请求过于频繁，请稍后再试');
}

class ServerException extends AppException {
  const ServerException() : super('服务异常，请稍后重试');
}

class UnknownException extends AppException {
  const UnknownException() : super('出错了，请稍后重试');
}
