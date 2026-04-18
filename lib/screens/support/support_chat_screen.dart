import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/support_message.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatService = ChatService();

  List<SupportMessage> _messages = [];
  StreamSubscription? _sub;
  bool _loading = true;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _userId = context.read<AuthProvider>().user?.id ?? '';
    if (_userId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      _messages = await _chatService.getMessages(_userId);
    } catch (_) {
      // Appwrite not configured or collection not created yet
    }
    if (mounted) setState(() => _loading = false);
    _scrollToBottom();

    try {
      final realtimeSub = _chatService.subscribeToMessages(_userId);
      _sub = realtimeSub.stream.listen((event) {
        if (event.events.any((e) => e.contains('.create'))) {
          try {
            final msg = SupportMessage.fromJson(event.payload);
            // Only add if not already present (we add locally first)
            if (msg.userId == _userId &&
                !_messages.any((m) => m.message == msg.message &&
                    m.createdAt.difference(msg.createdAt).inSeconds.abs() < 5)) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          } catch (_) {}
        }
      });
    } catch (_) {
      // Realtime not available
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    // Add message locally immediately so user sees it
    final localMsg = SupportMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      message: text,
      isFromAdmin: false,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(localMsg));
    _scrollToBottom();

    // Try to send to Appwrite backend
    if (_userId.isNotEmpty) {
      final result =
          await _chatService.sendMessage(userId: _userId, message: text);
      if (result == null && mounted) {
        // Show a subtle error indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Мессеж илгээхэд алдаа гарлаа. Дахин оролдоно уу.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(S.supportTitle, style: textTheme.titleLarge),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.textTertiary(context)),
                              const SizedBox(height: 16),
                              Text(S.supportWelcome,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                      color:
                                          AppColors.textSecondary(context))),
                              const SizedBox(height: 8),
                              Text(
                                  'Доорх талбарт мессежээ бичнэ үү',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                      color:
                                          AppColors.textTertiary(context))),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border:
                  Border(top: BorderSide(color: AppColors.border(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: S.supportHint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(SupportMessage msg) {
    final isMe = !msg.isFromAdmin;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceVariant(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Text(
          msg.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isMe ? Colors.white : AppColors.textPrimary(context),
              ),
        ),
      ),
    );
  }
}
