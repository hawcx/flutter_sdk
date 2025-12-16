import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';
import 'package:hawcx_flutter_sdk/src/platform/hawcx_flutter_sdk_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeHawcxPlatform extends HawcxFlutterSdkPlatform with MockPlatformInterfaceMixin {
  final _events = StreamController<Object?>.broadcast();
  final calls = <Map<String, Object?>>[];

  void emit(Map<String, Object?> event) => _events.add(event);

  @override
  Stream<Object?> get rawEvents => _events.stream;

  @override
  Future<void> initialize(Map<String, Object?> config) async {
    calls.add({'method': 'initialize', 'args': config});
  }

  @override
  Future<void> authenticateV5(String userId) async {
    calls.add({'method': 'authenticateV5', 'userId': userId});
  }

  @override
  Future<void> submitOtpV5(String otp) async {
    calls.add({'method': 'submitOtpV5', 'otp': otp});
  }

  @override
  Future<void> getDeviceDetails() async {
    calls.add({'method': 'getDeviceDetails'});
  }

  @override
  Future<void> webLogin(String pin) async {
    calls.add({'method': 'webLogin', 'pin': pin});
  }

  @override
  Future<void> webApprove(String token) async {
    calls.add({'method': 'webApprove', 'token': token});
  }

  @override
  Future<bool> storeBackendOAuthTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    calls.add({
      'method': 'storeBackendOAuthTokens',
      'userId': userId,
      'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
    });
    return true;
  }

  @override
  Future<String> getLastLoggedInUser() async {
    calls.add({'method': 'getLastLoggedInUser'});
    return 'u';
  }

  @override
  Future<void> clearSessionTokens(String userId) async {
    calls.add({'method': 'clearSessionTokens', 'userId': userId});
  }

  @override
  Future<void> clearUserKeychainData(String userId) async {
    calls.add({'method': 'clearUserKeychainData', 'userId': userId});
  }

  @override
  Future<void> clearLastLoggedInUser() async {
    calls.add({'method': 'clearLastLoggedInUser'});
  }

  @override
  Future<void> setApnsDeviceToken(String tokenBase64OrHex) async {
    calls.add({'method': 'setApnsDeviceToken', 'token': tokenBase64OrHex});
  }

  @override
  Future<void> setFcmToken(String token) async {
    calls.add({'method': 'setFcmToken', 'token': token});
  }

  @override
  Future<void> setPushToken({required String token, required String platform}) async {
    calls.add({'method': 'setPushToken', 'token': token, 'platform': platform});
  }

  @override
  Future<void> userDidAuthenticate() async {
    calls.add({'method': 'userDidAuthenticate'});
  }

  @override
  Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    calls.add({'method': 'handlePushNotification', 'payload': payload});
    return payload.containsKey('request_id');
  }

  @override
  Future<void> approvePushRequest(String requestId) async {
    calls.add({'method': 'approvePushRequest', 'requestId': requestId});
  }

  @override
  Future<void> declinePushRequest(String requestId) async {
    calls.add({'method': 'declinePushRequest', 'requestId': requestId});
  }

  void close() => _events.close();
}

void main() {
  test('HawcxConfig validates required fields', () {
    expect(
      () => HawcxConfig(projectApiKey: '', baseUrl: 'https://x'),
      throwsArgumentError,
    );
    expect(
      () => HawcxConfig(projectApiKey: 'k', baseUrl: ''),
      throwsArgumentError,
    );
  });

  test('HawcxEvent parsing handles unknown events', () {
    final event = HawcxEvent.fromNative({'type': 'new_event', 'payload': {'x': 1}});
    expect(event, isA<HawcxUnknownEvent>());
    expect(event?.type, 'new_event');
  });

  test('HawcxClient authenticate resolves on auth_success', () async {
    final platform = FakeHawcxPlatform();
    HawcxFlutterSdkPlatform.instance = platform;

    final client = HawcxClient(platform: platform);
    await client.initialize(HawcxConfig(projectApiKey: 'k', baseUrl: 'https://x'));

    final auth = client.authenticate(userId: 'u');
    platform.emit({
      'type': 'auth_success',
      'payload': {
        'isLoginFlow': true,
        'accessToken': 'a',
        'refreshToken': 'r',
      }
    });

    final success = await auth.future;
    expect(success.isLoginFlow, true);
    expect(success.accessToken, 'a');
    expect(success.refreshToken, 'r');

    platform.close();
  });

  test('HawcxClient authenticate rejects on auth_error', () async {
    final platform = FakeHawcxPlatform();
    HawcxFlutterSdkPlatform.instance = platform;

    final client = HawcxClient(platform: platform);
    await client.initialize(HawcxConfig(projectApiKey: 'k', baseUrl: 'https://x'));

    final auth = client.authenticate(userId: 'u');
    platform.emit({
      'type': 'auth_error',
      'payload': {'code': 'NETWORK_ERROR', 'message': 'nope'}
    });

    await expectLater(
      auth.future,
      throwsA(isA<HawcxAuthException>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
    );

    platform.close();
  });

  test('HawcxClient authenticate cancel rejects with AUTH_CANCELLED', () async {
    final platform = FakeHawcxPlatform();
    HawcxFlutterSdkPlatform.instance = platform;

    final client = HawcxClient(platform: platform);
    await client.initialize(HawcxConfig(projectApiKey: 'k', baseUrl: 'https://x'));

    final auth = client.authenticate(userId: 'u');
    auth.cancel();

    await expectLater(
      auth.future,
      throwsA(isA<HawcxAuthException>().having((e) => e.code, 'code', HawcxAuthException.cancelledCode)),
    );

    platform.close();
  });

  test('HawcxClient session operations resolve on session_success', () async {
    final platform = FakeHawcxPlatform();
    HawcxFlutterSdkPlatform.instance = platform;

    final client = HawcxClient(platform: platform);
    await client.initialize(HawcxConfig(projectApiKey: 'k', baseUrl: 'https://x'));

    final future = client.fetchDeviceDetails();
    platform.emit({'type': 'session_success'});
    await future;

    platform.close();
  });
}

