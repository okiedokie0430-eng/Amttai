import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../theme.dart';

class TransactionDetailScreen extends StatelessWidget {
  final SmsTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  void _copyToClipboard(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(transaction.status);
    final isActivated = transaction.status == 'synced';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Header
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActivated ? Icons.check_circle : Icons.info_outline,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActivated ? 'ACTIVATED' : transaction.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Parsed Data Card
          _buildSectionTitle('Parsed Information'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(context, 'Transaction Code', transaction.parsedTransactionCode ?? 'N/A'),
                  const Divider(),
                  _buildDetailRow(context, 'Amount', transaction.parsedAmount != null ? '${transaction.parsedAmount} MNT' : 'N/A'),
                  const Divider(),
                  _buildDetailRow(context, 'Plan Extracted', transaction.parsedPlan ?? 'N/A'),
                  const Divider(),
                  _buildDetailRow(context, 'Appwrite Payment ID', transaction.matchedPaymentId ?? 'Not matched'),
                  const Divider(),
                  _buildDetailRow(context, 'Appwrite User ID', transaction.matchedUserId ?? 'Not matched'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Raw SMS Data Card
          _buildSectionTitle('Raw SMS Payload'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Sender', transaction.sender),
                  const Divider(),
                  const Text(
                    'Body',
                    style: TextStyle(
                      color: BridgeTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BridgeTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BridgeTheme.border),
                    ),
                    child: SelectableText(
                      transaction.body,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: BridgeTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metadata Card
          _buildSectionTitle('System Metadata'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(context, 'SMS Hash (Dedup Key)', transaction.smsHash),
                  const Divider(),
                  _buildDetailRow(context, 'Received At', DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.receivedAt)),
                  const Divider(),
                  _buildDetailRow(context, 'Last Updated', DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.updatedAt)),
                  const Divider(),
                  _buildDetailRow(context, 'Sync Attempts', transaction.syncAttempts.toString()),
                  if (transaction.error != null) ...[
                    const Divider(),
                    _buildDetailRow(context, 'Last Error', transaction.error!, valueColor: BridgeTheme.error),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: BridgeTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color valueColor = BridgeTheme.textPrimary}) {
    return InkWell(
      onTap: () => _copyToClipboard(context, label, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  color: BridgeTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
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
}
