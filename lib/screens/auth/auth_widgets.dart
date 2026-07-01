import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Shared scaffold wrapper for all auth screens (login, register, forgot).
/// Provides transparent AppBar, scrollable body, and consistent padding.
class AuthScaffold extends StatelessWidget {
  final GlobalKey<FormState>? formKey;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    this.formKey,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

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
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  title,
                  style: textTheme.headlineLarge?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),
                ...children,
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable text field with a floating underline style for auth forms.
class AuthTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const AuthTextField({
    super.key,
    this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary(context),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// Primary CTA button used across auth screens.
class AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const AuthButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
