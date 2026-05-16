import 'package:flutter/material.dart';

import '../../services/sms/sms_parser.dart';
import '../theme.dart';

/// Test screen for pasting SMS text and previewing parser output.
class TestParserScreen extends StatefulWidget {
  const TestParserScreen({super.key});

  @override
  State<TestParserScreen> createState() => _TestParserScreenState();
}

class _TestParserScreenState extends State<TestParserScreen> {
  final _smsController = TextEditingController();
  final _senderController = TextEditingController(text: 'Golomt');
  ParsedSms? _result;

  void _parse() {
    final result = SmsParser.parse(
      sender: _senderController.text.trim(),
      body: _smsController.text.trim(),
      receivedAt: DateTime.now(),
    );
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST PARSER')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'SENDER',
            style: TextStyle(
              color: BridgeTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _senderController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(hintText: 'e.g., Golomt, 1800'),
          ),
          const SizedBox(height: 16),

          const Text(
            'SMS BODY',
            style: TextStyle(
              color: BridgeTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _smsController,
            maxLines: 6,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText:
                  'Paste SMS text here...\n\n'
                  'e.g., 290*****08 dansand 9000 dungeer orlogiin guilgee hiigdlee. '
                  'Ognoo: 2026-04-26, Utga: AMTTAI-ONEMONTH-user123 Uldegdel: 45000',
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Parse'),
          ),
          const SizedBox(height: 16),

          if (_result != null) ...[
            const Text(
              'RESULT',
              style: TextStyle(
                color: BridgeTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _resultRow(
                      'Valid',
                      _result!.isValid ? '✅ YES' : '❌ NO',
                      _result!.isValid
                          ? BridgeTheme.success
                          : BridgeTheme.error,
                    ),
                    _resultRow(
                      'Method',
                      _result!.parseMethod,
                      BridgeTheme.primary,
                    ),
                    _resultRow(
                      'Amount',
                      _result!.amount != null
                          ? '${_result!.amount} MNT'
                          : 'not found',
                      null,
                    ),
                    _resultRow(
                      'TX Code',
                      _result!.transactionCode ?? 'not found',
                      null,
                    ),
                    _resultRow('Plan', _result!.plan ?? 'unknown', null),
                    if (_result!.error != null)
                      _resultRow('Error', _result!.error!, BridgeTheme.error),
                  ],
                ),
              ),
            ),
          ],

          // Example SMS templates
          const SizedBox(height: 24),
          const Text(
            'EXAMPLES',
            style: TextStyle(
              color: BridgeTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._examples.map(
            (ex) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  _smsController.text = ex['body']!;
                  _senderController.text = ex['sender']!;
                  _parse();
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex['name']!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BridgeTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ex['body']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: BridgeTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: BridgeTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? BridgeTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, String>> _examples = [
    {
      'name': 'Production format (transliterated)',
      'sender': 'Golomt',
      'body':
          '290*****08 dansand 9000 dungeer orlogiin guilgee hiigdlee. '
          'Ognoo: 2026-04-26 11:04, Utga:  AMTTAI-ONEMONTH-user_123 Uldegdel: 45000',
    },
    {
      'name': 'Golomt — Incoming with AMTTAI code',
      'sender': 'Golomt',
      'body':
          'Таны 480015002905262908 дансанд 9,000 MNT орлого орсон. '
          'Гүйлгээний утга: AMTTAI-BATBOLD-ONEMONTH-84629',
    },
    {
      'name': 'Generic bank — Amount + code',
      'sender': '1800',
      'body':
          'Данс: ****2908, 21,000₮ хүлээн авлаа. '
          'Утга: AMTTAI-SARNAI-THREEMONTH-71234',
    },
    {
      'name': 'No transaction code',
      'sender': 'KhanBank',
      'body':
          'Таны дансанд 36,000 MNT шилжүүлэг орлоо. '
          'Илгээгч: Болд',
    },
    {
      'name': 'Non-payment SMS',
      'sender': 'Golomt',
      'body': 'Таны нууц үгийг солих хүсэлт баталгаажлаа.',
    },
  ];

  @override
  void dispose() {
    _smsController.dispose();
    _senderController.dispose();
    super.dispose();
  }
}
