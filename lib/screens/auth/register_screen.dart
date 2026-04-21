import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (auth.isLoggedIn) {
      context.go('/home');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return S.requiredField;
    if (v.length < 8) return 'Хамгийн багадаа 8 тэмдэгт';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Том үсэг оруулна уу';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Жижиг үсэг оруулна уу';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Тоо оруулна уу';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final textTheme = Theme.of(context).textTheme;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final inputDecoration = InputDecoration(
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border(context)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      isDense: true,
    );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 26),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Heading
                Text(
                  'Бүртгүүлэх', // Sign Up
                  style: textTheme.headlineLarge?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  "Тавтай морил! Монголын шилдэг жоруудтай танилцаарай.",
                  style: textTheme.titleMedium?.copyWith(
                    color: textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),

                // Name
                Text('Нэр', style: textTheme.titleMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  cursorColor: AppColors.primary,
                  decoration: inputDecoration,
                  validator: (v) => v == null || v.trim().isEmpty ? S.requiredField : null,
                ),
                const SizedBox(height: 24),

                // Email
                Text('И-мэйл', style: textTheme.titleMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  cursorColor: AppColors.primary,
                  decoration: inputDecoration,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return S.requiredField;
                    if (!v.contains('@')) return S.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Password
                Text('Нууц үг', style: textTheme.titleMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  cursorColor: AppColors.primary,
                  decoration: inputDecoration,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),

                // Confirm Password
                Text('Нууц үг баталгаажуулах', style: textTheme.titleMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                  cursorColor: AppColors.primary,
                  decoration: inputDecoration,
                  validator: (v) {
                    if (v != _passwordCtrl.text) return S.passwordMismatch;
                    return null;
                  },
                ),

                const SizedBox(height: 48),

                // Start Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'БҮРТГҮҮЛЭХ', // SIGN UP!
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
