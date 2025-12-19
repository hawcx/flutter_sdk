# Hawcx Flutter SDK

Flutter plugin for Hawcx V5 authentication, device verification, web sessions, and push approvals.  
This SDK delegates all crypto and network flows to the existing native Hawcx SDKs on iOS and Android.

## Requirements

- Flutter >= 3.19 (Dart >= 3.3)
- iOS 17+ / Android 8+ (Android minSdk 26)
- OAuth client credentials must stay on your backend

## Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  hawcx_flutter_sdk: ^1.0.2
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
`https://raw.githubusercontent.com/hawcx/hawcx_android_sdk/main/maven` (public).

Minimum supported Android SDK is API 26.

Add the repository to your app’s Gradle repositories (typically `android/settings.gradle` or `android/build.gradle`, depending on your Gradle setup):

```gradle
repositories {
    maven {
        url = uri("https://raw.githubusercontent.com/hawcx/hawcx_android_sdk/main/maven")
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

## Quick Start

```dart
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

final client = HawcxClient();
await client.initialize(HawcxConfig(
  projectApiKey: '<PROJECT_API_KEY>',
  baseUrl: 'https://your-hawcx-host.example.com',
));

final auth = client.authenticate(
  userId: 'user@example.com',
  onOtpRequired: () {
    // prompt user
  },
  onAuthorizationCode: (payload) async {
    // Forward payload.code to your backend to exchange for tokens.
    // Then persist the resulting tokens into the native secure store:
    // await client.storeBackendOAuthTokens(
    //   userId: 'user@example.com',
    //   accessToken: '<access>',
    //   refreshToken: '<refresh>',
    // );
  },
);

// later, when OTP entered:
await client.submitOtp('123456');

final success = await auth.future;
// success.isLoginFlow, success.accessToken, success.refreshToken
```

> Note: `baseUrl` must be the tenant-specific Hawcx host (for example, `https://hawcx-api.hawcx.com`). The native SDK appends `/hc_auth` internally.

### Authentication flow (OTP + authorization code)

The SDK returns an authorization code after Hawcx authentication completes. Your frontend must send the code to your backend and redeem it using the OAuth client credentials issued for your project. Never ship `clientId`, token endpoints, or private keys inside the mobile app.

After your backend responds, call `storeBackendOAuthTokens(userId, accessToken, refreshToken)` so Hawcx can securely store tokens and manage device sessions.

### Backend exchange (server-side)

Redeem the authorization code on your backend using the Hawcx OAuth client or your preferred language SDK. Example (Node/Express):

```ts
import express from 'express';
import { exchangeCodeForTokenAndClaims } from '@hawcx/oauth-client';

const app = express();
app.use(express.json());

app.post('/api/hawcx/login', async (req, res) => {
  const { email, code, expires_in } = req.body ?? {};
  if (!email || !code) {
    return res.status(400).json({ success: false, error: 'Missing email or code' });
  }

  try {
    const [claims, idToken] = await exchangeCodeForTokenAndClaims({
      code,
      oauthTokenUrl: process.env.HAWCX_OAUTH_TOKEN_ENDPOINT,
      clientId: process.env.HAWCX_OAUTH_CLIENT_ID,
      publicKey: process.env.HAWCX_OAUTH_PUBLIC_KEY_PEM,
      audience: process.env.HAWCX_OAUTH_CLIENT_ID,
      issuer: process.env.HAWCX_OAUTH_ISSUER,
    });

    return res.json({
      success: true,
      message: `Verified ${claims.email}`,
      access_token: idToken,
      refresh_token: idToken,
    });
  } catch (error) {
    return res.status(401).json({ success: false, error: error.message });
  }
});
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

## Support

- Documentation: https://docs.hawcx.com
- Questions? Reach out to your Hawcx solutions engineer or support@hawcx.com.
