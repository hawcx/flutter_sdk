import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hawcx_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return null;
        case 'authenticateV5':
          return <String, Object?>{'status': 'ok'};
        case 'submitOtpV5':
          return <String, Object?>{'token': 't'};
        case 'getDeviceDetails':
          return <String, Object?>{'deviceId': 'd'};
        case 'setPushToken':
          return null;
        case 'handlePushNotification':
          return null;
        default:
          throw PlatformException(
            code: 'unimplemented',
            message: 'No mock for ${call.method}',
          );
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize validates apiKey', () async {
    expect(
      () => HawcxFlutterSdk.initialize(apiKey: ''),
      throwsArgumentError,
    );
  });

  test('initialize sends args', () async {
    MethodCall? last;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      last = call;
      return null;
    });

    await HawcxFlutterSdk.initialize(
      apiKey: 'k',
      baseUrl: 'https://example.com',
      oauthConfig: <String, dynamic>{'clientId': 'c'},
    );

    expect(last?.method, 'initialize');
    expect(last?.arguments, <String, Object?>{
      'apiKey': 'k',
      'baseUrl': 'https://example.com',
      'oauthConfig': <String, Object?>{'clientId': 'c'},
    });
  });

  test('authenticateV5 sends userId and returns map', () async {
    MethodCall? last;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      last = call;
      return <String, Object?>{'status': 'ok'};
    });

    final res = await HawcxFlutterSdk.authenticateV5(userId: 'u');
    expect(last?.method, 'authenticateV5');
    expect(last?.arguments, <String, Object?>{'userId': 'u'});
    expect(res, <String, dynamic>{'status': 'ok'});
  });

  test('submitOtpV5 validates args', () async {
    expect(
      () => HawcxFlutterSdk.submitOtpV5(otp: '', userId: 'u'),
      throwsArgumentError,
    );
    expect(
      () => HawcxFlutterSdk.submitOtpV5(otp: '1', userId: ''),
      throwsArgumentError,
    );
  });

  test('getDeviceDetails returns map', () async {
    final res = await HawcxFlutterSdk.getDeviceDetails();
    expect(res, <String, dynamic>{'deviceId': 'd'});
  });

  test('setPushToken validates token', () async {
    expect(
      () => HawcxFlutterSdk.setPushToken(token: '', platform: 'ios'),
      throwsArgumentError,
    );
  });

  test('handlePushNotification forwards payload', () async {
    MethodCall? last;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      last = call;
      return null;
    });

    await HawcxFlutterSdk.handlePushNotification(<String, dynamic>{
      'aps': <String, dynamic>{'alert': 'hi'},
    });

    expect(last?.method, 'handlePushNotification');
    expect(last?.arguments, <String, Object?>{
      'aps': <String, Object?>{'alert': 'hi'},
    });
  });
}


