import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_hawcx_flutter_sdk.dart';

abstract class HawcxFlutterSdkPlatform extends PlatformInterface {
  HawcxFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static HawcxFlutterSdkPlatform _instance = MethodChannelHawcxFlutterSdk();

  static HawcxFlutterSdkPlatform get instance => _instance;

  static set instance(HawcxFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Object?> get rawEvents;

  Future<void> initialize(Map<String, Object?> config);

  Future<void> authenticateV5(String userId);

  Future<void> submitOtpV5(String otp);

  Future<void> getDeviceDetails();

  Future<void> webLogin(String pin);

  Future<void> webApprove(String token);

  Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  });

  Future<String> getLastLoggedInUser();

  Future<void> clearSessionTokens(String userId);

  Future<void> clearUserKeychainData(String userId);

  Future<void> clearLastLoggedInUser();

  Future<void> setApnsDeviceToken(String tokenBase64OrHex);

  Future<void> setFcmToken(String token);

  Future<void> setPushToken({required String token, required String platform});

  Future<void> userDidAuthenticate();

  Future<bool> handlePushNotification(Map<String, Object?> payload);

  Future<void> approvePushRequest(String requestId);

  Future<void> declinePushRequest(String requestId);
}
