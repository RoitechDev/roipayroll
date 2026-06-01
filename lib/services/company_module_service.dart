import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/core/constants/app_routes.dart';

class CompanyModuleService {
  static const Duration _webPollInterval = Duration(seconds: 20);

  final FirebaseFirestore _firestore;

  CompanyModuleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const List<String> alwaysEnabledModules = [
    'dashboard',
    'settings',
    'users',
  ];

  static const Map<String, bool> defaultModules = {
    'dashboard': true,
    'employees': true,
    'attendance': true,
    'payroll': true,
    'reports': true,
    'settings': true,
    'users': true,
    'leave': false,
    'loans': false,
    'deductions': false,
    'expense': true,
    'salary_advance': false,
    'exit': false,
    'incentives': false,
    'documents': false,
    'compliance': false,
    'probation': false,
    'audit': false,
  };

  static const List<String> moduleDisplayOrder = [
    'dashboard',
    'employees',
    'attendance',
    'payroll',
    'reports',
    'leave',
    'loans',
    'deductions',
    'expense',
    'salary_advance',
    'exit',
    'incentives',
    'documents',
    'compliance',
    'probation',
    'audit',
    'users',
    'settings',
  ];

  static const Map<String, Map<String, bool>> modulePresets = {
    'Core Payroll': {
      'dashboard': true,
      'employees': true,
      'attendance': true,
      'payroll': true,
      'reports': true,
      'settings': true,
      'users': true,
      'audit': true,
      'leave': false,
      'loans': false,
      'deductions': false,
      'expense': false,
      'salary_advance': false,
      'exit': false,
      'incentives': false,
      'documents': false,
      'compliance': false,
      'probation': false,
    },
    'Payroll + HR': {
      'dashboard': true,
      'employees': true,
      'attendance': true,
      'payroll': true,
      'reports': true,
      'settings': true,
      'users': true,
      'audit': true,
      'leave': true,
      'loans': true,
      'deductions': true,
      'expense': false,
      'salary_advance': true,
      'exit': true,
      'incentives': false,
      'documents': false,
      'compliance': false,
      'probation': true,
    },
    'Full Suite': {
      'dashboard': true,
      'employees': true,
      'attendance': true,
      'payroll': true,
      'reports': true,
      'settings': true,
      'users': true,
      'audit': true,
      'leave': true,
      'loans': true,
      'deductions': true,
      'expense': true,
      'salary_advance': true,
      'exit': true,
      'incentives': true,
      'documents': true,
      'compliance': true,
      'probation': true,
    },
  };

  static String moduleLabel(String key) {
    return switch (key) {
      'dashboard' => 'Dashboard',
      'employees' => 'Employees',
      'attendance' => 'Attendance',
      'payroll' => 'Payroll',
      'reports' => 'Reports',
      'leave' => 'Leave',
      'loans' => 'Loans',
      'deductions' => 'Deductions',
      'expense' => 'Expenses',
      'salary_advance' => 'Salary Advance',
      'exit' => 'Exit Management',
      'incentives' => 'Commission & Bonus',
      'documents' => 'Documents',
      'compliance' => 'Compliance',
      'probation' => 'Probation & Contract',
      'audit' => 'Audit Logs',
      'users' => 'Users / Roles',
      'settings' => 'Settings',
      _ => key,
    };
  }

  static Map<String, bool> normalizedModules(Map<String, bool> input) {
    final normalized = Map<String, bool>.from(defaultModules);
    normalized.addAll(input);
    for (final module in alwaysEnabledModules) {
      normalized[module] = true;
    }
    return normalized;
  }

  Future<Map<String, bool>> getCompanyModules(String companyId) async {
    final doc = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('modules')
        .get();

    final merged = Map<String, bool>.from(defaultModules);
    final data = doc.data();
    final enabled = data?['enabled'];
    if (enabled is Map<String, dynamic>) {
      for (final entry in enabled.entries) {
        merged[entry.key] = entry.value == true;
      }
    }

    for (final module in alwaysEnabledModules) {
      merged[module] = true;
    }

    return merged;
  }

  Stream<Map<String, bool>> watchCompanyModules(String companyId) {
    final docRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('modules');

    Map<String, bool> parseModules(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final merged = Map<String, bool>.from(defaultModules);
      final data = snapshot.data();
      final enabled = data?['enabled'];
      if (enabled is Map<String, dynamic>) {
        for (final entry in enabled.entries) {
          merged[entry.key] = entry.value == true;
        }
      }
      for (final module in alwaysEnabledModules) {
        merged[module] = true;
      }
      return merged;
    }

    if (kIsWeb) {
      return (() async* {
        yield parseModules(await docRef.get());
        yield* Stream.periodic(
          _webPollInterval,
        ).asyncMap((_) async => parseModules(await docRef.get()));
      })();
    }

    return docRef.snapshots().map(parseModules);
  }

  Future<void> saveCompanyModules({
    required String companyId,
    required String updatedBy,
    required Map<String, bool> enabledModules,
  }) async {
    final normalized = normalizedModules(enabledModules);

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('modules')
        .set({
          'enabled': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        }, SetOptions(merge: true));
  }

  bool isRouteEnabledInMap(String routeName, Map<String, bool> enabledModules) {
    final module = moduleForRoute(routeName);
    if (module == null) return true;
    return isModuleEnabledInMap(module, enabledModules);
  }

  static bool isModuleEnabledInMap(String module, Map<String, bool> modules) {
    if (alwaysEnabledModules.contains(module)) return true;
    return modules[module] ?? defaultModules[module] ?? false;
  }

  String? moduleForRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) return null;

    if (routeName.startsWith('/login') ||
        routeName.startsWith('/register') ||
        routeName.startsWith('/forgot-password')) {
      return null;
    }

    if (routeName == AppRoutes.dashboard) return 'dashboard';
    if (routeName == AppRoutes.notifications) return 'dashboard';
    if (routeName.startsWith('/employees')) return 'employees';
    if (routeName.startsWith('/attendance')) return 'attendance';
    if (routeName.startsWith('/payroll')) return 'payroll';
    if (routeName.startsWith('/reports')) return 'reports';
    if (routeName == AppRoutes.auditLogs) return 'audit';
    if (routeName.startsWith('/leave')) return 'leave';
    if (routeName.startsWith('/loans')) return 'loans';
    if (routeName.startsWith('/deductions')) return 'deductions';
    if (routeName.startsWith('/expenses')) return 'expense';
    if (routeName == AppRoutes.salaryAdvances) return 'salary_advance';
    if (routeName == AppRoutes.exitManagement) return 'exit';
    if (routeName.startsWith('/incentives')) return 'incentives';
    if (routeName.startsWith('/documents')) return 'documents';
    if (routeName.startsWith('/compliance')) return 'compliance';
    if (routeName == AppRoutes.probation) return 'probation';
    if (routeName.startsWith('/users')) return 'users';
    if (routeName.startsWith('/settings')) return 'settings';

    return null;
  }
}
