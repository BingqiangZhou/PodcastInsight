import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive text field.
///
/// iOS: [CupertinoTextField] with bottom-border-only style.
/// Android: Material [TextField] or [TextFormField] when validator is provided.
class AdaptiveTextField extends StatefulWidget {
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.placeholder,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.validator,
    this.formFieldKey,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final String? placeholder;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final String? Function(String?)? validator;
  final GlobalKey<FormFieldState<String>>? formFieldKey;

  @override
  State<AdaptiveTextField> createState() => _AdaptiveTextFieldState();
}

class _AdaptiveTextFieldState extends State<AdaptiveTextField> {
  String? _errorText;

  void _validate(String? value) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
      });
    }
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
    widget.onFieldSubmitted?.call(value);
    _validate(value);
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    // Clear error when user starts typing
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      final cupertinoField = CupertinoTextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        placeholder: widget.placeholder,
        obscureText: widget.obscureText,
        onChanged: _handleChanged,
        onSubmitted: _handleSubmitted,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(10),
        ),
      );

      if (_errorText != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            cupertinoField,
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      }
      return cupertinoField;
    }

    if (widget.validator != null) {
      return TextFormField(
        key: widget.formFieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscureText,
        onChanged: _handleChanged,
        onFieldSubmitted: _handleSubmitted,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus,
        validator: widget.validator,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.placeholder,
              border: const OutlineInputBorder(),
            ),
      );
    }

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      onChanged: _handleChanged,
      onSubmitted: _handleSubmitted,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      decoration: widget.decoration ??
          InputDecoration(
            hintText: widget.placeholder,
            border: const OutlineInputBorder(),
          ),
    );
  }
}
