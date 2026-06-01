import 'package:flutter/material.dart';

class ModernPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const ModernPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: icon == null
          ? ElevatedButton(onPressed: onPressed, child: Text(label))
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class ModernSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ModernSecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
