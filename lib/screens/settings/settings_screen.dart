import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  Widget _buildSection({required List<Widget> children, required Color bgColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: color, height: 1, thickness: 1),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onTap,
    Widget? trailing,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? Colors.redAccent : AppColors.primary,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isLogout ? Colors.redAccent : textColor,
                  fontSize: 16,
                  fontWeight: isLogout ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (!isLogout)
              Icon(Icons.chevron_right_rounded, color: iconColor, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    
    final isDark = themeProvider.isDark;
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
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Тохиргоо',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        children: [
          const SizedBox(height: 8),

          // -- APP PREFERENCES SECTION --
          const SizedBox(height: 12),
          _buildSection(
            bgColor: cardColor,
            children: [
              _buildListTile(
                icon: Icons.settings_rounded,
                title: 'Ерөнхий тохиргоо',
                textColor: textPrimary,
                iconColor: textSecondary,
                onTap: () => context.push('/account-settings'),
              ),
              _buildDivider(dividerColor),
              _buildListTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      title: S.darkMode,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => themeProvider.toggle(),
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                        onChanged: (_) => themeProvider.toggle(),
                      ),
                    ),
                  ],
                ),

                // -- SUPPORT & ABOUT SECTION --
                const SizedBox(height: 12),
                _buildSection(
                  bgColor: cardColor,
                  children: [
                    _buildListTile(
                      icon: Icons.workspace_premium_rounded,
                      title: S.subscription,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => context.push('/payment'),
                    ),
                    _buildDivider(dividerColor),
                    _buildListTile(
                      icon: Icons.headset_mic_rounded,
                      title: S.customerService,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () => context.push('/support'),
                    ),
                    _buildDivider(dividerColor),
                    _buildListTile(
                      icon: Icons.info_rounded,
                      title: S.about,
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      onTap: () {},
                    ),
                  ],
                ),

                // -- LOGOUT SECTION --
                const SizedBox(height: 16),
                _buildSection(
                  bgColor: cardColor,
                  children: [
                    _buildListTile(
                      icon: Icons.logout_rounded,
                      title: 'Гарах',
                      textColor: textPrimary,
                      iconColor: textSecondary,
                      isLogout: true,
                      onTap: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/welcome');
                      },
                    ),
                  ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
