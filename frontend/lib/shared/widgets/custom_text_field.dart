import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    required this.controller,
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
  });
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FormFieldState<String>? _formFieldState;

  void _handleChanged(String value) {
    _formFieldState?.didChange(value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return _buildCupertino(context);
    }
    return _buildMaterial(context);
  }

  Widget _buildLabel(BuildContext context) {
    if (widget.label == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label!,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        SizedBox(height: context.spacing.sm),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: enabled
                ? Theme.of(context).inputDecorationTheme.fillColor
                : Theme.of(context).disabledColor.withValues(alpha: 0.12),
            border: Theme.of(context).inputDecorationTheme.border,
            enabledBorder:
                Theme.of(context).inputDecorationTheme.enabledBorder,
            focusedBorder:
                Theme.of(context).inputDecorationTheme.focusedBorder,
            errorBorder: Theme.of(context).inputDecorationTheme.errorBorder,
            contentPadding:
                Theme.of(context).inputDecorationTheme.contentPadding,
            hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
          ),
        ),
      ],
    );
  }

  bool get enabled => widget.enabled;

  Widget _buildCupertino(BuildContext context) {
    final theme = Theme.of(context);
    final cupertinoField = CupertinoTextField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      onChanged: _handleChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      placeholder: widget.hint,
      placeholderStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      style: theme.textTheme.bodyMedium,
      prefix: widget.prefixIcon != null
          ? Padding(
              padding: EdgeInsets.only(left: context.spacing.md),
              child: IconTheme(
                data: IconThemeData(
                  color: widget.enabled
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
                child: widget.prefixIcon!,
              ),
            )
          : null,
      suffix: widget.suffixIcon != null
          ? Padding(
              padding: EdgeInsets.only(right: context.spacing.sm),
              child: widget.suffixIcon,
            )
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.md,
      ),
      inputFormatters: widget.maxLength != null
          ? [LengthLimitingTextInputFormatter(widget.maxLength)]
          : null,
      decoration: BoxDecoration(
        color: widget.enabled
            ? CupertinoColors.tertiarySystemFill
            : CupertinoColors.quaternarySystemFill,
        borderRadius:
            BorderRadius.circular(appThemeOf(context).buttonRadius),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context),
        if (widget.validator != null)
          FormField<String>(
            initialValue: widget.controller.text,
            validator: widget.validator,
            builder: (field) {
              _formFieldState = field;
              final error = widget.errorText ?? field.errorText;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cupertinoField,
                  if (error != null)
                    Padding(
                      padding: EdgeInsets.only(
                        left: context.spacing.smMd,
                        top: context.spacing.xs,
                      ),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize:
                              theme.textTheme.bodySmall?.fontSize ?? 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else ...[
          cupertinoField,
          if (widget.errorText != null)
            Padding(
              padding: EdgeInsets.only(
                left: context.spacing.smMd,
                top: context.spacing.xs,
              ),
              child: Text(
                widget.errorText!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
