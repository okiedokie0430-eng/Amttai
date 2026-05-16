import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../theme.dart';
import 'transaction_detail_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  final AppDatabase db;

  const TransactionsListScreen({super.key, required this.db});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<SmsTransaction> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadNextPage();
      }
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newItems = await widget.db.getRecentTransactions(
        limit: _pageSize,
        offset: _transactions.length,
      );

      setState(() {
        _transactions.addAll(newItems);
        if (newItems.length < _pageSize) {
          _hasMore = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _transactions.clear();
      _hasMore = true;
    });
    await _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _transactions.isEmpty && !_isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No transactions found',
                      style: TextStyle(color: BridgeTheme.textMuted),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _transactions.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _transactions.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final tx = _transactions[index];
                  return _buildTransactionTile(context, tx);
                },
              ),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, SmsTransaction tx) {
    final statusColor = _statusColor(tx.status);
    final time = DateFormat('MM/dd HH:mm').format(tx.createdAt);
    final isActivated = tx.status == 'synced';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.parsedTransactionCode ?? tx.sender,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: BridgeTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tx.parsedAmount != null ? "${tx.parsedAmount} MNT" : "amount unknown"} • $time',
                      style: const TextStyle(
                        color: BridgeTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActivated) ...[
                      Icon(Icons.check_circle, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isActivated ? 'ACTIVATED' : tx.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
}
