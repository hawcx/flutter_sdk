import 'dart:async';

import 'errors.dart';
import 'models/config.dart';
import 'models/events.dart';
import 'platform/hawcx_flutter_sdk_platform.dart';

class HawcxFlutterSdk {
  HawcxFlutterSdk._();

  static Stream<HawcxEvent> get events {
    return HawcxFlutterSdkPlatform.instance.rawEvents
        .map(HawcxEvent.fromNative)
        .whereType<HawcxEvent>();
  }

  static Stream<AuthEvent> get authEvents => events.whereType<AuthEvent>();
  static Stream<SessionEvent> get sessionEvents => events.whereType<SessionEvent>();
  static Stream<PushEvent> get pushEvents => events.whereType<PushEvent>();

  static Future<void> initialize(HawcxConfig config) {
    return HawcxFlutterSdkPlatform.instance.initialize(config.toMap());
  }

  static Future<void> authenticateV5({required String userId}) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await HawcxFlutterSdkPlatform.instance.authenticateV5(trimmed);
  }

  static Future<void> submitOtpV5({required String otp}) async {
    if (otp.isEmpty) {
      throw ArgumentError('otp is required');
    }
    await HawcxFlutterSdkPlatform.instance.submitOtpV5(otp.trim());
  }

  static Future<void> getDeviceDetails() {
    return HawcxFlutterSdkPlatform.instance.getDeviceDetails();
  }

  static Future<void> webLogin({required String pin}) async {
    if (pin.isEmpty) {
      throw ArgumentError('pin is required');
    }
    await HawcxFlutterSdkPlatform.instance.webLogin(pin.trim());
  }

  static Future<void> webApprove({required String token}) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await HawcxFlutterSdkPlatform.instance.webApprove(token.trim());
  }

  static Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    final trimmedUser = userId.trim();
    if (trimmedUser.isEmpty) {
      throw ArgumentError('userId is required');
    }
    final trimmedAccess = accessToken.trim();
    if (trimmedAccess.isEmpty) {
      throw ArgumentError('accessToken is required');
    }
    final trimmedRefresh = refreshToken?.trim();
    return HawcxFlutterSdkPlatform.instance.storeBackendOAuthTokens(
      userId: trimmedUser,
      accessToken: trimmedAccess,
      refreshToken: trimmedRefresh?.isEmpty == true ? null : trimmedRefresh,
    );
  }

  static Future<String> getLastLoggedInUser() async {
    return HawcxFlutterSdkPlatform.instance.getLastLoggedInUser();
  }

  static Future<void> clearSessionTokens({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await HawcxFlutterSdkPlatform.instance.clearSessionTokens(userId.trim());
  }

  static Future<void> clearUserKeychainData({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await HawcxFlutterSdkPlatform.instance.clearUserKeychainData(userId.trim());
  }

  static Future<void> clearLastLoggedInUser() async {
    await HawcxFlutterSdkPlatform.instance.clearLastLoggedInUser();
  }

  static Future<void> setApnsDeviceToken({required String tokenBase64OrHex}) async {
    if (tokenBase64OrHex.isEmpty) {
      throw ArgumentError('tokenBase64OrHex is required');
    }
    await HawcxFlutterSdkPlatform.instance.setApnsDeviceToken(tokenBase64OrHex.trim());
  }

  static Future<void> setFcmToken({required String token}) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await HawcxFlutterSdkPlatform.instance.setFcmToken(token.trim());
  }

  static Future<void> setPushToken({
    required String token,
    required String platform,
  }) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await HawcxFlutterSdkPlatform.instance.setPushToken(token: token.trim(), platform: platform.trim());
  }

  static Future<void> userDidAuthenticate() async {
    await HawcxFlutterSdkPlatform.instance.userDidAuthenticate();
  }

  static Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    return HawcxFlutterSdkPlatform.instance.handlePushNotification(payload);
  }

  static Future<void> approvePushRequest({required String requestId}) async {
    if (requestId.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await HawcxFlutterSdkPlatform.instance.approvePushRequest(requestId.trim());
  }

  static Future<void> declinePushRequest({required String requestId}) async {
    if (requestId.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await HawcxFlutterSdkPlatform.instance.declinePushRequest(requestId.trim());
  }

  @Deprecated('Use HawcxFlutterSdkPlatform in tests instead.')
  static HawcxAuthException authCancelledError() => HawcxAuthException.cancelled();
}
