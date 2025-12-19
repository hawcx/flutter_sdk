import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

/// Keep test credentials in one place for the example app.
const String hawcxProjectApiKey = 'ceasar2';
const String hawcxBaseUrl = 'https://ceasar-api.hawcx.com';

HawcxConfig? _buildDefaultConfig() {
  final trimmedKey = hawcxProjectApiKey.trim();
  if (trimmedKey.isEmpty) {
    return null;
  }
  final trimmedBase = hawcxBaseUrl.trim();
  if (trimmedBase.isEmpty) {
    return null;
  }
  return HawcxConfig(projectApiKey: trimmedKey, baseUrl: trimmedBase);
}

final HawcxConfig? defaultHawcxConfig = _buildDefaultConfig();
