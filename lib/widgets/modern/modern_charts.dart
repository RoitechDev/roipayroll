import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';

class ModernMiniBarChart extends StatelessWidget {
  final List<double> values;

  const ModernMiniBarChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (v) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 100 * (v / max),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
