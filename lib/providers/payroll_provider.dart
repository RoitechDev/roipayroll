import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/system_alert_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/services/payroll_service.dart';

class PayrollPeriod {
  final int month;
  final int year;

  const PayrollPeriod({required this.month, required this.year});

  factory PayrollPeriod.now() {
    final now = DateTime.now();
    return PayrollPeriod(month: now.month, year: now.year);
  }

  @override
  bool operator ==(Object other) {
    return other is PayrollPeriod && other.month == month && other.year == year;
  }

  @override
  int get hashCode => Object.hash(month, year);
}

class PayrollHistorySummary {
  final List<Payroll> payrolls;
  final bool isMonthLocked;

  const PayrollHistorySummary({
    required this.payrolls,
    required this.isMonthLocked,
  });
}

final payrollAlertsProvider =
    FutureProvider.family<List<SystemAlert>, PayrollPeriod>((
      ref,
      period,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      return PayrollService().generateSystemAlerts(period.month, period.year);
    });

final payrollPreviewProvider =
    FutureProvider.family<PayrollPreview, PayrollPeriod>((ref, period) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      return PayrollService().simulatePayroll(period.month, period.year);
    });

final payrollHistoryProvider =
    FutureProvider.family<PayrollHistorySummary, PayrollPeriod>((
      ref,
      period,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final payrolls = await PayrollService().getPayrollsByMonth(
        period.month,
        period.year,
      );
      return PayrollHistorySummary(
        payrolls: payrolls,
        isMonthLocked: payrolls.any((payroll) => payroll.isLocked),
      );
    });
