import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../services/background/foreground_service.dart';
import '../../services/background/watchdog.dart';
import '../../services/sync/sync_engine.dart';
import '../../services/sync/sync_worker.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';
import 'test_parser_screen.dart';
import 'transaction_detail_screen.dart';
import 'transactions_list_screen.dart';

/// Main dashboard — shows service status, sync queue, and quick actions.
class DashboardScreen extends StatefulWidget {
  final AppDatabase db;
  final SyncEngine syncEngine;
  final Watchdog watchdog;

  const DashboardScreen({
    super.key,
    required this.db,
    required this.syncEngine,
    required this.watchdog,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _serviceRunning = false;
  bool _batteryExempted = false;
  int _pendingCount = 0;
  int _totalTransactions = 0;
  bool _isSyncing = false;
  DateTime? _lastCheck;
  List<SmsTransaction> _recentTransactions = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final serviceRunning = await ForegroundServiceController.isRunning();
    final batteryExempted =
        await ForegroundServiceController.isBatteryExempted();
    final pendingCount = await widget.db.getPendingSyncCount();
    final totalTx = await widget.db.getTransactionCount();
    final recent = await widget.db.getRecentTransactions(limit: 5);

    if (mounted) {
      setState(() {
        _serviceRunning = serviceRunning;
        _batteryExempted = batteryExempted;
        _pendingCount = pendingCount;
        _totalTransactions = totalTx;
        _isSyncing = widget.syncEngine.isSyncing;
        _recentTransactions = recent;
        _lastCheck = DateTime.now();
      });
    }
  }

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    await widget.syncEngine.syncAll();
    await SyncWorker.triggerImmediateSync();
    await _refresh();
  }

  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await ForegroundServiceController.stop();
    } else {
      await ForegroundServiceController.start();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _serviceRunning
                    ? BridgeTheme.success
                    : BridgeTheme.error,
              ),
            ),
            const SizedBox(width: 8),
            const Text('AMTTAI BRIDGE'),
          ],
        ),
        actions: [
          QueueIndicator(count: _pendingCount, isSyncing: _isSyncing),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: BridgeTheme.textSecondary),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logs', child: Text('View Logs')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'test', child: Text('Test Parser')),
              const PopupMenuItem(value: 'health', child: Text('Health Check')),
            ],
            onSelected: (value) {
              switch (value) {
                case 'logs':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LogsScreen(db: widget.db),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(db: widget.db),
                    ),
                  );
                  break;
                case 'test':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TestParserScreen()),
                  );
                  break;
                case 'health':
                  _runHealthCheck();
                  break;
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Status cards grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: [
                StatusCard(
                  title: 'SERVICE',
                  value: _serviceRunning ? 'ACTIVE' : 'STOPPED',
                  icon: Icons.play_circle_outline,
                  valueColor: _serviceRunning
                      ? BridgeTheme.success
                      : BridgeTheme.error,
                  onTap: _toggleService,
                ),
                StatusCard(
                  title: 'BATTERY OPT',
                  value: _batteryExempted ? 'EXEMPT' : 'ACTIVE',
                  icon: Icons.battery_full,
                  valueColor: _batteryExempted
                      ? BridgeTheme.success
                      : BridgeTheme.warning,
                  onTap: () =>
                      ForegroundServiceController.requestBatteryExemption(),
                ),
                StatusCard(
                  title: 'SYNC QUEUE',
                  value: '$_pendingCount',
                  icon: Icons.sync,
                  valueColor: _pendingCount > 0
                      ? BridgeTheme.warning
                      : BridgeTheme.success,
                ),
                StatusCard(
                  title: 'TRANSACTIONS',
                  value: '$_totalTransactions',
                  icon: Icons.receipt_long,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _forceSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BridgeTheme.background,
                            ),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(_isSyncing ? 'Syncing...' : 'Force Sync'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleService,
                    icon: Icon(
                      _serviceRunning ? Icons.stop : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(_serviceRunning ? 'Stop' : 'Start'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent transactions
            _buildSectionHeader('RECENT TRANSACTIONS'),
            const SizedBox(height: 8),
            if (_recentTransactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: BridgeTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              ..._recentTransactions.map((tx) => _buildTransactionTile(context, tx)),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsListScreen(db: widget.db),
                      ),
                    );
                  },
                  child: const Text('View All Transactions'),
                ),
              ),
            ],

            if (_lastCheck != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Last refresh: ${DateFormat('HH:mm:ss').format(_lastCheck!)}',
                  style: const TextStyle(
                    color: BridgeTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildTransactionTile(BuildContext context, SmsTransaction tx) {
    final statusColor = _statusColor(tx.status);
    final time = DateFormat('MM/dd HH:mm').format(tx.createdAt);
    final isActivated = tx.status == 'synced';

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: tx),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.parsedTransactionCode ?? tx.sender,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.parsedAmount != null ? "${tx.parsedAmount} MNT" : "parsing..."} • $time',
                      style: const TextStyle(
                        color: BridgeTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActivated) ...[
                      Icon(Icons.check_circle, size: 10, color: statusColor),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      isActivated ? 'ACTIVATED' : tx.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'synced':
        return BridgeTheme.success;
      case 'matched':
      case 'parsed':
        return BridgeTheme.primary;
      case 'failed':
        return BridgeTheme.error;
      case 'duplicate':
        return BridgeTheme.textMuted;
      default:
        return BridgeTheme.warning;
    }
  }

  void _runHealthCheck() async {
    final report = await widget.watchdog.check();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Health Report'),
          content: Text(
            'Service: ${report.serviceRunning ? "✅" : "❌"}\n'
            'Battery Exempt: ${report.batteryExempted ? "✅" : "❌"}\n'
            'Pending Sync: ${report.pendingSyncCount}\n'
            'Total Transactions: ${report.transactionCount}\n'
            'Overall: ${report.healthy ? "✅ Healthy" : "⚠️ Issues"}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
