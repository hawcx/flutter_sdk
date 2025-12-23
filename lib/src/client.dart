import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models/config.dart';
import 'models/events.dart';
import 'platform/hawcx_flutter_sdk_platform.dart';

class HawcxClient {
  HawcxClient({HawcxFlutterSdkPlatform? platform})
      : _platform = platform ?? HawcxFlutterSdkPlatform.instance {
    _events = _platform.rawEvents
        .map(HawcxEvent.fromNative)
        .where((event) => event != null)
        .cast<HawcxEvent>()
        .asBroadcastStream();
  }

  final HawcxFlutterSdkPlatform _platform;
  late final Stream<HawcxEvent> _events;

  Stream<HawcxEvent> get events => _events;
  Stream<AuthEvent> get authEvents =>
      _events.where((event) => event is AuthEvent).cast<AuthEvent>();
  Stream<SessionEvent> get sessionEvents =>
      _events.where((event) => event is SessionEvent).cast<SessionEvent>();
  Stream<PushEvent> get pushEvents =>
      _events.where((event) => event is PushEvent).cast<PushEvent>();

  bool _initialized = false;
  StreamSubscription<AuthEvent>? _authSubscription;
  StreamSubscription<SessionEvent>? _sessionSubscription;

  // Configuration stored for MFA API calls
  String? _baseUrl;
  String? _apiKey;

  // Current auth session state
  String? _currentUserId;
  String? _currentSessionId;

  Future<void> initialize(HawcxConfig config) async {
    _baseUrl = config.baseUrl;
    _apiKey = config.projectApiKey;
    await _platform.initialize(config.toMap());
    _initialized = true;
  }

