import 'package:flutter/services.dart';

import 'hawcx_flutter_sdk_platform.dart';

class MethodChannelHawcxFlutterSdk extends HawcxFlutterSdkPlatform {
  static const MethodChannel _channel = MethodChannel('hawcx_flutter');
  static const EventChannel _events = EventChannel('hawcx_flutter/events');

  @override
  Stream<Object?> get rawEvents => _events.receiveBroadcastStream();

  @override
  Future<void> initialize(Map<String, Object?> config) {
    return _channel.invokeMethod<void>('initialize', config);
  }

  @override
  Future<void> authenticateV5(String userId) {
    return _channel.invokeMethod<void>('authenticateV5', {'userId': userId});
  }

  @override
  Future<void> submitOtpV5(String otp) {
    return _channel.invokeMethod<void>('submitOtpV5', {'otp': otp});
  }

  @override
  Future<void> getDeviceDetails() {
    return _channel.invokeMethod<void>('getDeviceDetails');
  }

  @override
  Future<void> webLogin(String pin) {
    return _channel.invokeMethod<void>('webLogin', {'pin': pin});
  }

  @override
  Future<void> webApprove(String token) {
    return _channel.invokeMethod<void>('webApprove', {'token': token});
  }

  @override
  Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    final stored =
        await _channel.invokeMethod<bool>('storeBackendOAuthTokens', {
      'userId': userId,
      'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
    return stored ?? false;
  }

  @override
  Future<String> getLastLoggedInUser() async {
    return (await _channel.invokeMethod<String>('getLastLoggedInUser')) ?? '';
  }

  @override
  Future<void> clearSessionTokens(String userId) {
    return _channel
        .invokeMethod<void>('clearSessionTokens', {'userId': userId});
  }

  @override
  Future<void> clearUserKeychainData(String userId) {
    return _channel
        .invokeMethod<void>('clearUserKeychainData', {'userId': userId});
  }

  @override
  Future<void> clearLastLoggedInUser() {
    return _channel.invokeMethod<void>('clearLastLoggedInUser');
  }

  @override
  Future<void> setApnsDeviceToken(String tokenBase64OrHex) {
    return setPushToken(token: tokenBase64OrHex, platform: 'ios');
  }

  @override
  Future<void> setFcmToken(String token) {
    return setPushToken(token: token, platform: 'android');
  }

  @override
  Future<void> setPushToken({required String token, required String platform}) {
    return _channel.invokeMethod<void>(
        'setPushToken', {'token': token, 'platform': platform});
  }

  @override
  Future<void> userDidAuthenticate() {
    return _channel.invokeMethod<void>('userDidAuthenticate');
  }

  @override
  Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    final handled =
        await _channel.invokeMethod<bool>('handlePushNotification', payload);
    return handled ?? false;
  }

  @override
  Future<void> approvePushRequest(String requestId) {
    return _channel
        .invokeMethod<void>('approvePushRequest', {'requestId': requestId});
  }

  @override
  Future<void> declinePushRequest(String requestId) {
    return _channel
        .invokeMethod<void>('declinePushRequest', {'requestId': requestId});
  }
}
