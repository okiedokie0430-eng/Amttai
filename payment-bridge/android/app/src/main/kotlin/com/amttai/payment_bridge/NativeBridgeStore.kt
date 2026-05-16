package com.amttai.payment_bridge

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.security.MessageDigest
import java.util.Locale

class NativeBridgeStore private constructor(context: Context) : SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS native_sms_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sms_hash TEXT NOT NULL UNIQUE,
                sender TEXT NOT NULL,
                body TEXT NOT NULL,
                received_at INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                parsed_amount INTEGER,
                parsed_transaction_code TEXT,
                parsed_user_id TEXT,
                parsed_duration TEXT,
                parsed_plan TEXT,
                parse_method TEXT,
                attempts INTEGER NOT NULL DEFAULT 0,
                next_retry_at INTEGER,
                last_error TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_native_sms_queue_status ON native_sms_queue(status, next_retry_at, created_at)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_native_sms_queue_hash ON native_sms_queue(sms_hash)")
        createFlutterCompatibleTables(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        onCreate(db)
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS native_sms_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sms_hash TEXT NOT NULL UNIQUE,
                sender TEXT NOT NULL,
                body TEXT NOT NULL,
                received_at INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                parsed_amount INTEGER,
                parsed_transaction_code TEXT,
                parsed_user_id TEXT,
                parsed_duration TEXT,
                parsed_plan TEXT,
                parse_method TEXT,
                attempts INTEGER NOT NULL DEFAULT 0,
                next_retry_at INTEGER,
                last_error TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_native_sms_queue_status ON native_sms_queue(status, next_retry_at, created_at)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_native_sms_queue_hash ON native_sms_queue(sms_hash)")
        createFlutterCompatibleTables(db)
    }

    fun insertRawSms(sender: String, body: String, receivedAt: Long): Long {
        val hash = fingerprint(sender, body, receivedAt)
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("sms_hash", hash)
            put("sender", sender)
            put("body", body)
            put("received_at", receivedAt)
            put("status", STATUS_PENDING)
            put("created_at", now)
            put("updated_at", now)
        }
        val db = writableDatabase
        val inserted = db.insertWithOnConflict("native_sms_queue", null, values, SQLiteDatabase.CONFLICT_IGNORE)
        pruneQueue(db)
        return inserted
    }

    fun nextPending(limit: Int, now: Long = System.currentTimeMillis()): List<NativeSmsRecord> {
        val db = readableDatabase
        db.query(
            "native_sms_queue",
            null,
            "(status = ? OR status = ?) AND (next_retry_at IS NULL OR next_retry_at <= ?)",
            arrayOf(STATUS_PENDING, STATUS_RETRY, now.toString()),
            null,
            null,
            "created_at ASC",
            limit.toString()
        ).use { cursor ->
            val out = ArrayList<NativeSmsRecord>(limit)
            while (cursor.moveToNext()) {
                out.add(
                    NativeSmsRecord(
                        id = cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                        smsHash = cursor.getString(cursor.getColumnIndexOrThrow("sms_hash")),
                        sender = cursor.getString(cursor.getColumnIndexOrThrow("sender")),
                        body = cursor.getString(cursor.getColumnIndexOrThrow("body")),
                        receivedAt = cursor.getLong(cursor.getColumnIndexOrThrow("received_at")),
                        attempts = cursor.getInt(cursor.getColumnIndexOrThrow("attempts"))
                    )
                )
            }
            return out
        }
    }

    fun markProcessing(id: Long) {
        updateStatus(id, STATUS_PROCESSING, null)
    }

    fun markParsed(record: NativeSmsRecord, parsed: ParsedSms, enqueueForFlutter: Boolean = true): Long {
        val db = writableDatabase
        val now = System.currentTimeMillis()
        db.beginTransaction()
        return try {
            val values = ContentValues().apply {
                put("status", STATUS_PARSED)
                put("parsed_amount", parsed.amount)
                put("parsed_transaction_code", parsed.transactionCode)
                put("parsed_user_id", parsed.userId)
                put("parsed_duration", parsed.duration)
                put("parsed_plan", parsed.plan)
                put("parse_method", parsed.parseMethod)
                putNull("last_error")
                put("updated_at", now)
            }
            db.update("native_sms_queue", values, "id = ?", arrayOf(record.id.toString()))
            val transactionId = upsertFlutterTransaction(db, record, parsed, STATUS_MATCHED)
            if (enqueueForFlutter) enqueueFlutterSync(db, transactionId, record, parsed)
            insertDedup(db, record.smsHash)
            db.setTransactionSuccessful()
            transactionId
        } finally {
            db.endTransaction()
        }
    }

    fun markSynced(record: NativeSmsRecord, parsed: ParsedSms, paymentId: String?, userId: String?) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val values = ContentValues().apply {
                put("status", STATUS_SYNCED)
                putNull("last_error")
                put("updated_at", System.currentTimeMillis())
            }
            db.update("native_sms_queue", values, "id = ?", arrayOf(record.id.toString()))
            updateFlutterTransactionByHash(db, record.smsHash, STATUS_SYNCED, paymentId, userId, null)
            markFlutterSyncDone(db, record.smsHash)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun markRejected(id: Long, error: String) {
        updateStatus(id, STATUS_REJECTED, error)
    }

    fun markRetry(id: Long, attempts: Int, baseDelayMs: Int, maxDelayMs: Int, error: String) {
        val boundedAttempts = attempts.coerceAtLeast(0)
        val multiplier = 1L shl boundedAttempts.coerceAtMost(10)
        val delay = (baseDelayMs.toLong() * multiplier).coerceAtMost(maxDelayMs.toLong())
        val values = ContentValues().apply {
            put("status", STATUS_RETRY)
            put("attempts", attempts + 1)
            put("next_retry_at", System.currentTimeMillis() + delay)
            put("last_error", error.take(500))
            put("updated_at", System.currentTimeMillis())
        }
        writableDatabase.update("native_sms_queue", values, "id = ?", arrayOf(id.toString()))
    }

    fun markFailed(id: Long, error: String) {
        updateStatus(id, STATUS_FAILED, error)
    }

    fun pendingCount(): Int {
        readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM native_sms_queue WHERE status IN (?, ?, ?)",
            arrayOf(STATUS_PENDING, STATUS_RETRY, STATUS_PROCESSING)
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
    }

    fun recent(limit: Int): List<Map<String, Any?>> {
        readableDatabase.query(
            "native_sms_queue",
            null,
            null,
            null,
            null,
            null,
            "created_at DESC",
            limit.coerceIn(1, 200).toString()
        ).use { cursor ->
            val rows = ArrayList<Map<String, Any?>>()
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "id" to cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                        "smsHash" to cursor.getString(cursor.getColumnIndexOrThrow("sms_hash")),
                        "sender" to cursor.getString(cursor.getColumnIndexOrThrow("sender")),
                        "body" to cursor.getString(cursor.getColumnIndexOrThrow("body")),
                        "receivedAt" to cursor.getLong(cursor.getColumnIndexOrThrow("received_at")),
                        "status" to cursor.getString(cursor.getColumnIndexOrThrow("status")),
                        "amount" to cursor.getNullableInt("parsed_amount"),
                        "transactionCode" to cursor.getNullableString("parsed_transaction_code"),
                        "userId" to cursor.getNullableString("parsed_user_id"),
                        "duration" to cursor.getNullableString("parsed_duration"),
                        "plan" to cursor.getNullableString("parsed_plan"),
                        "parseMethod" to cursor.getNullableString("parse_method"),
                        "attempts" to cursor.getInt(cursor.getColumnIndexOrThrow("attempts")),
                        "lastError" to cursor.getNullableString("last_error")
                    )
                )
            }
            return rows
        }
    }

    private fun updateStatus(id: Long, status: String, error: String?) {
        val values = ContentValues().apply {
            put("status", status)
            if (error == null) putNull("last_error") else put("last_error", error.take(500))
            put("updated_at", System.currentTimeMillis())
        }
        writableDatabase.update("native_sms_queue", values, "id = ?", arrayOf(id.toString()))
    }

    private fun createFlutterCompatibleTables(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS sms_transactions (
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
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS sync_queue (
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
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS dedup_entries (
                fingerprint TEXT PRIMARY KEY,
                sms_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
                expires_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS local_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS log_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level TEXT NOT NULL,
                tag TEXT NOT NULL,
                message TEXT NOT NULL,
                metadata TEXT,
                created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
            )
            """.trimIndent()
        )
    }

    private fun upsertFlutterTransaction(db: SQLiteDatabase, record: NativeSmsRecord, parsed: ParsedSms, status: String): Long {
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("sms_hash", record.smsHash)
            put("sender", record.sender)
            put("body", record.body)
            put("received_at", record.receivedAt)
            put("parsed_amount", parsed.amount)
            put("parsed_transaction_code", parsed.transactionCode)
            put("parsed_plan", parsed.plan)
            put("status", status)
            put("updated_at", now)
            put("created_at", now)
        }
        val inserted = db.insertWithOnConflict("sms_transactions", null, values, SQLiteDatabase.CONFLICT_IGNORE)
        if (inserted != -1L) return inserted
        db.update("sms_transactions", values, "sms_hash = ?", arrayOf(record.smsHash))
        db.rawQuery("SELECT id FROM sms_transactions WHERE sms_hash = ? LIMIT 1", arrayOf(record.smsHash)).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getLong(0) else -1L
        }
    }

    private fun enqueueFlutterSync(db: SQLiteDatabase, transactionId: Long, record: NativeSmsRecord, parsed: ParsedSms) {
        if (transactionId <= 0) return
        db.rawQuery(
            "SELECT id FROM sync_queue WHERE transaction_local_id = ? AND status IN ('pending', 'retry', 'in_progress') LIMIT 1",
            arrayOf(transactionId.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) return
        }
        val payload = "{" +
            "\"sender\":\"${jsonEscape(record.sender)}\"," +
            "\"amount\":${parsed.amount}," +
            "\"transaction_code\":\"${jsonEscape(parsed.transactionCode)}\"," +
            "\"direct_user_id\":\"${jsonEscape(parsed.userId)}\"," +
            "\"plan\":${parsed.plan?.let { "\"${jsonEscape(it)}\"" } ?: "null"}," +
            "\"sms_hash\":\"${jsonEscape(record.smsHash)}\"," +
            "\"received_at\":\"${record.receivedAt}\"," +
            "\"parse_method\":\"${jsonEscape(parsed.parseMethod)}\"" +
            "}"
        val values = ContentValues().apply {
            put("transaction_local_id", transactionId)
            put("payload", payload)
            put("priority", if (parsed.plan != null) 10 else 5)
            put("status", "pending")
            put("created_at", System.currentTimeMillis())
        }
        db.insert("sync_queue", null, values)
    }

    private fun updateFlutterTransactionByHash(db: SQLiteDatabase, smsHash: String, status: String, paymentId: String?, userId: String?, error: String?) {
        val values = ContentValues().apply {
            put("status", status)
            if (paymentId != null) put("matched_payment_id", paymentId)
            if (userId != null) put("matched_user_id", userId)
            if (error != null) put("error", error)
            put("updated_at", System.currentTimeMillis())
        }
        db.update("sms_transactions", values, "sms_hash = ?", arrayOf(smsHash))
    }

    private fun markFlutterSyncDone(db: SQLiteDatabase, smsHash: String) {
        db.rawQuery("SELECT id FROM sms_transactions WHERE sms_hash = ? LIMIT 1", arrayOf(smsHash)).use { cursor ->
            if (!cursor.moveToFirst()) return
            val transactionId = cursor.getLong(0)
            val values = ContentValues().apply {
                put("status", "done")
                putNull("last_error")
            }
            db.update("sync_queue", values, "transaction_local_id = ? AND status IN ('pending', 'retry', 'in_progress')", arrayOf(transactionId.toString()))
        }
    }

    private fun insertDedup(db: SQLiteDatabase, smsHash: String) {
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("fingerprint", smsHash)
            put("sms_hash", smsHash)
            put("created_at", now)
            put("expires_at", now + 30L * 24L * 60L * 60L * 1000L)
        }
        db.insertWithOnConflict("dedup_entries", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun pruneQueue(db: SQLiteDatabase) {
        db.delete("native_sms_queue", "created_at < ? AND status IN (?, ?, ?)", arrayOf((System.currentTimeMillis() - 90L * 24L * 60L * 60L * 1000L).toString(), STATUS_SYNCED, STATUS_FAILED, STATUS_REJECTED))
        val maxRows = 500
        db.rawQuery("SELECT COUNT(*) FROM native_sms_queue", null).use { cursor ->
            if (cursor.moveToFirst() && cursor.getInt(0) > maxRows) {
                db.execSQL("DELETE FROM native_sms_queue WHERE id IN (SELECT id FROM native_sms_queue ORDER BY created_at ASC LIMIT (SELECT COUNT(*) - $maxRows FROM native_sms_queue))")
            }
        }
    }

    companion object {
        private const val DB_NAME = "amttai_bridge.db"
        private const val DB_VERSION = 1
        const val STATUS_PENDING = "pending"
        const val STATUS_PROCESSING = "processing"
        const val STATUS_RETRY = "retry"
        const val STATUS_PARSED = "parsed"
        const val STATUS_MATCHED = "matched"
        const val STATUS_SYNCED = "synced"
        const val STATUS_REJECTED = "rejected"
        const val STATUS_FAILED = "failed"

        @Volatile
        private var instance: NativeBridgeStore? = null

        fun getInstance(context: Context): NativeBridgeStore = instance ?: synchronized(this) {
            instance ?: NativeBridgeStore(context.applicationContext).also { instance = it }
        }

        fun fingerprint(sender: String, body: String, receivedAt: Long): String {
            val roundedTimestamp = receivedAt / 1000L
            val input = "${sender.lowercase(Locale.ROOT).trim()}|${body.trim()}|$roundedTimestamp"
            val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
            return digest.joinToString("") { "%02x".format(it) }
        }

        private fun jsonEscape(value: String): String = value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
    }
}

data class NativeSmsRecord(
    val id: Long,
    val smsHash: String,
    val sender: String,
    val body: String,
    val receivedAt: Long,
    val attempts: Int
)

private fun android.database.Cursor.getNullableString(columnName: String): String? {
    val index = getColumnIndexOrThrow(columnName)
    return if (isNull(index)) null else getString(index)
}

private fun android.database.Cursor.getNullableInt(columnName: String): Int? {
    val index = getColumnIndexOrThrow(columnName)
    return if (isNull(index)) null else getInt(index)
}
