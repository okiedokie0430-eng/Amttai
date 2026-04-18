import 'package:flutter/material.dart';

import 'src/forwarder_engine.dart';
import 'src/sms_listener_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmsForwarderApp());
}

class SmsForwarderApp extends StatelessWidget {
  const SmsForwarderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMS Forwarder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A75)),
      ),
      home: const ForwarderHomePage(),
    );
  }
}

class ForwarderHomePage extends StatefulWidget {
  const ForwarderHomePage({super.key});

  @override
  State<ForwarderHomePage> createState() => _ForwarderHomePageState();
}

class _ForwarderHomePageState extends State<ForwarderHomePage> {
  bool _permissionGranted = false;
  bool _enabled = true;
  bool _loading = true;
  String _status = 'Starting...';
  List<String> _logs = const [];

  final TextEditingController _senderController = TextEditingController(
    text: 'GOLOMT,SocialPay,151515',
  );
  final TextEditingController _bodyController = TextEditingController(
    text:
        'AMTTAI-SP-ONEMONTH-123456 төлбөр амжилттай. Amount: 9000 MNT. Success',
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _status = 'Requesting SMS permission...';
    });

    final permission = await SmsListenerService.requestPermissions();
    _permissionGranted = permission;

    if (permission) {
      await SmsListenerService.start();
      _status = 'Listening for incoming SMS';
    } else {
      _status = 'SMS permission denied';
    }

    _enabled = await ForwarderEngine.isEnabled();
    _logs = await ForwarderEngine.readLogs();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    await ForwarderEngine.setEnabled(value);
    final updatedLogs = await ForwarderEngine.readLogs();
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _logs = updatedLogs;
      _status = value ? 'Forwarding active' : 'Forwarding paused';
    });
  }

  Future<void> _simulateMessage() async {
    setState(() {
      _status = 'Running simulation...';
    });

    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();
    final outcome = await ForwarderEngine.processRawMessage(
      body: body,
      sender: sender,
      source: 'simulation',
    );

    final updatedLogs = await ForwarderEngine.readLogs();
    if (!mounted) return;

    setState(() {
      _logs = updatedLogs;
      _status = outcome.summary;
    });
  }

  Future<void> _clearLogs() async {
    await ForwarderEngine.clearLogs();
    if (!mounted) return;
    setState(() {
      _logs = const [];
      _status = 'Logs cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Payment Forwarder')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _bootstrap,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Runtime status',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(_status),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _permissionGranted
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _permissionGranted
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _permissionGranted
                                    ? 'SMS permission granted'
                                    : 'SMS permission missing',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable forwarding'),
                            subtitle: const Text(
                              'When off, incoming SMS will be ignored.',
                            ),
                            value: _enabled,
                            onChanged: _toggleEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick simulation',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _senderController,
                            decoration: const InputDecoration(
                              labelText: 'Sender (example: GOLOMT or 151515)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bodyController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'SMS body',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _simulateMessage,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Simulate and send'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent logs',
                                style: theme.textTheme.titleMedium,
                              ),
                              TextButton(
                                onPressed: _clearLogs,
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_logs.isEmpty)
                            const Text('No logs yet.')
                          else
                            ..._logs.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(line),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
