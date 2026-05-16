import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../../settings/settings_manager.dart';
import '../../core/security/device_binding.dart';
import '../../services/native/native_bridge_controller.dart';
import '../theme.dart';

/// Settings editor screen.
class SettingsScreen extends StatefulWidget {
  final AppDatabase db;

  const SettingsScreen({super.key, required this.db});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsManager _manager;
  late BridgeSettings _settings;
  bool _loading = true;
  bool _dirty = false;

  // Controllers
  late TextEditingController _apiKeyController;
  late TextEditingController _smsTemplateController;
  late TextEditingController _sendersController;
  late TextEditingController _targetUserIdsController;
  late TextEditingController _toleranceController;
  late TextEditingController _retryBaseController;
  late TextEditingController _retryMaxController;
  late TextEditingController _retryAttemptsController;
  late TextEditingController _heartbeatController;
  late TextEditingController _syncIntervalController;
  late TextEditingController _logRetentionController;

  @override
  void initState() {
    super.initState();
    _manager = SettingsManager(widget.db);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _manager.load();
    _settings = _manager.current;

    final apiKey = await DeviceBinding.getApiKey();
    _apiKeyController = TextEditingController(text: apiKey ?? '');

    _smsTemplateController = TextEditingController(text: _settings.smsTemplate);

    _sendersController = TextEditingController(
      text: _settings.trustedSenders.join('\n'),
    );
    _targetUserIdsController = TextEditingController(
      text: _settings.targetUserIds.join('\n'),
    );
    _toleranceController = TextEditingController(
      text: _settings.amountTolerance.toString(),
    );
    _retryBaseController = TextEditingController(
      text: (_settings.retryBaseDelayMs ~/ 1000).toString(),
    );
    _retryMaxController = TextEditingController(
      text: (_settings.retryMaxDelayMs ~/ 1000).toString(),
    );
    _retryAttemptsController = TextEditingController(
      text: _settings.retryMaxAttempts.toString(),
    );
    _heartbeatController = TextEditingController(
      text: _settings.heartbeatIntervalMinutes.toString(),
    );
    _syncIntervalController = TextEditingController(
      text: _settings.syncIntervalMinutes.toString(),
    );
    _logRetentionController = TextEditingController(
      text: _settings.logRetentionDays.toString(),
    );

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final senders = _sendersController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final targetUserIds = _targetUserIdsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (_apiKeyController.text.isNotEmpty) {
      await DeviceBinding.setApiKey(_apiKeyController.text.trim());
    }

    _settings = _settings.copyWith(
      trustedSenders: senders,
      targetUserIds: targetUserIds,
      smsTemplate: _smsTemplateController.text.trim(),
      amountTolerance:
          int.tryParse(_toleranceController.text) ?? _settings.amountTolerance,
      retryBaseDelayMs: (int.tryParse(_retryBaseController.text) ?? 30) * 1000,
      retryMaxDelayMs: (int.tryParse(_retryMaxController.text) ?? 1800) * 1000,
      retryMaxAttempts:
          int.tryParse(_retryAttemptsController.text) ??
          _settings.retryMaxAttempts,
      heartbeatIntervalMinutes:
          int.tryParse(_heartbeatController.text) ??
          _settings.heartbeatIntervalMinutes,
      syncIntervalMinutes:
          int.tryParse(_syncIntervalController.text) ??
          _settings.syncIntervalMinutes,
      logRetentionDays:
          int.tryParse(_logRetentionController.text) ??
          _settings.logRetentionDays,
    );

    await _manager.update(_settings);
    await NativeBridgeController.syncSettings(_settings);
    setState(() => _dirty = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: BridgeTheme.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionTitle('CREDENTIALS'),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Appwrite API Key',
              hintText: 'Paste secret API key here',
            ),
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 20),

          _sectionTitle('TRUSTED SMS SENDERS'),
          const SizedBox(height: 6),
          TextField(
            controller: _sendersController,
            maxLines: 4,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'One sender per line\ne.g., Golomt, 1800',
            ),
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 20),

          _sectionTitle('TARGET USER IDS'),
          const SizedBox(height: 6),
          TextField(
            controller: _targetUserIdsController,
            maxLines: 4,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Optional allow-list, one user ID per line',
            ),
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 20),

          _sectionTitle('DIRECT USER ID PARSING'),
          const SizedBox(height: 6),
          TextField(
            controller: _smsTemplateController,
            maxLines: 4,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText:
                  'e.g. ...Utga: AMTTAI-{DURATION}-{USER_ID} Uldegdel: {BALANCE}',
            ),
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: 20),

          _sectionTitle('PAYMENT MATCHING'),
          const SizedBox(height: 6),
          _numberField('Amount Tolerance (MNT)', _toleranceController),
          const SizedBox(height: 20),

          _sectionTitle('RETRY POLICY'),
          const SizedBox(height: 6),
          _numberField('Base Delay (seconds)', _retryBaseController),
          const SizedBox(height: 8),
          _numberField('Max Delay (seconds)', _retryMaxController),
          const SizedBox(height: 8),
          _numberField('Max Attempts', _retryAttemptsController),
          const SizedBox(height: 20),

          _sectionTitle('SCHEDULING'),
          const SizedBox(height: 6),
          _numberField('Sync Interval (minutes)', _syncIntervalController),
          const SizedBox(height: 8),
          _numberField('Heartbeat Interval (minutes)', _heartbeatController),
          const SizedBox(height: 8),
          _numberField('Log Retention (days)', _logRetentionController),
          const SizedBox(height: 20),

          _sectionTitle('FEATURE FLAGS'),
          const SizedBox(height: 6),
          _switchTile(
            'Strict Mode',
            'Reject ambiguous SMS parses',
            _settings.strictMode,
            (v) {
              setState(() => _settings = _settings.copyWith(strictMode: v));
              _markDirty();
            },
          ),
          _switchTile(
            'Foreground Service',
            'Keep persistent notification',
            _settings.foregroundServiceEnabled,
            (v) {
              setState(
                () =>
                    _settings = _settings.copyWith(foregroundServiceEnabled: v),
              );
              _markDirty();
            },
          ),
          _switchTile(
            'Fallback Parsing',
            'Try fallback regex patterns',
            _settings.fallbackParsingEnabled,
            (v) {
              setState(
                () => _settings = _settings.copyWith(fallbackParsingEnabled: v),
              );
              _markDirty();
            },
          ),
          const SizedBox(height: 24),

          OutlinedButton(
            onPressed: () async {
              await _manager.update(BridgeSettings.defaults());
              _loadSettings();
            },
            child: const Text('Reset to Defaults'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: BridgeTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => _markDirty(),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: BridgeTheme.textSecondary,
          ),
        ),
        value: value,
        onChanged: onChanged,
        dense: true,
      ),
    );
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _smsTemplateController.dispose();
    _sendersController.dispose();
    _targetUserIdsController.dispose();
    _toleranceController.dispose();
    _retryBaseController.dispose();
    _retryMaxController.dispose();
    _retryAttemptsController.dispose();
    _heartbeatController.dispose();
    _syncIntervalController.dispose();
    _logRetentionController.dispose();
    super.dispose();
  }
}
