# Hawcx Flutter SDK

Flutter plugin for Hawcx V5 authentication, device verification, web sessions, and push approvals.  
This SDK delegates all crypto and network flows to the existing native Hawcx SDKs on iOS and Android.

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hawcx_flutter_sdk: ^0.0.1
```

Then:

```bash
flutter pub get
```

## Example App

See `example/` for a runnable iOS/Android app that exercises initialization, auth/OTP, web sessions, and push handling.

## Native Setup

### Android

The plugin depends on the Hawcx Android SDK published from:
`https://raw.githubusercontent.com/hawcx/hawcx_android_sdk/main/maven`.

Add the repository to your app’s Gradle repositories (typically `android/settings.gradle` or `android/build.gradle`, depending on your Gradle setup):

```gradle
repositories {
    maven {
        url = uri("https://raw.githubusercontent.com/hawcx/hawcx_android_sdk/main/maven")
        // For private access, configure a GitHub token with read permissions.
        credentials {
            username = System.getenv("GITHUB_USER") ?: "<github-username>"
            password = System.getenv("GITHUB_TOKEN") ?: "<github-token>"
        }
        metadataSources {
            mavenPom()
            artifact()
        }
    }
    google()
    mavenCentral()
}
```

### iOS

The plugin links the Hawcx iOS SDK as a vendored xcframework (`ios/Frameworks/HawcxFramework.xcframework`) bundled with the plugin.

If you’re consuming the published package, no additional CocoaPods setup is required beyond running `pod install` in your app’s `ios/` directory.

## Usage

```dart
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

final client = HawcxClient();
await client.initialize(HawcxConfig(
  projectApiKey: '<PROJECT_API_KEY>',
  baseUrl: 'https://api.hawcx.com',
));

final auth = client.authenticate(
  userId: 'user@example.com',
  onOtpRequired: () {
    // prompt user
  },
  onAuthorizationCode: (payload) async {
    // If you use a backend OAuth exchange flow, send payload.code to your backend.
    // Then persist the resulting tokens into the native secure store:
    // await client.storeBackendOAuthTokens(userId: 'user@example.com', accessToken: '<access>', refreshToken: '<refresh>');
  },
);

// later, when OTP entered:
await client.submitOtp('123456');

final success = await auth.future;
// success.isLoginFlow, success.accessToken, success.refreshToken
```

## Web Sessions

```dart
await client.webLogin('123456');
await client.webApprove('<web-token>');
```

`webLogin` / `webApprove` emit `session_success` or `session_error` events on the shared event stream.

## Push Notifications

Register a device token, forward push payloads to Hawcx, and listen for Hawcx push events.

### Register Device Token

Expose your platform token (APNs on iOS, FCM on Android) and register it with Hawcx:

```dart
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> registerHawcxPushToken(HawcxClient client) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    if (apnsToken != null) {
      await client.setPushDeviceToken(apnsToken);
    }
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await client.setPushDeviceToken(fcmToken);
    }
  }
}
```

### Forward Push Payloads

When your app receives a push, forward the payload to Hawcx so it can emit Hawcx events:

```dart
final handled = await client.handlePushNotification(
  Map<String, Object?>.from(message.data),
);
```

### Handle Hawcx Push Events

```dart
client.pushEvents.listen((event) async {
  switch (event) {
    case PushLoginRequestEvent(:final payload):
      // Show UI and call one of:
      await client.approvePushRequest(payload.requestId);
      // await client.declinePushRequest(payload.requestId);
      break;
    case PushErrorEvent(:final payload):
      // payload.code, payload.message
      break;
  }
});
```

After your user signs in successfully, call:

```dart
await client.notifyUserAuthenticated();
```
