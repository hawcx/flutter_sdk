# Hawcx Flutter SDK Example App

Minimal demo app for `hawcx_flutter_sdk` that lets you:
- initialize with `projectApiKey` + `baseUrl`
- run `authenticate` + `submitOtp`
- run `webLogin` + `webApprove`
- register push tokens and forward push payloads
- view emitted Hawcx events

## Dependency Source (Published vs Local)

By default, `example/pubspec.yaml` depends on the **published** package:
`hawcx_flutter_sdk: ^0.0.1`.

To test local changes without publishing, create `example/pubspec_overrides.yaml`
(this file is ignored by git):

```yaml
dependency_overrides:
  hawcx_flutter_sdk:
    path: ../
```

## Run

From the repo root:

```bash
cd example
flutter pub get
flutter run
```

If the Hawcx Android Maven repo is private, export credentials before running:

```bash
export GITHUB_USER="<your-github-username>"
export GITHUB_TOKEN="<your-github-token>"
```
