import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _notifications = true;
  bool _deleting = false;

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Бүртгэл устгах'),
        content: const Text('Та бүртгэлээ устгахдаа итгэлтэй байна уу?\n\nЭнэ үйлдлийг буцаах боломжгүй.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Болих')),
          TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text('Устгах', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final success = await context.read<AuthProvider>().deleteAccount();
      if (success && mounted) context.go('/welcome');
    } catch (e) {
      if (mounted) _showSnack('Бүртгэл устгахад алдаа: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildSection({required List<Widget> children, required Color bgColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(color: color, height: 1, thickness: 1));
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required Color textColor,
    Color? iconColor,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final effectiveIconColor = iconColor ?? AppColors.textSecondary(context);
    final cThemeColor = isDestructive ? Colors.redAccent : AppColors.primary;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: cThemeColor, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: isDestructive ? Colors.redAccent : textColor, fontSize: 16, fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            if (trailing != null) trailing else if (!isDestructive) Icon(Icons.chevron_right_rounded, color: effectiveIconColor, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final cardColor = AppColors.surfaceVariant(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final dividerColor = AppColors.border(context).withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Ерөнхий тохиргоо', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildSection(
              bgColor: cardColor,
              children: [
                _buildListTile(
                  icon: Icons.email_rounded, title: 'И-мэйл солих', textColor: textPrimary, iconColor: textSecondary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ChangeEmailScreen())),
                ),
                _buildDivider(dividerColor),
                _buildListTile(
                  icon: Icons.lock_rounded, title: 'Нууц үг солих', textColor: textPrimary, iconColor: textSecondary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ChangePasswordScreen())),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              bgColor: cardColor,
              children: [
                _buildListTile(
                  icon: Icons.notifications_rounded, title: S.notifications, textColor: textPrimary, iconColor: textSecondary,
                  onTap: () => setState(() => _notifications = !_notifications),
                  trailing: Switch.adaptive(
                    value: _notifications, activeThumbColor: AppColors.primary, activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              bgColor: cardColor,
              children: [
                _buildListTile(
                  icon: Icons.delete_forever_rounded, title: _deleting ? 'Устгаж байна...' : 'Бүртгэл устгах', textColor: textPrimary,
                  isDestructive: true, onTap: _deleting ? () {} : _deleteAccount,
                  trailing: _deleting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)) : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _ChangeEmailScreen extends StatefulWidget {
  const _ChangeEmailScreen();
  @override
  State<_ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<_ChangeEmailScreen> {
  final _newEmailCtrl = TextEditingController();
  final _emailPasswordCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _newEmailCtrl.dispose(); _emailPasswordCtrl.dispose(); super.dispose(); }

  Future<void> _changeEmail() async {
    final email = _newEmailCtrl.text.trim();
    final password = _emailPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('И-мэйл хаяг буруу байна')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().changeEmail(newEmail: email, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('И-мэйл амжилттай солигдлоо')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('И-мэйл солих', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)), centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            _inputField(context: context, controller: _newEmailCtrl, icon: Icons.email_rounded, hint: 'Шинэ и-мэйл хаяг', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _inputField(context: context, controller: _emailPasswordCtrl, icon: Icons.lock_rounded, hint: 'Одоогийн нууц үг', obscure: true),
            const SizedBox(height: 32),
            _actionButton(label: 'И-мэйл солих', onPressed: _saving ? null : _changeEmail, loading: _saving),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();
  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _oldPasswordCtrl.dispose(); _newPasswordCtrl.dispose(); super.dispose(); }

  Future<void> _changePassword() async {
    final oldPw = _oldPasswordCtrl.text.trim();
    final newPw = _newPasswordCtrl.text.trim();
    if (oldPw.isEmpty || newPw.isEmpty) return;
    if (newPw.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Хамгийн багадаа 8 тэмдэгт')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().changePassword(oldPassword: oldPw, newPassword: newPw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нууц үг амжилттай солигдлоо')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Нууц үг солих', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)), centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            _inputField(context: context, controller: _oldPasswordCtrl, icon: Icons.lock_rounded, hint: 'Хуучин нууц үг', obscure: true),
            const SizedBox(height: 16),
            _inputField(context: context, controller: _newPasswordCtrl, icon: Icons.lock_rounded, hint: 'Шинэ нууц үг', obscure: true),
            const SizedBox(height: 32),
            _actionButton(label: 'Нууц үг хадгалах', onPressed: _saving ? null : _changePassword, loading: _saving),
          ],
        ),
      ),
    );
  }
}

// ── Shared UI Helpers 
Widget _inputField({required BuildContext context, required TextEditingController controller, required IconData icon, required String hint, bool obscure = false, TextInputType? keyboardType}) {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none);
  return TextField(
    controller: controller, obscureText: obscure, keyboardType: keyboardType,
    decoration: InputDecoration(
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Icon(icon, size: 22, color: AppColors.textSecondary(context)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      hintText: hint, filled: true, fillColor: AppColors.surfaceVariant(context),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    ),
  );
}

Widget _actionButton({required String label, required VoidCallback? onPressed, bool loading = false}) {
  return SizedBox(
    width: double.infinity, height: 56,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
      child: loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
    ),
  );
}
