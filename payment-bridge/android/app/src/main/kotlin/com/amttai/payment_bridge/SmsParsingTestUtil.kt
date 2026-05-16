package com.amttai.payment_bridge

object SmsParsingTestUtil {
    fun test(rawSms: String): Map<String, Any?> = SmsParser.parseForTest(rawSms).toMap()

    fun testBatch(messages: List<String>): List<Map<String, Any?>> = messages.map { test(it) }
}
