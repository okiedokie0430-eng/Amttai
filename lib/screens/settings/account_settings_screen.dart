import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/gesture_exclusion_scope.dart';

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
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final success = await context.read<AuthProvider>().deleteAccount();
      if (success && mounted) context.go('/welcome');
    } catch (e) {
      if (mounted) _showSnack('Error deleting account: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildSectionTitle(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 12, top: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(
      color: color.withValues(alpha: 0.15),
      height: 1,
      thickness: 1,
      indent: 28,
      endIndent: 28,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureExclusionScope(
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textSecondary,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'General Settings',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.8,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              _buildSectionTitle('Account', textSecondary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.email_rounded,
                      title: 'Change Email',
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _ChangeEmailScreen(),
                        ),
                      ),
                    ),
                    _buildDivider(textSecondary),
                    _SettingsTile(
                      icon: Icons.lock_rounded,
                      title: 'Change Password',
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _ChangePasswordScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Preferences', textSecondary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_rounded,
                      title: S.notifications,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () =>
                          setState(() => _notifications = !_notifications),
                      trailing: Switch.adaptive(
                        value: _notifications,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.25,
                        ),
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Danger Zone', textSecondary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: _deleting ? 'Deleting...' : 'Delete Account',
                  textColor: textPrimary,
                  iconColor: textSecondary,
                  isDestructive: true,
                  onTap: _deleting ? () {} : _deleteAccount,
                  trailing: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.isDestructive
        ? Colors.redAccent.withValues(alpha: 0.9)
        : widget.iconColor.withValues(alpha: 0.7);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Icon(widget.icon, color: effectiveIconColor, size: 22),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.isDestructive
                        ? Colors.redAccent
                        : widget.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (widget.trailing != null)
                widget.trailing!
              else if (!widget.isDestructive)
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.iconColor.withValues(alpha: 0.35),
                  size: 20,
                ),
            ],
          ),
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
  void dispose() {
    _newEmailCtrl.dispose();
    _emailPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    final email = _newEmailCtrl.text.trim();
    final password = _emailPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid email address')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().changeEmail(
        newEmail: email,
        password: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email changed successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textSecondary,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Email',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          children: [
            _inputField(
              context: context,
              controller: _newEmailCtrl,
              icon: Icons.email_rounded,
              hint: 'New email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _inputField(
              context: context,
              controller: _emailPasswordCtrl,
              icon: Icons.lock_rounded,
              hint: 'Current password',
              obscure: true,
            ),
            const SizedBox(height: 40),
            _MinimalButton(
              label: 'Change Email',
              onPressed: _saving ? null : _changeEmail,
              loading: _saving,
            ),
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
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPw = _oldPasswordCtrl.text.trim();
    final newPw = _newPasswordCtrl.text.trim();
    if (oldPw.isEmpty || newPw.isEmpty) return;
    if (newPw.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 8 characters required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().changePassword(
        oldPassword: oldPw,
        newPassword: newPw,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textSecondary,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          children: [
            _inputField(
              context: context,
              controller: _oldPasswordCtrl,
              icon: Icons.lock_rounded,
              hint: 'Old password',
              obscure: true,
            ),
            const SizedBox(height: 16),
            _inputField(
              context: context,
              controller: _newPasswordCtrl,
              icon: Icons.lock_rounded,
              hint: 'Шинэ нууц үг',
              obscure: true,
            ),
            const SizedBox(height: 40),
            _MinimalButton(
              label: 'Save Password',
              onPressed: _saving ? null : _changePassword,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared UI Helpers ─────────────────────────────────────────────────

Widget _inputField({
  required BuildContext context,
  required TextEditingController controller,
  required IconData icon,
  required String hint,
  bool obscure = false,
  TextInputType? keyboardType,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );
  return TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Icon(
          icon,
          size: 22,
          color: AppColors.textSecondary(context).withValues(alpha: 0.7),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceVariant(context).withValues(alpha: 0.6),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    ),
  );
}

class _MinimalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _MinimalButton({
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  State<_MinimalButton> createState() => _MinimalButtonState();
}

class _MinimalButtonState extends State<_MinimalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            },
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.onPressed == null
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary.withValues(
                      alpha: widget.onPressed == null ? 0.3 : 1.0,
                    ),
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.onPressed == null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
