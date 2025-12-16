import 'dart:async';

import 'errors.dart';
import 'models/config.dart';
import 'models/events.dart';
import 'platform/hawcx_flutter_sdk_platform.dart';

class HawcxClient {
  HawcxClient({HawcxFlutterSdkPlatform? platform}) : _platform = platform ?? HawcxFlutterSdkPlatform.instance {
    _events = _platform.rawEvents
        .map(HawcxEvent.fromNative)
        .whereType<HawcxEvent>()
        .asBroadcastStream();
  }

  final HawcxFlutterSdkPlatform _platform;
  late final Stream<HawcxEvent> _events;

  Stream<HawcxEvent> get events => _events;
  Stream<AuthEvent> get authEvents => _events.whereType<AuthEvent>();
  Stream<SessionEvent> get sessionEvents => _events.whereType<SessionEvent>();
  Stream<PushEvent> get pushEvents => _events.whereType<PushEvent>();

  bool _initialized = false;
  StreamSubscription<AuthEvent>? _authSubscription;
  StreamSubscription<SessionEvent>? _sessionSubscription;

  Future<void> initialize(HawcxConfig config) async {
    await _platform.initialize(config.toMap());
    _initialized = true;
  }

  HawcxAuthHandle authenticate({
    required String userId,
    void Function()? onOtpRequired,
    void Function(AuthorizationCodePayload payload)? onAuthorizationCode,
    void Function(AdditionalVerificationRequiredPayload payload)? onAdditionalVerificationRequired,
    void Function(AuthEvent event)? onEvent,
  }) {
    _requireInitialized();
    if (_authSubscription != null) {
      throw StateError('An authentication flow is already in progress');
    }

    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError('userId is required');
    }

    final completer = Completer<AuthSuccessPayload>();
    late final void Function() cleanup;
    cleanup = () {
      _authSubscription?.cancel();
      _authSubscription = null;
    };

    _authSubscription = authEvents.listen((event) {
      onEvent?.call(event);
      switch (event) {
        case AuthOtpRequiredEvent():
          onOtpRequired?.call();
          break;
        case AuthorizationCodeEvent(:final payload):
          onAuthorizationCode?.call(payload);
          break;
        case AdditionalVerificationRequiredEvent(:final payload):
          onAdditionalVerificationRequired?.call(payload);
          break;
        case AuthSuccessEvent(:final payload):
          cleanup();
          if (!completer.isCompleted) {
            completer.complete(payload);
          }
          break;
        case AuthErrorEvent(:final payload):
          cleanup();
          if (!completer.isCompleted) {
            completer.completeError(HawcxAuthException(payload.code, payload.message));
          }
          break;
      }
    }, onError: (Object error, StackTrace stack) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    });

    _platform.authenticateV5(trimmedUserId).catchError((Object error, StackTrace stack) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    });

    return HawcxAuthHandle._(
      future: completer.future,
      cancel: () {
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError(HawcxAuthException.cancelled());
        }
      },
    );
  }

  Future<void> submitOtp(String otp) async {
    _requireInitialized();
    final trimmed = otp.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('otp is required');
    }
    await _platform.submitOtpV5(trimmed);
  }

  Future<void> fetchDeviceDetails({void Function(SessionEvent event)? onEvent}) {
    return _runSessionOperation(
      callNative: _platform.getDeviceDetails,
      onEvent: onEvent,
    );
  }

  Future<void> webLogin(String pin, {void Function(SessionEvent event)? onEvent}) {
    _requireInitialized();
    final trimmed = pin.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('pin is required');
    }
    return _runSessionOperation(
      callNative: () => _platform.webLogin(trimmed),
      onEvent: onEvent,
    );
  }

  Future<void> webApprove(String token, {void Function(SessionEvent event)? onEvent}) {
    _requireInitialized();
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('token is required');
    }
    return _runSessionOperation(
      callNative: () => _platform.webApprove(trimmed),
      onEvent: onEvent,
    );
  }

  Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    _requireInitialized();
    final trimmedUser = userId.trim();
    if (trimmedUser.isEmpty) {
      throw ArgumentError('userId is required');
    }
    final trimmedAccess = accessToken.trim();
    if (trimmedAccess.isEmpty) {
      throw ArgumentError('accessToken is required');
    }
    final trimmedRefresh = refreshToken?.trim();
    return _platform.storeBackendOAuthTokens(
      userId: trimmedUser,
      accessToken: trimmedAccess,
      refreshToken: trimmedRefresh?.isEmpty == true ? null : trimmedRefresh,
    );
  }

  Future<String> getLastLoggedInUser() {
    _requireInitialized();
    return _platform.getLastLoggedInUser();
  }

  Future<void> clearSessionTokens(String userId) async {
    _requireInitialized();
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await _platform.clearSessionTokens(trimmed);
  }

  Future<void> clearUserKeychainData(String userId) async {
    _requireInitialized();
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await _platform.clearUserKeychainData(trimmed);
  }

  Future<void> clearLastLoggedInUser() async {
    _requireInitialized();
    await _platform.clearLastLoggedInUser();
  }

  Future<void> setApnsDeviceToken(String tokenBase64OrHex) async {
    _requireInitialized();
    final trimmed = tokenBase64OrHex.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _platform.setApnsDeviceToken(trimmed);
  }

  Future<void> setFcmToken(String token) async {
    _requireInitialized();
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _platform.setFcmToken(trimmed);
  }

  Future<void> setPushToken({required String token, required String platform}) async {
    _requireInitialized();
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _platform.setPushToken(token: trimmedToken, platform: platform.trim());
  }

  Future<void> userDidAuthenticate() async {
    _requireInitialized();
    await _platform.userDidAuthenticate();
  }

  Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    _requireInitialized();
    return _platform.handlePushNotification(payload);
  }

  Future<void> approvePushRequest(String requestId) async {
    _requireInitialized();
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await _platform.approvePushRequest(trimmed);
  }

  Future<void> declinePushRequest(String requestId) async {
    _requireInitialized();
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await _platform.declinePushRequest(trimmed);
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _sessionSubscription?.cancel();
    _authSubscription = null;
    _sessionSubscription = null;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError('HawcxClient.initialize must be called first');
    }
  }

  Future<void> _runSessionOperation({
    required Future<void> Function() callNative,
    void Function(SessionEvent event)? onEvent,
  }) {
    _requireInitialized();
    if (_sessionSubscription != null) {
      throw StateError('A session operation is already in progress');
    }

    final completer = Completer<void>();
    late final void Function() cleanup;
    cleanup = () {
      _sessionSubscription?.cancel();
      _sessionSubscription = null;
    };

    _sessionSubscription = sessionEvents.listen((event) {
      onEvent?.call(event);
      switch (event) {
        case SessionSuccessEvent():
          cleanup();
          if (!completer.isCompleted) {
            completer.complete();
          }
          break;
        case SessionErrorEvent(:final payload):
          cleanup();
          if (!completer.isCompleted) {
            completer.completeError(HawcxSessionException(payload.code, payload.message));
          }
          break;
      }
    }, onError: (Object error, StackTrace stack) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    });

    callNative().catchError((Object error, StackTrace stack) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    });

    return completer.future;
  }
}

class HawcxAuthHandle {
  HawcxAuthHandle._({required this.future, required this.cancel});

  final Future<AuthSuccessPayload> future;
  final void Function() cancel;
}
