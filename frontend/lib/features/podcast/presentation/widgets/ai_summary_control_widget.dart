import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../podcast/data/models/podcast_playback_model.dart';
import '../providers/summary_providers.dart';

/// AI summary controls for generating and regenerating summaries.
class AISummaryControlWidget extends ConsumerStatefulWidget {
  final int episodeId;
  final bool hasTranscript;
  final VoidCallback? onSummaryGenerated;
  final bool compact;

  const AISummaryControlWidget({
    super.key,
    required this.episodeId,
    required this.hasTranscript,
    this.onSummaryGenerated,
    this.compact = false,
  });

  @override
  ConsumerState<AISummaryControlWidget> createState() =>
      _AISummaryControlWidgetState();
}

class _AISummaryControlWidgetState
    extends ConsumerState<AISummaryControlWidget> {
  SummaryModelInfo? _selectedModel;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modelsAsync = ref.read(availableModelsProvider);
      modelsAsync.when(
        data: (models) {
          if (models.isEmpty) {
            return;
          }

          final defaultModel = models.firstWhere(
            (model) => model.isDefault,
            orElse: () => models.first,
          );
          if (mounted) {
            setState(() => _selectedModel = defaultModel);
          }
        },
        loading: () {},
        error: (_, _) {},
      );
    });
  }

  void _generateSummary() {
    final provider = getSummaryProvider(widget.episodeId);
    ref.read(provider.notifier).generateSummary(model: _resolvedModelName());
  }

  void _regenerateSummary() {
    final provider = getSummaryProvider(widget.episodeId);
    ref.read(provider.notifier).regenerateSummary(model: _resolvedModelName());
  }

  String? _resolvedModelName() {
    if (_selectedModel != null) {
      return _selectedModel!.name;
    }

    final models = ref.read(availableModelsProvider).asData?.value;
    if (models == null || models.isEmpty) {
      return null;
    }

    return models
        .firstWhere((model) => model.isDefault, orElse: () => models.first)
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final provider = getSummaryProvider(widget.episodeId);
    final summaryState = ref.watch(provider);
    final availableModelsAsync = ref.watch(availableModelsProvider);

    if (!widget.hasTranscript) {
      return _buildNoTranscriptMessage(context);
    }

    return availableModelsAsync.when(
      data: (availableModels) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!summaryState.hasSummary && !summaryState.isLoading)
              _buildGenerateControls(
                context,
                availableModels,
                isLoading: summaryState.isLoading,
              )
            else if (summaryState.hasSummary)
              _buildRegenerateControls(context, availableModels, summaryState)
            else
              _buildLoadingState(context),
            if (summaryState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildErrorMessage(context, summaryState.errorMessage!),
              ),
          ],
        );
      },
      loading: () => _buildLoadingState(context),
      error: (_, _) => _buildLoadingState(context),
    );
  }

  Widget _buildNoTranscriptMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.podcast_summary_transcription_required,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateControls(
    BuildContext context,
    List<SummaryModelInfo> models, {
    required bool isLoading,
  }) {
    final isCompact = widget.compact;
    final hasModelOptions = models.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : _generateSummary,
          icon: Icon(Icons.auto_awesome, size: isCompact ? 16 : 18),
          label: Text(AppLocalizations.of(context)!.podcast_summary_generate),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 24,
              vertical: isCompact ? 10 : 12,
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: isCompact ? 13 : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hasModelOptions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => setState(() => _showOptions = !_showOptions),
              icon: Icon(
                _showOptions ? Icons.expand_less : Icons.expand_more,
                size: isCompact ? 16 : 18,
              ),
              label: Text(
                AppLocalizations.of(context)!.podcast_advanced_options,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 6 : 8,
                ),
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: isCompact ? 12 : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (_showOptions && hasModelOptions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAdvancedOptions(context, models),
          ),
      ],
    );
  }

  Widget _buildRegenerateControls(
    BuildContext context,
    List<SummaryModelInfo> models,
    SummaryState summaryState,
  ) {
    final isCompact = widget.compact;
    final hasModelOptions = models.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summaryState.modelUsed != null ||
            summaryState.processingTime != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 16,
              children: [
                if (summaryState.modelUsed != null)
                  _buildMetadataItem(
                    context,
                    Icons.psychology_outlined,
                    summaryState.modelUsed!,
                  ),
                if (summaryState.processingTime != null)
                  _buildMetadataItem(
                    context,
                    Icons.schedule_outlined,
                    '${summaryState.processingTime!.toStringAsFixed(1)}s',
                  ),
                if (summaryState.wordCount != null)
                  _buildMetadataItem(
                    context,
                    Icons.text_fields,
                    '${summaryState.wordCount} ${AppLocalizations.of(context)!.podcast_summary_chars}',
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: summaryState.isLoading ? null : _regenerateSummary,
                icon: Icon(Icons.refresh, size: isCompact ? 16 : 18),
                label: Text(AppLocalizations.of(context)!.podcast_regenerate),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 16,
                    vertical: isCompact ? 8 : 10,
                  ),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: isCompact ? 13 : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (hasModelOptions) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _showOptions = !_showOptions),
                iconSize: isCompact ? 18 : 20,
                visualDensity: isCompact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: BoxConstraints.tightFor(
                  width: isCompact ? 36 : 40,
                  height: isCompact ? 36 : 40,
                ),
                icon: Icon(
                  _showOptions ? Icons.expand_less : Icons.expand_more,
                ),
                tooltip: AppLocalizations.of(context)!.podcast_advanced_options,
              ),
            ],
          ],
        ),
        if (_showOptions && hasModelOptions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAdvancedOptions(context, models),
          ),
      ],
    );
  }

  Widget _buildMetadataItem(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions(
    BuildContext context,
    List<SummaryModelInfo> models,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<SummaryModelInfo>(
        initialValue: _selectedModel,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.podcast_ai_model,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: models.map((model) {
          return DropdownMenuItem<SummaryModelInfo>(
            value: model,
            child: Row(
              children: [
                Text(model.displayName),
                if (model.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.podcast_default_model,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedModel = value);
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.podcast_generating_summary,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            iconSize: 16,
            icon: const Icon(Icons.close),
            onPressed: () {
              final provider = getSummaryProvider(widget.episodeId);
              ref.read(provider.notifier).clearError();
            },
          ),
        ],
      ),
    );
  }
}
