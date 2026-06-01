import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/global_error_state.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/widgets/common/app_sidebar.dart';
import 'package:roipayroll/widgets/common/app_topbar.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final String title;
  final Widget? child;
  final Widget? body;
  final Widget? headerActions;
  final bool showSearch;
  final Widget? topBar;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    this.title = '',
    this.child,
    this.body,
    this.headerActions,
    this.showSearch = false,
    this.topBar,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
    this.floatingActionButton,
  });

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _collapsed = false;
  bool _userToggled = false;
  final _authService = AuthService();

  void _toggleSidebar() {
    setState(() {
      _collapsed = !_collapsed;
      _userToggled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.child ?? widget.body ?? const SizedBox.shrink();
    final topBar = widget.topBar ??
        AppTopBar(
          title: widget.title,
          showSearch: widget.showSearch,
          actions: widget.headerActions,
        );
    final constrainedTopBar = topBar is PreferredSizeWidget
        ? SizedBox(height: topBar.preferredSize.height, child: topBar)
        : topBar;
    return LayoutBuilder(
      builder: (context, constraints) {
        final forceCollapsed = constraints.maxWidth < 1100;
        final isCollapsed = forceCollapsed
            ? (_userToggled ? _collapsed : true)
            : _collapsed;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          floatingActionButton: widget.floatingActionButton,
          body: Row(
            children: [
              AppSidebar(
                isCollapsed: isCollapsed,
                onToggle: _toggleSidebar,
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF4F7FB),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: globalErrorState,
                        builder: (context, _) {
                          final error = globalErrorState.current;
                          if (error == null) return const SizedBox.shrink();
                          return _buildPermissionBanner(error);
                        },
                      ),
                      constrainedTopBar,
                      Expanded(
                        child: widget.scrollable
                            ? SingleChildScrollView(
                                padding: widget.padding,
                                child: content,
                              )
                            : Padding(
                                padding: widget.padding,
                                child: content,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionBanner(GlobalErrorInfo error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.error,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Permission denied. Please re-login or retry.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(appManualRefreshControllerProvider)
                  .add(DateTime.now().millisecondsSinceEpoch);
              globalErrorState.clear();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              globalErrorState.clear();
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.error,
            ),
            child: const Text('Re-login'),
          ),
          IconButton(
            onPressed: globalErrorState.clear,
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
