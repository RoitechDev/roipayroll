import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/services/auth_service.dart';

class ModernLoadingState extends StatelessWidget {
  final String message;

  const ModernLoadingState({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, _) {
        return Container(
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ModernEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 160;
        final isVeryCompact = constraints.maxHeight < 90;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 8 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isVeryCompact) ...[
                  Icon(
                    icon,
                    size: isCompact ? 32 : 56,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null && !isCompact) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (action != null && !isCompact) ...[
                  const SizedBox(height: 12),
                  action!,
                ] else if (actionLabel != null &&
                    onAction != null &&
                    !isCompact) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ModernErrorState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ModernErrorState({
    super.key,
    required this.message,
    this.subtitle,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 180;
        final isVeryCompact = constraints.maxHeight < 90;

        final permissionDenied = (subtitle ?? '')
                .toLowerCase()
                .contains('permission-denied') ||
            (subtitle ?? '')
                .toLowerCase()
                .contains('missing or insufficient permissions');

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 8 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isVeryCompact) ...[
                  Icon(
                    Icons.error_outline,
                    size: isCompact ? 32 : 56,
                    color: AppColors.error,
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                ],
                Text(message, textAlign: TextAlign.center),
                if (subtitle != null && !isCompact) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                if (onRetry != null && !isCompact) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
                if (!isCompact &&
                    (actionLabel != null && onAction != null)) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ] else if (!isCompact && permissionDenied) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await AuthService().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                    child: const Text('Re-login'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
