import '../errors.dart';

typedef JsonMap = Map<String, Object?>;

JsonMap? asStringKeyMap(Object? value) {
  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = entry.value as Object?;
    }
    return out;
  }
  return null;
}

sealed class HawcxEvent {
  const HawcxEvent(this.type);

  final String type;

  static HawcxEvent? fromNative(Object? raw) {
    final map = asStringKeyMap(raw);
    if (map == null) return null;
    final type = map['type'];
    if (type is! String || type.trim().isEmpty) return null;

    final payload = asStringKeyMap(map['payload']);
    switch (type) {
      case 'otp_required':
        return const AuthOtpRequiredEvent();
      case 'auth_success':
        final parsed = AuthSuccessPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : AuthSuccessEvent(parsed);
      case 'auth_error':
        final parsed = HawcxErrorPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : AuthErrorEvent(parsed);
      case 'authorization_code':
        final parsed = AuthorizationCodePayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : AuthorizationCodeEvent(parsed);
      case 'additional_verification_required':
        final parsed = AdditionalVerificationRequiredPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : AdditionalVerificationRequiredEvent(parsed);
      case 'session_success':
        return const SessionSuccessEvent();
      case 'session_error':
        final parsed = HawcxErrorPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : SessionErrorEvent(parsed);
      case 'push_login_request':
        final parsed = PushLoginPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : PushLoginRequestEvent(parsed);
      case 'push_error':
        final parsed = HawcxErrorPayload.tryParse(payload);
        return parsed == null
            ? HawcxUnknownEvent(type, map)
            : PushErrorEvent(parsed);
      default:
        return HawcxUnknownEvent(type, map);
    }
  }
}

final class HawcxUnknownEvent extends HawcxEvent {
  const HawcxUnknownEvent(super.type, this.raw);
  final JsonMap raw;
}

sealed class AuthEvent extends HawcxEvent {
  const AuthEvent(super.type);
}

final class AuthOtpRequiredEvent extends AuthEvent {
  const AuthOtpRequiredEvent() : super('otp_required');
}

final class AuthSuccessEvent extends AuthEvent {
  const AuthSuccessEvent(this.payload) : super('auth_success');
  final AuthSuccessPayload payload;
}

final class AuthErrorEvent extends AuthEvent {
  const AuthErrorEvent(this.payload) : super('auth_error');
  final HawcxErrorPayload payload;

  HawcxAuthException toException() =>
      HawcxAuthException(payload.code, payload.message);
}

final class AuthorizationCodeEvent extends AuthEvent {
  const AuthorizationCodeEvent(this.payload) : super('authorization_code');
  final AuthorizationCodePayload payload;
}

final class AdditionalVerificationRequiredEvent extends AuthEvent {
  const AdditionalVerificationRequiredEvent(this.payload)
      : super('additional_verification_required');
  final AdditionalVerificationRequiredPayload payload;
}

sealed class SessionEvent extends HawcxEvent {
  const SessionEvent(super.type);
}

final class SessionSuccessEvent extends SessionEvent {
  const SessionSuccessEvent() : super('session_success');
}

final class SessionErrorEvent extends SessionEvent {
  const SessionErrorEvent(this.payload) : super('session_error');
  final HawcxErrorPayload payload;

  HawcxSessionException toException() =>
      HawcxSessionException(payload.code, payload.message);
}

sealed class PushEvent extends HawcxEvent {
  const PushEvent(super.type);
}

final class PushLoginRequestEvent extends PushEvent {
  const PushLoginRequestEvent(this.payload) : super('push_login_request');
  final PushLoginPayload payload;
}

final class PushErrorEvent extends PushEvent {
  const PushErrorEvent(this.payload) : super('push_error');
  final HawcxErrorPayload payload;
}

final class HawcxErrorPayload {
  const HawcxErrorPayload({required this.code, required this.message});

  final String code;
  final String message;

  static HawcxErrorPayload? tryParse(JsonMap? payload) {
    if (payload == null) return null;
    final code = payload['code'];
    final message = payload['message'];
    if (code is! String || code.isEmpty) return null;
    if (message is! String || message.isEmpty) return null;
    return HawcxErrorPayload(code: code, message: message);
  }
}

final class AuthSuccessPayload {
  const AuthSuccessPayload({
    required this.isLoginFlow,
    this.accessToken,
    this.refreshToken,
  });

  final bool isLoginFlow;
  final String? accessToken;
  final String? refreshToken;

  static AuthSuccessPayload? tryParse(JsonMap? payload) {
    if (payload == null) return null;
    final isLoginFlow = payload['isLoginFlow'];
    if (isLoginFlow is! bool) return null;
    final accessToken = payload['accessToken'];
    final refreshToken = payload['refreshToken'];
    return AuthSuccessPayload(
      isLoginFlow: isLoginFlow,
      accessToken:
          accessToken is String && accessToken.isNotEmpty ? accessToken : null,
      refreshToken: refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null,
    );
  }
}

final class AuthorizationCodePayload {
  const AuthorizationCodePayload({
    required this.code,
    this.expiresIn,
  });

  final String code;
  final int? expiresIn;

  static AuthorizationCodePayload? tryParse(JsonMap? payload) {
    if (payload == null) return null;
    final code = payload['code'];
    if (code is! String || code.isEmpty) return null;
    final expiresRaw = payload['expiresIn'];
    final expiresIn = switch (expiresRaw) {
      int v => v,
      num v => v.toInt(),
      _ => null,
    };
    return AuthorizationCodePayload(code: code, expiresIn: expiresIn);
  }
}

final class AdditionalVerificationRequiredPayload {
  const AdditionalVerificationRequiredPayload({
    required this.sessionId,
    this.detail,
  });

  final String sessionId;
  final String? detail;

  static AdditionalVerificationRequiredPayload? tryParse(JsonMap? payload) {
    if (payload == null) return null;
    final sessionId = payload['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) return null;
    final detail = payload['detail'];
    return AdditionalVerificationRequiredPayload(
      sessionId: sessionId,
      detail: detail is String && detail.isNotEmpty ? detail : null,
    );
  }
}

final class PushLoginPayload {
  const PushLoginPayload({
    required this.requestId,
    required this.ipAddress,
    required this.deviceInfo,
    required this.timestamp,
    this.location,
  });

  final String requestId;
  final String ipAddress;
  final String deviceInfo;
  final String timestamp;
  final String? location;

  static PushLoginPayload? tryParse(JsonMap? payload) {
    if (payload == null) return null;
    final requestId = payload['requestId'];
    final ipAddress = payload['ipAddress'];
    final deviceInfo = payload['deviceInfo'];
    final timestamp = payload['timestamp'];
    if (requestId is! String || requestId.isEmpty) return null;
    if (ipAddress is! String || ipAddress.isEmpty) return null;
    if (deviceInfo is! String || deviceInfo.isEmpty) return null;
    if (timestamp is! String || timestamp.isEmpty) return null;
    final location = payload['location'];
    return PushLoginPayload(
      requestId: requestId,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      timestamp: timestamp,
      location: location is String && location.isNotEmpty ? location : null,
    );
  }
}
