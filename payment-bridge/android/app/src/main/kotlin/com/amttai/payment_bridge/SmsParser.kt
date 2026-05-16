package com.amttai.payment_bridge

import java.text.Normalizer
import java.util.Locale

object SmsParser {
    private val whitespace = "[\\s\\u00A0]*"
    private val looseWhitespace = "[\\s\\u00A0]+"
    private val amountToken = "([0-9][0-9, .\\u00A0]*)(?=\\s*(?:MNT|₮|tugrug|togrog|dungeer|дүнгээр|дvнгээр|dunguur|orlog|орлог|,|\\.|$))"
    private val dateToken = "(.{1,80}?)(?=${whitespace}(?:[,;]${whitespace})?(?:utga|утга|description|memo|ref(?:erence)?))"
    private val durationToken = "([a-z0-9_]+)"
    private val userToken = "([a-z0-9][a-z0-9_.@-]{1,80})"
    private val balanceToken = "([0-9][0-9, .\\u00A0]*)"

    private val primaryPattern = Regex(
        "(?is)" +
            "(?:\\b\\d{2,8}${whitespace}\\*{2,}${whitespace}\\d{2,8}\\b)?" +
            ".{0,80}?" +
            "(?:dansand|дансанд|dans|account|acct)${looseWhitespace}" +
            amountToken +
            ".{0,220}?" +
            "(?:ognoo|огноо|date)${whitespace}[:：-]${whitespace}" +
            dateToken +
            ".{0,180}?" +
            "(?:utga|утга|description|memo|ref(?:erence)?)${whitespace}[:：-]${whitespace}" +
            "(?<![a-z0-9])amt${whitespace}-?${whitespace}tai${whitespace}-${whitespace}" +
            durationToken +
            "${whitespace}-${whitespace}" +
            userToken +
            "(?:.{0,160}?(?:uldegdel|үлдэгдэл|uldegdel:|balance)${whitespace}[:：-]${whitespace}" +
            balanceToken + ")?"
    )

    private val referencePattern = Regex(
        "(?is)(?<![a-z0-9])amt${whitespace}-?${whitespace}tai${whitespace}-${whitespace}" +
            durationToken +
            "${whitespace}-${whitespace}" +
            userToken +
            "(?![a-z0-9_.@-])"
    )

    private val labeledDatePattern = Regex("(?is)(?:ognoo|огноо|date)${whitespace}[:：-]${whitespace}([^,;\\n\\r]+(?:[,;]\\s*[^,;\\n\\r]+)?)")
    private val labeledBalancePattern = Regex("(?is)(?:uldegdel|үлдэгдэл|balance)${whitespace}[:：-]${whitespace}$balanceToken")
    private val incomingAmountPattern = Regex(
        "(?is)(?:dansand|дансанд|dans|account|acct)${looseWhitespace}" + amountToken +
            "|" + amountToken + ".{0,80}?(?:dungeer|дүнгээр|orlogiin|орлог|orlogo|credit|received|guilgee|гүйлгээ)"
    )
    private val anyMoneyPattern = Regex("(?is)([0-9][0-9, .\\u00A0]*)${whitespace}(?:MNT|₮|tugrug|togrog|төгрөг)")
    private val suspiciousLinkPattern = Regex("(?is)(http://|bit\\.ly|tinyurl|verify your|confirm your password)")

    fun parse(sender: String, body: String, receivedAtMillis: Long = System.currentTimeMillis()): ParsedSms? {
        if (body.isBlank() || body.length > 2000 || suspiciousLinkPattern.containsMatchIn(body)) return null
        val normalizedBody = normalizeBody(body)
        val primary = primaryPattern.find(normalizedBody)
        if (primary != null) {
            val amount = parseAmount(primary.groupValues.getOrNull(1)) ?: return null
            val date = primary.groupValues.getOrNull(2).orEmpty().trim().takeIf { it.isNotEmpty() }
            val duration = normalizeDuration(primary.groupValues.getOrNull(3).orEmpty())
            val userId = primary.groupValues.getOrNull(4).orEmpty().trim()
            val balance = parseAmount(primary.groupValues.getOrNull(5))
            if (duration.isNotEmpty() && userId.isNotEmpty()) {
                return ParsedSms(
                    sender = sender,
                    body = body,
                    receivedAtMillis = receivedAtMillis,
                    amount = amount,
                    dateText = date,
                    duration = duration,
                    userId = userId,
                    balance = balance,
                    transactionCode = buildTransactionCode(duration, userId),
                    plan = planFromDuration(duration) ?: planFromAmount(amount),
                    parseMethod = "native_primary"
                )
            }
        }

        val reference = referencePattern.find(normalizedBody) ?: return null
        val duration = normalizeDuration(reference.groupValues.getOrNull(1).orEmpty())
        val userId = reference.groupValues.getOrNull(2).orEmpty().trim()
        if (duration.isEmpty() || userId.isEmpty()) return null
        val amount = extractAmount(normalizedBody) ?: return null
        return ParsedSms(
            sender = sender,
            body = body,
            receivedAtMillis = receivedAtMillis,
            amount = amount,
            dateText = labeledDatePattern.find(normalizedBody)?.groupValues?.getOrNull(1)?.trim(),
            duration = duration,
            userId = userId,
            balance = labeledBalancePattern.find(normalizedBody)?.groupValues?.getOrNull(1)?.let(::parseAmount),
            transactionCode = buildTransactionCode(duration, userId),
            plan = planFromDuration(duration) ?: planFromAmount(amount),
            parseMethod = "native_reference"
        )
    }

