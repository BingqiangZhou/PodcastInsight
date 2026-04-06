import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
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
          message: '${l10n.podcast_failed_add} $error',
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        tier: GlassTier.overlay,
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.podcast_add_dialog_title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _feedUrlController,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: l10n.podcast_rss_feed_url,
                        hintText: l10n.podcast_feed_url_hint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.rss_feed),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.podcast_enter_url;
                        }
                        if (!value.startsWith('http')) {
                          return l10n.validation_invalid_url;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addSubscription,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(
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
    );
  }
}
