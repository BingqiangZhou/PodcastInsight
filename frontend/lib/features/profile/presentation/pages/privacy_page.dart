import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';

/// Static Privacy Policy page.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SizedBox(),
            SafeArea(
              bottom: false,
              child: ResponsiveContainer(
                maxWidth: 720,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompactHeaderPanel(
                      title: l10n.privacy_policy_title,
                      trailing: HeaderCapsuleActionButton(
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                        circular: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.privacy_policy_title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.privacy_policy_last_updated,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_intro,
                              body: l10n.privacy_section_intro_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_collection,
                              body: l10n.privacy_section_collection_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_usage,
                              body: l10n.privacy_section_usage_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_storage,
                              body: l10n.privacy_section_storage_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_sharing,
                              body: l10n.privacy_section_sharing_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_rights,
                              body: l10n.privacy_section_rights_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_children,
                              body: l10n.privacy_section_children_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_changes,
                              body: l10n.privacy_section_changes_body,
                            ),
                            _buildSection(
                              context,
                              title: l10n.privacy_section_contact,
                              body: l10n.privacy_section_contact_body,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
