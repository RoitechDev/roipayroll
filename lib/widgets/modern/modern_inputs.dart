import 'package:flutter/material.dart';

class ModernTextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const ModernTextInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
