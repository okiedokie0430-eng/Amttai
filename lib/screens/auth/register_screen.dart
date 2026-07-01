import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import 'auth_widgets.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return S.requiredField;
    if (v.length < 8) return 'Minimum 8 characters required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      formKey: _formKey,
      title: 'Register',
      subtitle: 'Welcome! Discover the best Mongolian recipes.',
      children: [
        AuthTextField(
          controller: _nameCtrl,
          label: 'Name',
          textInputAction: TextInputAction.next,
          validator: (v) =>
              v == null || v.trim().isEmpty ? S.requiredField : null,
        ),
        const SizedBox(height: 24),
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
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _confirmCtrl,
          label: 'Confirm Password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (v) {
            if (v != _passwordCtrl.text) return S.passwordMismatch;
            return null;
          },
        ),
        const SizedBox(height: 48),
        AuthButton(
          onPressed: auth.isLoading ? null : _submit,
          isLoading: auth.isLoading,
          label: 'REGISTER',
        ),
      ],
    );
  }
}
