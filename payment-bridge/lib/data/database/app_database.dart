import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// --- Data Models ---

class SmsTransaction {
  final int id;
  final String smsHash;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final int? parsedAmount;
  final String? parsedTransactionCode;
  final String? parsedPlan;
  final String status;
  final String? matchedPaymentId;
  final String? matchedUserId;
  final String? error;
  final int syncAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;

  SmsTransaction({
    required this.id,
    required this.smsHash,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.parsedAmount,
    this.parsedTransactionCode,
    this.parsedPlan,
    required this.status,
    this.matchedPaymentId,
    this.matchedUserId,
    this.error,
    required this.syncAttempts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SmsTransaction.fromMap(Map<String, dynamic> map) {
    return SmsTransaction(
      id: map['id'] as int,
      smsHash: map['sms_hash'] as String,
      sender: map['sender'] as String,
      body: map['body'] as String,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        map['received_at'] as int,
      ),
      parsedAmount: map['parsed_amount'] as int?,
      parsedTransactionCode: map['parsed_transaction_code'] as String?,
      parsedPlan: map['parsed_plan'] as String?,
      status: map['status'] as String,
      matchedPaymentId: map['matched_payment_id'] as String?,
      matchedUserId: map['matched_user_id'] as String?,
      error: map['error'] as String?,
      syncAttempts: map['sync_attempts'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class SyncQueueItem {
  final int id;
  final int transactionLocalId;
  final String payload;
  final int attempts;
  final int priority;
  final DateTime? nextRetryAt;
  final String status;
  final String? lastError;
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.transactionLocalId,
    required this.payload,
    required this.attempts,
    required this.priority,
    this.nextRetryAt,
    required this.status,
    this.lastError,
    required this.createdAt,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int,
      transactionLocalId: map['transaction_local_id'] as int,
      payload: map['payload'] as String,
      attempts: map['attempts'] as int? ?? 0,
      priority: map['priority'] as int? ?? 5,
      nextRetryAt: map['next_retry_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['next_retry_at'] as int)
          : null,
      status: map['status'] as String,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

class LogEntry {
  final int id;
  final String level;
  final String tag;
  final String message;
  final String? metadata;
  final DateTime createdAt;

  LogEntry({
    required this.id,
    required this.level,
    required this.tag,
    required this.message,
    this.metadata,
    required this.createdAt,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int,
      level: map['level'] as String,
      tag: map['tag'] as String,
      message: map['message'] as String,
      metadata: map['metadata'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

// --- AppDatabase (Sqflite Implementation) ---

class AppDatabase {
  static const String _dbName = 'amttai_bridge.db';
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    // SMS Transactions
    await db.execute('''
      CREATE TABLE sms_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sms_hash TEXT NOT NULL UNIQUE,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        parsed_amount INTEGER,
        parsed_transaction_code TEXT,
        parsed_plan TEXT,
        status TEXT NOT NULL DEFAULT 'raw',
        matched_payment_id TEXT,
        matched_user_id TEXT,
        error TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Sync Queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_local_id INTEGER NOT NULL,
        payload TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 5,
        next_retry_at INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Dedup Entries
    await db.execute('''
      CREATE TABLE dedup_entries (
        fingerprint TEXT PRIMARY KEY,
        sms_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        expires_at INTEGER NOT NULL
      )
    ''');

    // Log Entries
    await db.execute('''
      CREATE TABLE log_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        tag TEXT NOT NULL,
        message TEXT NOT NULL,
        metadata TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Local Settings
    await db.execute('''
      CREATE TABLE local_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // --- Transactions ---

  Future<int> insertTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    tx['created_at'] = _now();
    tx['updated_at'] = _now();
    return await db.insert(
      'sms_transactions',
      tx,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SmsTransaction?> getTransactionByHash(String hash) async {
    final db = await database;
    final results = await db.query(
      'sms_transactions',
      where: 'sms_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SmsTransaction.fromMap(results.first);
  }

  Future<List<SmsTransaction>> getRecentTransactions({int limit = 50, int offset = 0}) async {
    final db = await database;
    final results = await db.query(
      'sms_transactions',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((e) => SmsTransaction.fromMap(e)).toList();
  }

  Future<void> updateTransactionStatus(
    int id,
    String status, {
    String? paymentId,
    String? userId,
    String? error,
  }) async {
    final db = await database;
    final data = <String, dynamic>{'status': status, 'updated_at': _now()};
    if (paymentId != null) data['matched_payment_id'] = paymentId;
    if (userId != null) data['matched_user_id'] = userId;
    if (error != null) data['error'] = error;
    await db.update('sms_transactions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncAttempts(int txId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sms_transactions SET sync_attempts = sync_attempts + 1, updated_at = ? WHERE id = ?',
      [_now(), txId],
    );
  }

  Future<int> getTransactionCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sms_transactions',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- Sync Queue ---

  Future<int> insertSyncItem(Map<String, dynamic> item) async {
    final db = await database;
    item['created_at'] = _now();
    return await db.insert('sync_queue', item);
  }

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await database;
    final now = _now();
    final results = await db.query(
      'sync_queue',
      where:
          "(status = 'pending' OR status = 'retry') AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: [now],
      orderBy: 'priority DESC, created_at ASC',
    );
    return results.map((e) => SyncQueueItem.fromMap(e)).toList();
  }

  Future<void> updateSyncStatus(int id, String status, {String? error}) async {
    final db = await database;
    final data = <String, dynamic>{'status': status};
    if (error != null) data['last_error'] = error;
    await db.update('sync_queue', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncQueueAttempts(
    int id,
    DateTime nextRetry,
    String? error,
  ) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, next_retry_at = ?, status = ?, last_error = ? WHERE id = ?',
      [nextRetry.millisecondsSinceEpoch, 'retry', error, id],
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'pending' OR status = 'retry'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- Dedup ---

  Future<bool> isDuplicate(String fingerprint) async {
    final db = await database;
    final now = _now();

    // Auto-cleanup expired while we check
    await db.delete('dedup_entries', where: 'expires_at < ?', whereArgs: [now]);

    final results = await db.query(
      'dedup_entries',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> insertDedup(Map<String, dynamic> dedup) async {
    final db = await database;
    dedup['created_at'] = _now();
    await db.insert(
      'dedup_entries',
      dedup,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Settings ---

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('local_settings');
    final map = <String, String>{};
    for (var row in results) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('local_settings', {
      'key': key,
      'value': value,
      'updated_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Logs ---

  Future<void> insertLog(Map<String, dynamic> log) async {
    final db = await database;
    log['created_at'] = _now();
    await db.insert('log_entries', log);
  }

  Future<List<LogEntry>> getRecentLogs({
    int limit = 100,
    String? levelFilter,
  }) async {
    final db = await database;
    List<Map<String, Object?>> results;
    if (levelFilter != null) {
      results = await db.query(
        'log_entries',
        where: 'level = ?',
        whereArgs: [levelFilter],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    } else {
      results = await db.query(
        'log_entries',
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return results.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('log_entries');
  }

  // --- Maintenance ---

  Future<void> pruneOldData() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;

    await db.delete(
      'log_entries',
      where: 'created_at < ?',
      whereArgs: [thirtyDaysAgo],
    );
    await db.delete(
      'dedup_entries',
      where: 'expires_at < ?',
      whereArgs: [_now()],
    );

    // Prune synced/failed sync queue items older than 30 days
    await db.delete(
      'sync_queue',
      where: '(status = ? OR status = ?) AND created_at < ?',
      whereArgs: ['done', 'failed', thirtyDaysAgo],
    );
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