    fun parseForTest(rawSms: String): SmsParserTestResult {
        val parsed = parse(sender = "TEST", body = rawSms, receivedAtMillis = 0L)
        return if (parsed == null) {
            SmsParserTestResult(success = false, parsed = null, error = "No native SMS pattern matched")
        } else {
            SmsParserTestResult(success = true, parsed = parsed, error = null)
        }
    }

    private fun extractAmount(body: String): Int? {
        val incoming = incomingAmountPattern.find(body)
        if (incoming != null) {
            for (i in 1 until incoming.groupValues.size) {
                parseAmount(incoming.groupValues[i])?.let { return it }
            }
        }
        val money = anyMoneyPattern.find(body)
        if (money != null) return parseAmount(money.groupValues.getOrNull(1))
        return null
    }

    private fun parseAmount(raw: String?): Int? {
        if (raw.isNullOrBlank()) return null
        val cleaned = raw.replace("\u00A0", "").replace(Regex("[^0-9.]"), "")
        if (cleaned.isBlank()) return null
        val normalized = if (cleaned.count { it == '.' } > 1) cleaned.replace(".", "") else cleaned
        return normalized.toDoubleOrNull()?.toInt()
    }

    private fun normalizeBody(body: String): String = Normalizer.normalize(body, Normalizer.Form.NFKC).replace('\u00A0', ' ')

    private fun normalizeDuration(raw: String): String = raw.replace(Regex("\\s+"), "").trim('-').lowercase(Locale.ROOT)

    private fun buildTransactionCode(duration: String, userId: String): String = "AMTTAI-${duration.uppercase(Locale.ROOT)}-${userId.uppercase(Locale.ROOT)}"

    private fun planFromDuration(duration: String): String? {
        val normalized = duration.lowercase(Locale.ROOT).replace("_", "").replace("-", "")
        return when {
            normalized in setOf("1month", "onemonth", "30days", "30day", "1mo", "month") -> "oneMonth"
            normalized in setOf("3month", "threemonth", "90days", "90day", "3mo") -> "threeMonth"
            normalized in setOf("6month", "sixmonth", "180days", "180day", "6mo") -> "sixMonth"
            normalized in setOf("1year", "oneyear", "12month", "365days", "365day", "year") -> "oneYear"
            else -> null
        }
    }

    private fun planFromAmount(amount: Int): String? = when (amount) {
        6000, 9000 -> "oneMonth"
        15000, 21000 -> "threeMonth"
        36000 -> "sixMonth"
        38000 -> "oneYear"
        else -> null
    }
}

data class ParsedSms(
    val sender: String,
    val body: String,
    val receivedAtMillis: Long,
    val amount: Int,
    val dateText: String?,
    val duration: String,
    val userId: String,
    val balance: Int?,
    val transactionCode: String,
    val plan: String?,
    val parseMethod: String
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "sender" to sender,
        "body" to body,
        "receivedAt" to receivedAtMillis,
        "amount" to amount,
        "date" to dateText,
        "duration" to duration,
        "userId" to userId,
        "balance" to balance,
        "transactionCode" to transactionCode,
        "plan" to plan,
        "parseMethod" to parseMethod
    )
}

data class SmsParserTestResult(
    val success: Boolean,
    val parsed: ParsedSms?,
    val error: String?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "success" to success,
        "parsed" to parsed?.toMap(),
        "error" to error
    )
}
