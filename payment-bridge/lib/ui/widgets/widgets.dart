import 'package:flutter/material.dart';
import '../theme.dart';

/// Reusable status card widget for the dashboard.
class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: BridgeTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: BridgeTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? BridgeTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact log entry tile.
class LogTile extends StatelessWidget {
  final String level;
  final String tag;
  final String message;
  final DateTime createdAt;

  const LogTile({
    super.key,
    required this.level,
    required this.tag,
    required this.message,
    required this.createdAt,
  });

  Color get _levelColor {
    switch (level) {
      case 'error':
        return BridgeTheme.error;
      case 'warn':
        return BridgeTheme.warning;
      case 'info':
        return BridgeTheme.primary;
      default:
        return BridgeTheme.textMuted;
    }
  }

  String get _levelIcon {
    switch (level) {
      case 'error':
        return '✖';
      case 'warn':
        return '▲';
      case 'info':
        return '●';
      default:
        return '○';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}:'
        '${createdAt.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _levelIcon,
            style: TextStyle(color: _levelColor, fontSize: 10),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: const TextStyle(
              color: BridgeTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '[$tag]',
            style: TextStyle(
              color: _levelColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BridgeTheme.textPrimary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated queue count indicator.
class QueueIndicator extends StatelessWidget {
  final int count;
  final bool isSyncing;

  const QueueIndicator({
    super.key,
    required this.count,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? BridgeTheme.warning.withValues(alpha: 0.15)
            : BridgeTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? BridgeTheme.warning.withValues(alpha: 0.4)
              : BridgeTheme.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: BridgeTheme.primary,
              ),
            ),
          if (isSyncing) const SizedBox(width: 6),
          Text(
            count > 0 ? '$count pending' : 'synced',
            style: TextStyle(
              color: count > 0 ? BridgeTheme.warning : BridgeTheme.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
