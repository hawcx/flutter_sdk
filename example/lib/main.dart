import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

void main() {
  runApp(const HawcxExampleApp());
}

class HawcxExampleApp extends StatelessWidget {
  const HawcxExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hawcx Flutter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HawcxExampleHome(),
    );
  }
}

class HawcxExampleHome extends StatefulWidget {
  const HawcxExampleHome({super.key});

  @override
  State<HawcxExampleHome> createState() => _HawcxExampleHomeState();
}

class _HawcxExampleHomeState extends State<HawcxExampleHome> {
  final HawcxClient _client = HawcxClient();

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://api.hawcx.com',
  );
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _webPinController = TextEditingController();
  final TextEditingController _webTokenController = TextEditingController();
  final TextEditingController _pushTokenController = TextEditingController();
  final TextEditingController _pushPayloadController = TextEditingController(
    text: '{"request_id":"<request_id>"}',
  );
  final TextEditingController _pushRequestIdController = TextEditingController();

  StreamSubscription<HawcxEvent>? _eventsSub;

  bool _initialized = false;
  HawcxAuthHandle? _authHandle;
  String? _lastPushRequestId;
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _eventsSub = _client.events.listen(
        _onEvent,
        onError: (Object error, StackTrace stack) {
          _appendLog('Event stream error: $error');
        },
      );
    } else {
      _appendLog(
        'This example is intended for iOS/Android. Current platform: '
        '${kIsWeb ? 'web' : defaultTargetPlatform}',
      );
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _userIdController.dispose();
    _otpController.dispose();
    _webPinController.dispose();
    _webTokenController.dispose();
    _pushTokenController.dispose();
    _pushPayloadController.dispose();
    _pushRequestIdController.dispose();
    super.dispose();
  }

  void _appendLog(String line) {
    setState(() {
      final timestamp = DateTime.now().toIso8601String();
      _logs.insert(0, '[$timestamp] $line');
    });
  }

  void _onEvent(HawcxEvent event) {
    _appendLog(_describeEvent(event));

    if (event is PushLoginRequestEvent) {
      _lastPushRequestId = event.payload.requestId;
      _pushRequestIdController.text = event.payload.requestId;
    }
  }

  String _describeEvent(HawcxEvent event) {
    switch (event) {
      case AuthOtpRequiredEvent():
        return 'Auth: otp_required';
      case AuthSuccessEvent(:final payload):
        return 'Auth: auth_success isLoginFlow=${payload.isLoginFlow} '
            'accessToken=${payload.accessToken != null ? '<present>' : '<null>'} '
            'refreshToken=${payload.refreshToken != null ? '<present>' : '<null>'}';
      case AuthErrorEvent(:final payload):
        return 'Auth: auth_error code=${payload.code} message=${payload.message}';
      case AuthorizationCodeEvent(:final payload):
        return 'Auth: authorization_code code=${payload.code} expiresIn=${payload.expiresIn}';
      case AdditionalVerificationRequiredEvent(:final payload):
        return 'Auth: additional_verification_required sessionId=${payload.sessionId} detail=${payload.detail}';
      case SessionSuccessEvent():
        return 'Session: session_success';
      case SessionErrorEvent(:final payload):
        return 'Session: session_error code=${payload.code} message=${payload.message}';
      case PushLoginRequestEvent(:final payload):
        return 'Push: push_login_request requestId=${payload.requestId} '
            'ip=${payload.ipAddress} device=${payload.deviceInfo} time=${payload.timestamp} '
            'location=${payload.location}';
      case PushErrorEvent(:final payload):
        return 'Push: push_error code=${payload.code} message=${payload.message}';
      case HawcxUnknownEvent(:final type):
        return 'Unknown: $type';
    }
  }

  Future<void> _runGuarded(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      _appendLog('Error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _initialize() {
    return _runGuarded(() async {
      final config = HawcxConfig(
        projectApiKey: _apiKeyController.text,
        baseUrl: _baseUrlController.text,
      );
      await _client.initialize(config);
      setState(() => _initialized = true);
      _appendLog('Initialized');
    });
  }

  Future<void> _authenticate() {
    return _runGuarded(() async {
      final userId = _userIdController.text;
      _authHandle = _client.authenticate(
        userId: userId,
        onOtpRequired: () => _appendLog('Auth: OTP required'),
        onAuthorizationCode: (payload) {
          _appendLog('Auth: Authorization code received (${payload.code})');
        },
        onAdditionalVerificationRequired: (payload) {
          _appendLog('Auth: Additional verification required (${payload.sessionId})');
        },
      );
      _appendLog('Auth: started for userId=$userId');

      final result = await _authHandle!.future;
      _appendLog('Auth: completed isLoginFlow=${result.isLoginFlow}');
    });
  }

  Future<void> _submitOtp() {
    return _runGuarded(() async {
      await _client.submitOtp(_otpController.text);
      _appendLog('Auth: submitOtp called');
    });
  }

  Future<void> _webLogin() {
    return _runGuarded(() async {
      await _client.webLogin(_webPinController.text);
      _appendLog('Web: webLogin completed');
    });
  }

  Future<void> _webApprove() {
    return _runGuarded(() async {
      await _client.webApprove(_webTokenController.text);
      _appendLog('Web: webApprove completed');
    });
  }

  Future<void> _setPushToken() {
    return _runGuarded(() async {
      await _client.setPushDeviceToken(_pushTokenController.text);
      _appendLog('Push: token registered');
    });
  }

  Future<void> _notifyUserAuthenticated() {
    return _runGuarded(() async {
      await _client.notifyUserAuthenticated();
      _appendLog('Push: notifyUserAuthenticated called');
    });
  }

  Future<void> _handlePushPayload() {
    return _runGuarded(() async {
      final raw = _pushPayloadController.text.trim();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw ArgumentError('Push payload must decode to a JSON object');
      }
      final payload = <String, Object?>{};
      decoded.forEach((key, value) {
        payload[key.toString()] = value as Object?;
      });
      final handled = await _client.handlePushNotification(payload);
      _appendLog('Push: handlePushNotification handled=$handled');
    });
  }

  Future<void> _approvePush() {
    return _runGuarded(() async {
      await _client.approvePushRequest(_pushRequestIdController.text);
      _appendLog('Push: approvePushRequest sent');
    });
  }

  Future<void> _declinePush() {
    return _runGuarded(() async {
      await _client.declinePushRequest(_pushRequestIdController.text);
      _appendLog('Push: declinePushRequest sent');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hawcx Flutter Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Clear log',
            onPressed: () => setState(_logs.clear),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This example is intended for iOS/Android.\n'
                      'Current platform: ${kIsWeb ? 'web' : defaultTargetPlatform}',
                    ),
                  ),
                ),
              _section(
                title: 'Config',
                children: [
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Project API Key',
                      hintText: 'Enter your Hawcx project api key',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.hawcx.com',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isMobile ? _initialize : null,
                    child: Text(_initialized ? 'Initialized' : 'Initialize'),
                  ),
                ],
              ),
              _section(
                title: 'Authenticate',
                children: [
                  TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      hintText: 'user@example.com',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isMobile && _initialized ? _authenticate : null,
                    child: const Text('Authenticate'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      hintText: '123456',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isMobile && _initialized ? _submitOtp : null,
                    child: const Text('Submit OTP'),
                  ),
                ],
              ),
              _section(
                title: 'Web Sessions',
                children: [
                  TextField(
                    controller: _webPinController,
                    decoration: const InputDecoration(
                      labelText: 'Web PIN',
                      hintText: 'PIN from web login screen',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isMobile && _initialized ? _webLogin : null,
                    child: const Text('Web Login'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Web Approve Token',
                      hintText: 'Token from web approve screen',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isMobile && _initialized ? _webApprove : null,
                    child: const Text('Web Approve'),
                  ),
                ],
              ),
              _section(
                title: 'Push',
                children: [
                  Text(
                    'For quick validation you can paste tokens/payloads manually.\n'
                    'iOS: provide APNs token as base64 or hex string.\n'
                    'Android: provide FCM token as string.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pushTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Push Device Token',
                      hintText: 'APNs (base64/hex) or FCM token',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isMobile && _initialized ? _setPushToken : null,
                          child: const Text('Register Token'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isMobile && _initialized
                              ? _notifyUserAuthenticated
                              : null,
                          child: const Text('Notify Authenticated'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pushPayloadController,
                    decoration: const InputDecoration(
                      labelText: 'Push Payload (JSON)',
                      hintText: '{"request_id":"..."}',
                    ),
                    minLines: 3,
                    maxLines: 6,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isMobile && _initialized ? _handlePushPayload : null,
                    child: const Text('Handle Push Payload'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pushRequestIdController,
                    decoration: InputDecoration(
                      labelText: 'Push Request ID',
                      hintText: _lastPushRequestId ?? '<requestId>',
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isMobile && _initialized ? _approvePush : null,
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isMobile && _initialized ? _declinePush : null,
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _section(
                title: 'Log',
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _logs.isEmpty
                        ? const Text('No events yet.')
                        : SelectableText(_logs.take(80).join('\n\n')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

