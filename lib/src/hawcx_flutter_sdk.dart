import 'dart:async';
import 'package:flutter/services.dart';

class HawcxFlutterSdk {
  HawcxFlutterSdk._();

  static const MethodChannel _channel = MethodChannel('hawcx_flutter');
  static const EventChannel _events = EventChannel('hawcx_flutter/events');

  static Stream<dynamic> get events => _events.receiveBroadcastStream();

  static Future<void> initialize({
    required String apiKey,
    String? baseUrl,
    Map<String, dynamic>? oauthConfig,
  }) async {
    if (apiKey.isEmpty) {
      throw ArgumentError('apiKey is required');
    }
    await _channel.invokeMethod<void>('initialize', {
      'apiKey': apiKey,
      if (baseUrl != null) 'baseUrl': baseUrl,
      if (oauthConfig != null) 'oauthConfig': oauthConfig,
    });
  }

  static Future<Map<String, dynamic>?> authenticateV5({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('authenticateV5', {
      'userId': userId,
    });
    return result?.cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>?> submitOtpV5({
    required String otp,
    required String userId,
  }) async {
    if (otp.isEmpty) {
      throw ArgumentError('otp is required');
    }
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('submitOtpV5', {
      'otp': otp,
      'userId': userId,
    });
    return result?.cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>?> getDeviceDetails() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('getDeviceDetails');
    return result?.cast<String, dynamic>();
  }

  static Future<void> webLogin({required String pin}) async {
    if (pin.isEmpty) {
      throw ArgumentError('pin is required');
    }
    await _channel.invokeMethod<void>('webLogin', {'pin': pin});
  }

  static Future<void> webApprove({required String token}) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _channel.invokeMethod<void>('webApprove', {'token': token});
  }

  static Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    if (accessToken.isEmpty) {
      throw ArgumentError('accessToken is required');
    }
    final stored = await _channel.invokeMethod<bool>('storeBackendOAuthTokens', {
      'userId': userId,
      'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
    return stored ?? false;
  }

  static Future<String> getLastLoggedInUser() async {
    return (await _channel.invokeMethod<String>('getLastLoggedInUser')) ?? '';
  }

  static Future<void> clearSessionTokens({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await _channel.invokeMethod<void>('clearSessionTokens', {'userId': userId});
  }

  static Future<void> clearUserKeychainData({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId is required');
    }
    await _channel.invokeMethod<void>('clearUserKeychainData', {'userId': userId});
  }

  static Future<void> clearLastLoggedInUser() async {
    await _channel.invokeMethod<void>('clearLastLoggedInUser');
  }

  static Future<void> setApnsDeviceToken({required String tokenBase64OrHex}) async {
    if (tokenBase64OrHex.isEmpty) {
      throw ArgumentError('tokenBase64OrHex is required');
    }
    await _channel.invokeMethod<void>('setApnsDeviceToken', {
      'token': tokenBase64OrHex,
    });
  }

  static Future<void> setFcmToken({required String token}) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _channel.invokeMethod<void>('setFcmToken', {'token': token});
  }

  static Future<void> setPushToken({
    required String token,
    required String platform,
  }) async {
    if (token.isEmpty) {
      throw ArgumentError('token is required');
    }
    await _channel.invokeMethod<void>('setPushToken', {
      'token': token,
      'platform': platform,
    });
  }

  static Future<void> userDidAuthenticate() async {
    await _channel.invokeMethod<void>('userDidAuthenticate');
  }

  static Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    await _channel.invokeMethod<void>('handlePushNotification', payload);
  }

  static Future<void> approvePushRequest({required String requestId}) async {
    if (requestId.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await _channel.invokeMethod<void>('approvePushRequest', {'requestId': requestId});
  }

  static Future<void> declinePushRequest({required String requestId}) async {
    if (requestId.isEmpty) {
      throw ArgumentError('requestId is required');
    }
    await _channel.invokeMethod<void>('declinePushRequest', {'requestId': requestId});
  }
}
