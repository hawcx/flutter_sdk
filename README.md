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

The plugin links the Hawcx iOS SDK as a vendored xcframework (`ios/Frameworks/HawcxFramework.xcframework`).

- If you’re consuming the published package, the release artifact must include the xcframework.
- If you’re developing locally, follow `docs/RELEASE.md` for how to refresh the xcframework before running `pod install`.

## Usage (preview)

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

The full API surface (push handling, richer session/device models, example apps) will be expanded in subsequent phases.  
See `flutter_mobile_sdk_plan.md` for the delivery roadmap.
