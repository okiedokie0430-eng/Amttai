
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/app_database.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Log viewer screen with level filtering and export.
class LogsScreen extends StatefulWidget {
  final AppDatabase db;

  const LogsScreen({super.key, required this.db});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> _logs = [];
  String? _levelFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await widget.db.getRecentLogs(
      limit: 200,
      levelFilter: _levelFilter,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logs = await widget.db.getRecentLogs(limit: 1000);
      final buffer = StringBuffer();
      buffer.writeln('Amttai Payment Bridge Logs');
      buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
      buffer.writeln('=' * 60);

      for (final log in logs) {
        final time =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt);
        buffer.writeln(
            '[$time] [${log.level.toUpperCase()}] [${log.tag}] ${log.message}');
        if (log.metadata != null) {
          buffer.writeln('  META: ${log.metadata}');
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/bridge_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Bridge Logs',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOGS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, size: 20),
            onPressed: _exportLogs,
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              await widget.db.clearLogs();
              _loadLogs();
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          // Level filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              children: [
                _filterChip('ALL', null),
                _filterChip('ERROR', 'error'),
                _filterChip('WARN', 'warn'),
                _filterChip('INFO', 'info'),
                _filterChip('DEBUG', 'debug'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log entries
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2))
                : _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs',
                          style: TextStyle(
                              color: BridgeTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (_, i) {
                          final log = _logs[i];
                          return LogTile(
                            level: log.level,
                            tag: log.tag,
                            message: log.message,
                            createdAt: log.createdAt,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? level) {
    final selected = _levelFilter == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected
                  ? BridgeTheme.background
                  : BridgeTheme.textSecondary,
            )),
        selected: selected,
        selectedColor: BridgeTheme.primary,
        backgroundColor: BridgeTheme.surfaceLight,
        side: BorderSide(
          color: selected ? BridgeTheme.primary : BridgeTheme.border,
        ),
        onSelected: (_) {
          setState(() => _levelFilter = level);
          _loadLogs();
        },
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
