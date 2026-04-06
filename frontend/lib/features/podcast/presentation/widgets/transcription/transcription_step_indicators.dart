import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_step_mapper.dart';

class TranscriptionStepDescriptor {
  const TranscriptionStepDescriptor({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class TranscriptionStepIndicators extends StatelessWidget {
  const TranscriptionStepIndicators({
    required this.progressPercentage, required this.steps, super.key,
  });

  final double progressPercentage;
  final List<TranscriptionStepDescriptor> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;
        final status = transcriptionStepStatusAt(progressPercentage, index);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TranscriptionStepIndicator(
              icon: step.icon,
              label: step.label,
              status: status,
            ),
            if (!isLast)
              _ConnectorLine(
                highlighted: transcriptionConnectorHighlighted(
                  progressPercentage,
                  index,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class TranscriptionStatusStepIcon extends StatelessWidget {
  const TranscriptionStatusStepIcon({required this.step, super.key});

  final int step;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 1:
        return const Icon(Icons.download, size: 16, color: Colors.blue);
      case 2:
        return const Icon(Icons.transform, size: 16, color: Colors.orange);
      case 3:
        return const Icon(Icons.content_cut, size: 16, color: Colors.purple);
      case 4:
        return const Icon(Icons.transcribe, size: 16, color: Colors.teal);
      case 5:
        return const Icon(Icons.merge_type, size: 16, color: Colors.green);
      default:
        return const Icon(Icons.pending, size: 16, color: Colors.grey);
    }
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Center(
        child: Container(
          height: 2,
          width: 16,
          color: highlighted
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _TranscriptionStepIndicator extends StatelessWidget {
  const _TranscriptionStepIndicator({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final TranscriptionStepStatus status;

  @override
  Widget build(BuildContext context) {
    final (iconColor, backgroundColor) = _resolveColor(context, status);

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            status == TranscriptionStepStatus.completed ? Icons.check : icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.navLabel(
            iconColor,
            weight: status == TranscriptionStepStatus.current
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (Color, Color) _resolveColor(
    BuildContext context,
    TranscriptionStepStatus status,
  ) {
    switch (status) {
      case TranscriptionStepStatus.completed:
        return (Colors.green, Colors.green.withValues(alpha: 0.1));
      case TranscriptionStepStatus.current:
        return (
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        );
      case TranscriptionStepStatus.pending:
        return (
          Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          Theme.of(context).colorScheme.surface,
        );
    }
  }
}
