import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/public_holiday_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/public_holiday_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class PublicHolidaysScreen extends ConsumerStatefulWidget {
  const PublicHolidaysScreen({super.key});

  @override
  ConsumerState<PublicHolidaysScreen> createState() =>
      _PublicHolidaysScreenState();
}

class _PublicHolidaysScreenState extends ConsumerState<PublicHolidaysScreen> {
  final _holidayService = PublicHolidayService();
  int _selectedYear = DateTime.now().year;

  Future<void> _initializeDefaults() async {
    NotificationHelper.showLoading(
      context,
      message: 'Initializing holidays...',
    );
    try {
      await _holidayService.initializeDefaultHolidays();
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Nigerian public holidays initialized for 2026!',
      );
      ref.invalidate(
        publicHolidaysProvider(PublicHolidaysQuery(year: _selectedYear)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  Future<void> _addHoliday() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    DateTime selectedDate = DateTime.now();
    HolidayType type = HolidayType.national;
    String description = '';
    bool isRecurring = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Public Holiday'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Holiday Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HolidayType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: HolidayType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (v) => type = v!,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(
                    DateFormat('MMMM dd, yyyy').format(selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) selectedDate = date;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (v) => description = v,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Recurring Yearly'),
                  value: isRecurring,
                  onChanged: (v) => isRecurring = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != true) return;
    try {
      await _holidayService.addHoliday(
        PublicHoliday(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          date: selectedDate,
          type: type,
          description: description.isEmpty ? null : description,
          isRecurring: isRecurring,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      NotificationHelper.showSuccess(context, 'Holiday added successfully!');
      ref.invalidate(
        publicHolidaysProvider(PublicHolidaysQuery(year: _selectedYear)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  Future<void> _deleteHoliday(PublicHoliday holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Delete "${holiday.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _holidayService.deleteHoliday(holiday.id);
      if (!mounted) return;
      NotificationHelper.showSuccess(context, 'Holiday deleted');
      ref.invalidate(
        publicHolidaysProvider(PublicHolidaysQuery(year: _selectedYear)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = PublicHolidaysQuery(year: _selectedYear);
    final holidaysAsync = ref.watch(publicHolidaysProvider(query));

    return holidaysAsync.when(
      loading: () => const AppScaffold(
        topBar: null,
        body: ModernLoadingState(message: 'Loading public holidays...'),
      ),
      error: (error, _) => AppScaffold(
        topBar: AppBar(title: const Text('Public Holidays')),
        body: ModernErrorState(
          message: 'Unable to load holidays',
          subtitle: '$error',
          onRetry: () => ref.invalidate(publicHolidaysProvider(query)),
        ),
      ),
      data: (data) {
        final holidays = data.holidays;
        final isAdmin = data.canManage;

        return AppScaffold(
          topBar: AppBar(
            title: const Text('Public Holidays'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(publicHolidaysProvider(query)),
              ),
              if (holidays.isEmpty)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _initializeDefaults,
                  tooltip: 'Initialize Defaults',
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicHolidaysProvider(query));
              await ref.read(publicHolidaysProvider(query).future);
            },
            child: ResponsiveLayout(
              mobile: _buildContent(holidays, isAdmin, true, 12),
              tablet: _buildContent(holidays, isAdmin, false, 16),
              desktop: _buildContent(holidays, isAdmin, false, 16),
            ),
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  onPressed: _addHoliday,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Holiday'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildContent(
    List<PublicHoliday> holidays,
    bool isAdmin,
    bool isCompact,
    double padding,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(padding),
      children: [
        _buildCalendarHero(holidays),
        const SizedBox(height: 12),
        _buildYearSelector(),
        const SizedBox(height: 12),
        _buildSummaryStrip(holidays, isCompact: isCompact),
        const SizedBox(height: 16),
        if (holidays.isEmpty)
          _buildEmptyState(isAdmin)
        else
          _buildHolidayList(holidays, isAdmin),
      ],
    );
  }

  Widget _buildCalendarHero(List<PublicHoliday> holidays) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.info.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Holiday Calendar $_selectedYear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${holidays.length} holidays configured',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _selectedYear--),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _selectedYear.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _selectedYear++),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(
    List<PublicHoliday> holidays, {
    required bool isCompact,
  }) {
    final recurring = holidays.where((h) => h.isRecurring).length;
    final upcoming = holidays
        .where((h) => !h.date.isBefore(DateTime.now()))
        .length;

    if (isCompact) {
      return Column(
        children: [
          _buildSummaryPill(
            label: 'Recurring',
            value: recurring.toString(),
            color: AppColors.info,
          ),
          const SizedBox(height: 8),
          _buildSummaryPill(
            label: 'Upcoming',
            value: upcoming.toString(),
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          _buildSummaryPill(
            label: 'Total',
            value: holidays.length.toString(),
            color: AppColors.primary,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildSummaryPill(
            label: 'Recurring',
            value: recurring.toString(),
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryPill(
            label: 'Upcoming',
            value: upcoming.toString(),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryPill(
            label: 'Total',
            value: holidays.length.toString(),
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isAdmin) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: ModernEmptyState(
            icon: Icons.event_busy,
            title: 'No holidays for $_selectedYear',
            subtitle: isAdmin
                ? 'Add holidays or initialize defaults for this year.'
                : 'No public holidays are available for this year yet.',
          ),
        ),
        if (isAdmin)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _selectedYear == 2026
                  ? _initializeDefaults
                  : _addHoliday,
              icon: const Icon(Icons.add),
              label: Text(
                _selectedYear == 2026
                    ? 'Initialize Nigerian Holidays'
                    : 'Add Holiday',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHolidayList(List<PublicHoliday> holidays, bool isAdmin) {
    final groupedHolidays = _groupHolidaysByMonth(holidays);
    return Column(
      children: groupedHolidays.entries.map((entry) {
        final month = entry.key;
        final monthHolidays = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Text(
                  DateFormat('MMMM').format(DateTime(_selectedYear, month)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...monthHolidays.map(
                (holiday) => _buildHolidayCard(holiday, isAdmin),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHolidayCard(PublicHoliday holiday, bool isAdmin) {
    final typeColor = _getTypeColor(holiday.type);
    final daysUntil = holiday.date.difference(DateTime.now()).inDays;
    final isPast = daysUntil < 0;
    final isToday = daysUntil == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('d').format(holiday.date),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
                Text(
                  DateFormat('EEE').format(holiday.date),
                  style: TextStyle(fontSize: 10, color: typeColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildChip(holiday.type.name, typeColor),
                    if (holiday.isRecurring)
                      _buildChip('Recurring', AppColors.info),
                    if (isToday) _buildChip('Today', AppColors.success),
                  ],
                ),
                if (holiday.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    holiday.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (!isPast && !isToday) ...[
                  const SizedBox(height: 4),
                  Text(
                    'in $daysUntil ${daysUntil == 1 ? "day" : "days"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _deleteHoliday(holiday),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Map<int, List<PublicHoliday>> _groupHolidaysByMonth(
    List<PublicHoliday> holidays,
  ) {
    final grouped = <int, List<PublicHoliday>>{};
    for (final holiday in holidays) {
      final month = holiday.date.month;
      grouped.putIfAbsent(month, () => <PublicHoliday>[]).add(holiday);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Color _getTypeColor(HolidayType type) {
    return switch (type) {
      HolidayType.national => AppColors.primary,
      HolidayType.religious => AppColors.info,
      HolidayType.regional => AppColors.warning,
      HolidayType.company => AppColors.success,
    };
  }
}
