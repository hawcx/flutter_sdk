class HawcxOAuthConfig {
  HawcxOAuthConfig({
    required String tokenEndpoint,
    required String clientId,
    required String publicKeyPem,
  })  : tokenEndpoint = tokenEndpoint.trim(),
        clientId = clientId.trim(),
        publicKeyPem = publicKeyPem.trim() {
    if (this.tokenEndpoint.isEmpty) {
      throw ArgumentError('tokenEndpoint is required');
    }
    if (this.clientId.isEmpty) {
      throw ArgumentError('clientId is required');
    }
    if (this.publicKeyPem.isEmpty) {
      throw ArgumentError('publicKeyPem is required');
    }
  }

  final String tokenEndpoint;
  final String clientId;
  final String publicKeyPem;

  Map<String, Object?> toMap() => {
        'tokenEndpoint': tokenEndpoint,
        'clientId': clientId,
        'publicKeyPem': publicKeyPem,
      };
}

class HawcxEndpoints {
  HawcxEndpoints({required String authBaseUrl}) : authBaseUrl = authBaseUrl.trim() {
    if (this.authBaseUrl.isEmpty) {
      throw ArgumentError('authBaseUrl is required');
    }
  }

  final String authBaseUrl;

  Map<String, Object?> toMap() => {
        'authBaseUrl': authBaseUrl,
      };
}

class HawcxConfig {
  HawcxConfig({
    required String projectApiKey,
    required String baseUrl,
    HawcxOAuthConfig? oauthConfig,
    HawcxEndpoints? endpoints,
  })  : projectApiKey = projectApiKey.trim(),
        baseUrl = baseUrl.trim(),
        oauthConfig = oauthConfig,
        endpoints = endpoints {
    if (this.projectApiKey.isEmpty) {
      throw ArgumentError('projectApiKey is required');
    }
    if (this.baseUrl.isEmpty && endpoints == null) {
      throw ArgumentError('baseUrl is required (or provide endpoints.authBaseUrl)');
    }
  }

  final String projectApiKey;
  final String baseUrl;
  final HawcxOAuthConfig? oauthConfig;
  final HawcxEndpoints? endpoints;

  Map<String, Object?> toMap() => {
        'projectApiKey': projectApiKey,
        if (baseUrl.isNotEmpty) 'baseUrl': baseUrl,
        if (oauthConfig != null) 'oauthConfig': oauthConfig!.toMap(),
        if (endpoints != null) 'endpoints': endpoints!.toMap(),
      };
}

