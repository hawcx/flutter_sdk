sealed class HawcxException implements Exception {
  const HawcxException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'HawcxException(code=$code, message=$message)';
}

final class HawcxAuthException extends HawcxException {
  const HawcxAuthException(super.code, super.message);

  static const String cancelledCode = 'AUTH_CANCELLED';

  factory HawcxAuthException.cancelled() {
    return const HawcxAuthException(cancelledCode, 'Authentication cancelled');
  }
}

final class HawcxSessionException extends HawcxException {
  const HawcxSessionException(super.code, super.message);
}

