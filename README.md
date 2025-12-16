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

await HawcxFlutterSdk.initialize(
  apiKey: '<PROJECT_API_KEY>',
  baseUrl: 'https://api.hawcx.com',
);
```

The full API surface (authenticate/OTP, session, web login/approve, push handling) will be added in subsequent phases.  
See `flutter_mobile_sdk_plan.md` for the delivery roadmap.
