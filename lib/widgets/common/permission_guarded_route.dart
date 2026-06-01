import 'package:flutter/material.dart';
import 'package:roipayroll/screens/common/unauthorized_screen.dart';
import 'package:roipayroll/services/company_module_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';

class PermissionGuardedRoute extends StatelessWidget {
  final Permission requiredPermission;
  final Widget child;

  const PermissionGuardedRoute({
    super.key,
    required this.requiredPermission,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final moduleService = CompanyModuleService();
    return FutureBuilder(
      future: UserService().getCurrentUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const UnauthorizedScreen(
            message: 'No active user profile found.',
          );
        }

        if (!PermissionService.hasPermission(user, requiredPermission)) {
          return UnauthorizedScreen(
            message: 'You need ${requiredPermission.name} permission.',
          );
        }

        return FutureBuilder<Map<String, bool>>(
          future: moduleService.getCompanyModules(user.companyId),
          builder: (context, modulesSnapshot) {
            if (modulesSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final routeName = ModalRoute.of(context)?.settings.name;
            final modules =
                modulesSnapshot.data ??
                Map<String, bool>.from(CompanyModuleService.defaultModules);
            final isEnabled = moduleService.isRouteEnabledInMap(
              routeName ?? '',
              modules,
            );
            if (!isEnabled) {
              final moduleKey = moduleService.moduleForRoute(routeName);
              return UnauthorizedScreen(
                message:
                    '${CompanyModuleService.moduleLabel(moduleKey ?? 'This module')} is disabled for your company.',
              );
            }

            return child;
          },
        );
      },
    );
  }
}
