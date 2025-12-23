# Changelog

## [1.0.3] - 2025-12-22
- Add MFA initiate/verify HTTP methods for mobile auth flow
- Auto-trigger MFA OTP send after cipher verification
- Add resendMfaOtp() and verifyMfaOtp() public methods
- Store session state (_currentUserId, _currentSessionId) for MFA flow
- Call /hc_auth/v5/mfa/initiate and /mfa/verify endpoints directly
- Add MfaInitiateResult and MfaVerifyResult response classes
- Add http dependency for API calls

## [1.0.2] - 2025-12-19
- Prepping Release v1.0.2
- Fixed podspec file

## [1.0.1] - 2025-12-19
- Prepping Release v1.0.1

## [0.0.1] - 2025-12-19
- Initial scaffold of Hawcx Flutter SDK plugin.
- Added Dart `HawcxClient`, typed config/models, and typed native event parsing.
- Added session/web/OAuth event helpers and expanded unit test coverage.
- Added push token helpers and push event handling APIs.
- Added a production-ready `example/` app for iOS/Android validation.