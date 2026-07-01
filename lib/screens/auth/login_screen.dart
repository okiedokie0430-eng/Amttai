import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.loginWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (auth.isLoggedIn) {
      context.go('/home');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final textSecondary = AppColors.textSecondary(context);

    return AuthScaffold(
      formKey: _formKey,
      title: 'Login',
      subtitle: 'Welcome! Join your Amttai journey.',
      children: [
        AuthTextField(
          controller: _emailCtrl,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return S.requiredField;
            if (!v.contains('@')) return S.invalidEmail;
            return null;
          },
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _passwordCtrl,
          label: 'Password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (v) {
            if (v == null || v.isEmpty) return S.requiredField;
            if (v.length < 8) return 'At least 8 characters required';
            return null;
          },
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/forgot-password'),
            child: Text(
              'FORGOT PASSWORD',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                decoration: TextDecoration.underline,
                decorationColor: textSecondary,
                decorationThickness: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        AuthButton(
          onPressed: auth.isLoading ? null : _submit,
          isLoading: auth.isLoading,
          label: 'LET\'S START COOKING!',
        ),
      ],
    );
  }
}
