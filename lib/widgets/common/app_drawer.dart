import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'user_avatar.dart';

/// Left-side drawer with profile info + menu items.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // ── Big glow from top-left corner ──
          Positioned(
            top: -40,
            left: -40,
            width: 220,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.primary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── User info ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile-edit');
                    },
                    child: Row(
                      children: [
                        // Profile avatar with actual image
                        UserAvatar(
                          photoUrl: user?.photoUrl,
                          name: user?.name,
                          isPremium: auth.hasPremium,
                          size: 56,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user?.name ?? '',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // V1.0: FREE/PREMIUM badge hidden — restore for V1.1.
                                  /* const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: auth.hasPremium
                                          ? AppColors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.border(context),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      auth.hasPremium
                                          ? S.activePremium
                                          : S.freePlan,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: auth.hasPremium
                                            ? AppColors.primary
                                            : AppColors.textSecondary(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ), */
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary(context),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Divider(color: AppColors.border(context), height: 1),
                const SizedBox(height: 8),

                // ── Menu items ──
                // V1.0: Premium navigation tile hidden — restore for V1.1.
                /* _tile(
                  context,
                  Icons.workspace_premium_outlined,
                  S.premiumTitle,
                  subtitle: auth.hasPremium ? S.activePremium : S.noPremium,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/premium');
                  },
                ),
                const SizedBox(height: 4), */
                _tile(
                  context,
                  themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  S.darkMode,
                  trailing: Switch.adaptive(
                    value: themeProvider.isDark,
                    activeTrackColor: AppColors.primary,
                    onChanged: (_) => themeProvider.toggle(),
                  ),
                ),

                _tile(
                  context,
                  Icons.notifications_outlined,
                  S.notifications,
                  onTap: () {},
                ),

                _tile(
                  context,
                  Icons.settings_outlined,
                  S.settings,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),

                const SizedBox(height: 8),
                Divider(color: AppColors.border(context), height: 1),
                const SizedBox(height: 8),

                _tile(
                  context,
                  Icons.headset_mic_outlined,
                  S.customerService,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/support');
                  },
                ),

                _tile(
                  context,
                  Icons.feedback_outlined,
                  S.leaveFeedback,
                  onTap: () {},
                ),

                const Spacer(),

                // ── Logout ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await auth.logout();
                        if (context.mounted) context.go('/welcome');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        S.logout,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    '${S.privacyPolicy}  ·  ${S.termsOfService}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary(context),
                      fontSize: 11,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppColors.textPrimary(context)),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(context),
              ),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textTertiary(context),
                )
              : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: 0),
    );
  }
}
