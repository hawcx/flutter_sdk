import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hawcx_flutter_sdk/hawcx_flutter_sdk.dart';

import 'hawcx_config.dart';

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

  final TextEditingController _userIdController =
      TextEditingController(text: 'user@example.com');
  final TextEditingController _otpController = TextEditingController();

  StreamSubscription<HawcxEvent>? _eventsSub;

  bool _initialized = false;
  bool _authInProgress = false;
  bool _otpRequired = false;
  String? _initError;
  String? _statusMessage;
  bool _statusIsError = false;
  HawcxAuthHandle? _authHandle;
  bool _suppressCancelMessage = false;
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
      if (defaultHawcxConfig == null) {
        _initError =
            'Missing Hawcx config. Update example/lib/hawcx_config.dart.';
        _appendLog(_initError!);
        _setStatus(_initError!, isError: true);
      } else {
        _initialize();
      }
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
    _userIdController.dispose();
    _otpController.dispose();
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

    switch (event) {
      case AuthOtpRequiredEvent():
        setState(() => _otpRequired = true);
        _setStatus('OTP required', isError: false);
        break;
      case AuthSuccessEvent():
        _setStatus('Authentication complete (tokens stored by SDK).',
            isError: false);
        _endAuthFlow();
        break;
      case AuthErrorEvent(:final payload):
        _setStatus('Auth error: ${payload.message}', isError: true);
        _endAuthFlow();
        break;
      case AuthorizationCodeEvent():
        _setStatus(
          'Authentication complete. Authorization code received — exchange via backend.',
          isError: false,
        );
        _cancelAuthFlow(suppressMessage: true);
        break;
      case AdditionalVerificationRequiredEvent(:final payload):
        _setStatus(
          'Additional verification required: ${payload.sessionId}',
          isError: true,
        );
        _cancelAuthFlow(suppressMessage: true);
        break;
      default:
        break;
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
        return 'Push: push_login_request requestId=${payload.requestId}';
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
      final config = defaultHawcxConfig;
      if (config == null) {
        _initError = 'Missing Hawcx config.';
        _appendLog(_initError!);
        _setStatus(_initError!, isError: true);
        return;
      }
      await _client.initialize(config);
      setState(() => _initialized = true);
      _appendLog('Initialized');
      _setStatus('Initialized', isError: false);
    });
  }

  Future<void> _authenticate() {
    return _runGuarded(() async {
      if (_authInProgress) {
        _appendLog('Auth already in progress.');
        _setStatus('Auth already in progress.', isError: true);
        return;
      }
      if (_initError != null) {
        _appendLog(_initError!);
        _setStatus(_initError!, isError: true);
        return;
      }
      if (!_initialized) {
        await _initialize();
      }
      final userId = _userIdController.text;
      setState(() {
        _authInProgress = true;
        _otpRequired = false;
        _statusMessage = 'Authenticating...';
        _statusIsError = false;
      });
      _otpController.clear();
      if (_authHandle != null) {
        _cancelAuthFlow(suppressMessage: true);
      }
      _authHandle = _client.authenticate(
        userId: userId,
        onOtpRequired: () {
          _appendLog('Auth: OTP required');
          setState(() => _otpRequired = true);
          _setStatus('OTP required', isError: false);
        },
        onAuthorizationCode: (payload) {
          _appendLog('Auth: Authorization code received (${payload.code})');
          _setStatus(
            'Authentication complete. Authorization code received — exchange via backend.',
            isError: false,
          );
        },
        onAdditionalVerificationRequired: (payload) {
          _appendLog(
              'Auth: Additional verification required (${payload.sessionId})');
          _setStatus(
            'Additional verification required: ${payload.sessionId}',
            isError: true,
          );
        },
      );
      _watchAuthHandle(_authHandle!);
      _appendLog('Auth: started for userId=$userId');
    });
  }

  Future<void> _submitOtp() {
    return _runGuarded(() async {
      await _client.submitOtp(_otpController.text);
      _appendLog('Auth: submitOtp called');
      _setStatus('OTP submitted. Awaiting verification...', isError: false);
    });
  }

  void _endAuthFlow() {
    setState(() {
      _authInProgress = false;
      _otpRequired = false;
    });
    _authHandle = null;
    _suppressCancelMessage = false;
  }

  void _cancelAuthFlow({required bool suppressMessage}) {
    _suppressCancelMessage = suppressMessage;
    _authHandle?.cancel();
    _authHandle = null;
    setState(() {
      _authInProgress = false;
      _otpRequired = false;
    });
  }

  void _watchAuthHandle(HawcxAuthHandle handle) {
    handle.future.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      if (error is HawcxAuthException &&
          error.code == HawcxAuthException.cancelledCode) {
        if (_suppressCancelMessage) {
          _suppressCancelMessage = false;
          return;
        }
        _appendLog('Auth cancelled.');
        _setStatus('Authentication cancelled.', isError: false);
        _endAuthFlow();
        return;
      }

      _appendLog('Auth error: $error');
      _setStatus('Auth error: $error', isError: true);
      _endAuthFlow();
    });
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
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
                    onPressed: isMobile && _initialized && !_authInProgress
                        ? _authenticate
                        : null,
                    child: const Text('Authenticate'),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusIsError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_otpRequired) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: '123456',
                      ),
                      autofillHints: const [AutofillHints.oneTimeCode],
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isMobile && _initialized ? _submitOtp : null,
                      child: const Text('Submit OTP'),
                    ),
                  ],
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
