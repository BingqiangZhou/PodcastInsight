import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/onboarding_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) {
      context.go('/discover');
    }
  }

  void _goToPage(int page) {
    unawaited(_pageController.animateToPage(
      page,
      duration: AppDurations.scrollAnimation,
      curve: Curves.easeInOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isLastPage = _currentPage == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
              // Top bar with skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: context.spacing.sm, right: context.spacing.sm),
                  child: AdaptiveButton(
                    style: AdaptiveButtonStyle.text,
                    onPressed: _completeOnboarding,
                    child: Text(
                      l10n.onboarding_skip,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: PlatformHelper.isApple(context)
                      ? const BouncingScrollPhysics()
                      : null,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    _OnboardingScreen(
                      icon: Icons.podcasts_rounded,
                      iconBackgroundColor: isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primaryContainer,
                      iconColor: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      title: l10n.onboarding_welcome_title,
                      subtitle: l10n.onboarding_welcome_subtitle,
                      body: l10n.onboarding_welcome_body,
                    ),
                    _OnboardingScreen(
                      icon: Icons.auto_awesome_rounded,
                      iconBackgroundColor: isDark
                          ? AppColors.accentWarmDark.withValues(alpha: 0.15)
                          : const Color(0xFFFEF3C7),
                      iconColor: isDark
                          ? AppColors.accentWarmDark
                          : AppColors.accentWarm,
                      title: l10n.onboarding_summary_title,
                      body: l10n.onboarding_summary_body,
                    ),
                    _OnboardingScreen(
                      icon: Icons.chat_bubble_rounded,
                      iconBackgroundColor: isDark
                          ? AppColors.accentCoralLight.withValues(alpha: 0.15)
                          : const Color(0xFFFCE7F3),
                      iconColor: isDark
                          ? AppColors.accentCoralLight
                          : AppColors.accentCoral,
                      title: l10n.onboarding_chat_title,
                      body: l10n.onboarding_chat_body,
                    ),
                  ],
                ),
              ),

              // Bottom section: dot indicators + action button
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.lg, context.spacing.md, context.spacing.lg, context.spacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pageCount, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: AppDurations.entranceNormal,
                          margin: EdgeInsets.symmetric(horizontal: context.spacing.xs),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? scheme.primary
                                : scheme.outlineVariant,
                            borderRadius: AppRadius.xsRadius,
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: context.spacing.xl),

                    // Action button
                    AdaptiveButton(
                      style: AdaptiveButtonStyle.filled,
                      onPressed: isLastPage
                          ? _completeOnboarding
                          : () => _goToPage(_currentPage + 1),
                      child: Text(
                        isLastPage
                            ? l10n.onboarding_get_started
                            : l10n.onboarding_next,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// A single onboarding screen with an icon, title, optional subtitle, and body.
class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen({
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.body,
    this.subtitle,
  });

  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: iconColor,
            ),
          ),
          SizedBox(height: context.spacing.xxl),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),

          // Subtitle (optional, used for welcome screen)
          if (subtitle != null) ...[
            SizedBox(height: context.spacing.smMd),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          SizedBox(height: context.spacing.mdLg),

          // Body
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
