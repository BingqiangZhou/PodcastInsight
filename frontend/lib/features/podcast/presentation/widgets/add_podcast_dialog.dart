import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

class AddPodcastDialog extends ConsumerStatefulWidget {
  const AddPodcastDialog({super.key});

  @override
  ConsumerState<AddPodcastDialog> createState() => _AddPodcastDialogState();
}

class _AddPodcastDialogState extends ConsumerState<AddPodcastDialog> {
  final _formKey = GlobalKey<FormState>();
  final _feedUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedUrlController.dispose();
    super.dispose();
  }

  Future<void> _addSubscription() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: _feedUrlController.text.trim());

      if (mounted) {
        Navigator.of(context).pop();
        showTopFloatingNotice(
          context,
          message: context.l10n.podcast_added_successfully,
        );
      }
    } catch (error) {
      if (mounted) {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.podcast_failed_add,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dialogMaxWidth = ResponsiveDialogHelper.maxWidth(context, desktopMaxWidth: 500);
    final dialogMaxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: ResponsiveDialogHelper.insetPadding(),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.xxlRadius,
        ),
        padding: EdgeInsets.all(context.spacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: dialogMaxHeight),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.podcast_add_dialog_title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: context.spacing.lg),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AdaptiveTextField(
                      controller: _feedUrlController,
                      placeholder: l10n.podcast_feed_url_hint,
                      decoration: InputDecoration(
                        labelText: l10n.podcast_rss_feed_url,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.rss_feed),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.spacing.smMd,
                          vertical: context.spacing.smMd,
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.podcast_enter_url;
                        }
                        if (!(value.startsWith('http://') || value.startsWith('https://'))) {
                          return l10n.validation_invalid_url;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  SizedBox(width: context.spacing.md),
                  AdaptiveButton(
                    onPressed: _isLoading ? null : _addSubscription,
                    isLoading: _isLoading,
                    icon: const Icon(Icons.add),
                    child: Text(
                      _isLoading
                          ? l10n.podcast_adding
                          : l10n.podcast_add_dialog_title,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