  HawcxAuthHandle authenticate({
    required String userId,
    void Function()? onOtpRequired,
    void Function(AuthorizationCodePayload payload)? onAuthorizationCode,
    void Function(AdditionalVerificationRequiredPayload payload)?
        onAdditionalVerificationRequired,
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

    _currentUserId = trimmedUserId;
    _currentSessionId = null;
    final completer = Completer<AuthSuccessPayload>();
    late final void Function() cleanup;
    cleanup = () {
      _authSubscription?.cancel();
      _authSubscription = null;
      _currentSessionId = null;
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
          // Store sessionId for resend functionality
          _currentSessionId = payload.sessionId;
          // Auto-trigger MFA OTP send when additional verification is required
          _initiateMfa().then((result) {
            if (result.success) {
              debugPrint(
                  '[HawcxClient] MFA OTP sent for session: ${payload.sessionId}');
            } else {
              debugPrint('[HawcxClient] MFA initiate failed: ${result.error}');
            }
          });
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
            completer.completeError(
                HawcxAuthException(payload.code, payload.message));
          }
          break;
      }
    }, onError: (Object error, StackTrace stack) {
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    });

    _platform
        .authenticateV5(trimmedUserId)
        .catchError((Object error, StackTrace stack) {
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

  /// Resend MFA OTP. Call this when user requests to resend the verification code.
  /// Returns [MfaInitiateResult] indicating success or failure.
  Future<MfaInitiateResult> resendMfaOtp() async {
    _requireInitialized();
    if (_currentSessionId == null) {
      return MfaInitiateResult.failure('No active MFA session');
    }
    return _initiateMfa();
  }

  /// Verify MFA OTP. Call this with the OTP received via email/SMS.
  /// Returns [MfaVerifyResult] with auth code on success.
  Future<MfaVerifyResult> verifyMfaOtp({
    required String otp,
    bool rememberMe = true,
  }) async {
    _requireInitialized();
    if (_currentUserId == null || _currentSessionId == null) {
      return MfaVerifyResult.failure('No active MFA session');
    }
    return _verifyMfa(otp: otp, rememberMe: rememberMe);
  }

  /// Internal method to call Hawcx backend to verify MFA OTP.
  Future<MfaVerifyResult> _verifyMfa({
    required String otp,
    required bool rememberMe,
  }) async {
    if (_baseUrl == null || _apiKey == null) {
      return MfaVerifyResult.failure('SDK not configured');
    }

    final url = '$_baseUrl/hc_auth/v5/mfa/verify';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _apiKey!,
        },
        body: jsonEncode({
          'userid': _currentUserId,
          'session_id': _currentSessionId,
          'verification_data': otp,
          'remember_me': rememberMe,
        }),
      );

      debugPrint('[HawcxClient] mfa/verify response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return MfaVerifyResult.success(
          code: body['code'] as String? ?? body['token'] as String?,
        );
      }

      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      return MfaVerifyResult.failure(
        errorBody['detail'] as String? ?? 'MFA verification failed',
      );
    } catch (e) {
      debugPrint('[HawcxClient] mfa/verify error: $e');
      return MfaVerifyResult.failure(e.toString());
    }
  }

  /// Internal method to call Hawcx backend to send MFA OTP.
  /// Called automatically after cipher verification and manually via [resendMfaOtp].
  Future<MfaInitiateResult> _initiateMfa() async {
    if (_baseUrl == null || _apiKey == null) {
      return MfaInitiateResult.failure('SDK not configured');
    }
    if (_currentUserId == null || _currentSessionId == null) {
      return MfaInitiateResult.failure('No active auth session');
    }

    final url = '$_baseUrl/hc_auth/v5/mfa/initiate';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _apiKey!,
        },
        body: jsonEncode({
          'userid': _currentUserId,
          'session_id': _currentSessionId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return MfaInitiateResult.success(
          method: body['method'] as String? ?? 'email',
          phoneMasked: body['phone_masked'] as String?,
        );
      }

      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      return MfaInitiateResult.failure(
        errorBody['detail'] as String? ?? 'MFA initiation failed',
      );
    } catch (e) {
      debugPrint('[HawcxClient] mfa/initiate error: $e');
      return MfaInitiateResult.failure(e.toString());
    }
  }

  Future<void> fetchDeviceDetails(
      {void Function(SessionEvent event)? onEvent}) {
    return _runSessionOperation(
      callNative: _platform.getDeviceDetails,
      onEvent: onEvent,
    );
  }

  Future<void> webLogin(String pin,
      {void Function(SessionEvent event)? onEvent}) {
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

  Future<void> webApprove(String token,
      {void Function(SessionEvent event)? onEvent}) {
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

  Future<void> setPushToken(
      {required String token, required String platform}) async {
    _requireInitialized();
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _platform.setPushToken(
        token: trimmedToken, platform: platform.trim());
  }

  Future<void> setPushDeviceToken(Object token) async {
    _requireInitialized();

    if (kIsWeb) {
      throw UnsupportedError(
          'Push token registration is not supported on web platforms.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        if (token is String) {
          await setApnsDeviceToken(token);
          return;
        }
        if (token is List<int>) {
          await setApnsDeviceToken(base64Encode(token));
          return;
        }
        throw ArgumentError(
            'APNs token must be provided as a base64/hex string or a byte array.');
      case TargetPlatform.android:
        if (token is String) {
          await setFcmToken(token);
          return;
        }
        throw ArgumentError('FCM token must be a string on Android.');
      default:
        throw UnsupportedError(
            'Unsupported platform for push token registration: $defaultTargetPlatform');
    }
  }

  Future<void> userDidAuthenticate() async {
    _requireInitialized();
    await _platform.userDidAuthenticate();
  }

  Future<void> notifyUserAuthenticated() => userDidAuthenticate();

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
            completer.completeError(
                HawcxSessionException(payload.code, payload.message));
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

/// Result of MFA initiation (sending OTP).
class MfaInitiateResult {
  MfaInitiateResult._({
    required this.success,
    this.method,
    this.phoneMasked,
    this.error,
  });

  factory MfaInitiateResult.success({
    required String method,
    String? phoneMasked,
  }) {
    return MfaInitiateResult._(
      success: true,
      method: method,
      phoneMasked: phoneMasked,
    );
  }

  factory MfaInitiateResult.failure(String error) {
    return MfaInitiateResult._(success: false, error: error);
  }

  /// Whether the OTP was successfully sent.
  final bool success;

  /// MFA method used ('email' or 'sms').
  final String? method;

  /// Masked phone number if SMS method (e.g., '+1***1234').
  final String? phoneMasked;

  /// Error message if [success] is false.
  final String? error;
}

/// Result of MFA verification.
class MfaVerifyResult {
  MfaVerifyResult._({
    required this.success,
    this.code,
    this.error,
  });

  factory MfaVerifyResult.success({String? code}) {
    return MfaVerifyResult._(success: true, code: code);
  }

  factory MfaVerifyResult.failure(String error) {
    return MfaVerifyResult._(success: false, error: error);
  }

  /// Whether the MFA OTP was successfully verified.
  final bool success;

  /// Authorization code returned on success (for token exchange).
  final String? code;

  /// Error message if [success] is false.
  final String? error;
}
