import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';

enum TrendDirection { up, down, neutral }

class ModernMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? trend;
  final TrendDirection trendDirection;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ModernMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendDirection = TrendDirection.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = switch (trendDirection) {
      TrendDirection.up => AppColors.success,
      TrendDirection.down => AppColors.error,
      TrendDirection.neutral => AppColors.textSecondary,
    };

    final trendIcon = switch (trendDirection) {
      TrendDirection.up => Icons.trending_up,
      TrendDirection.down => Icons.trending_down,
      TrendDirection.neutral => Icons.trending_flat,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (trend != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(trendIcon, size: 14, color: trendColor),
                          const SizedBox(width: 4),
                          Text(
                            trend!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: trendColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModernMetricsGrid extends StatelessWidget {
  final List<Widget> metrics;

  const ModernMetricsGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 1;
        double aspect = 2.6;

        if (constraints.maxWidth >= 1300) {
          columns = 4;
          aspect = 2.5;
        } else if (constraints.maxWidth >= 900) {
          columns = 2;
          aspect = 2.3;
        }

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspect,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: metrics,
        );
      },
    );
  }
}
