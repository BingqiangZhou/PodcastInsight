import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/shared/widgets/custom_text_field.dart';

class PasswordTextField extends StatelessWidget {
  const PasswordTextField({
    required this.controller, required this.label, required this.obscureText, required this.onToggleVisibility, super.key,
    this.validator,
    this.errorText,
    this.onChanged,
    this.toggleButtonKey,
    this.autofillHints,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Key? toggleButtonKey;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      obscureText: obscureText,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: Semantics(
        button: true,
        label: obscureText ? 'Show password' : 'Hide password',
        child: IconButton(
          key: toggleButtonKey,
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
      ),
      onChanged: onChanged,
      validator: validator,
      errorText: errorText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
    );
  }
}
