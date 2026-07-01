import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/common/gesture_exclusion_scope.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();

    final isDark = themeProvider.isDark;
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
          title: Text(
            'Settings',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              letterSpacing: -0.8,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textSecondary,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // -- APP PREFERENCES --
              _buildSectionTitle('App Preferences', textSecondary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.settings_rounded,
                      title: 'General Settings',
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => context.push('/account-settings'),
                    ),
                    _buildDivider(textSecondary),
                    _SettingsTile(
                      icon: Icons.cloud_download_rounded,
                      title: 'Offline Settings',
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => RecommendationService.openOfflineSettings(),
                    ),
                    _buildDivider(textSecondary),
                    _SettingsTile(
                      icon: isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: S.darkMode,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => themeProvider.toggle(),
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.25,
                        ),
                        onChanged: (_) => themeProvider.toggle(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // -- SUPPORT & ABOUT --
              _buildSectionTitle('Support & About', textSecondary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.headset_mic_rounded,
                      title: S.customerService,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => context.push('/support'),
                    ),
                    _buildDivider(textSecondary),
                    _SettingsTile(
                      icon: Icons.info_rounded,
                      title: S.about,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // -- LOGOUT --
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  textColor: textPrimary,
                  iconColor: textSecondary,
                  isLogout: true,
                  onTap: () async {
                    await auth.logout();
                    if (context.mounted) context.go('/welcome');
                  },
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
  final bool isLogout;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
    this.trailing,
    this.isLogout = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
              Icon(
                widget.icon,
                color: widget.isLogout
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : widget.iconColor.withValues(alpha: 0.7),
                size: 22,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.isLogout
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
              else if (!widget.isLogout)
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
