import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_strings.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/csv_file_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/dashboard_provider.dart';
import 'package:roipayroll/providers/employee_provider.dart';
import 'package:roipayroll/screens/employees/add_employee_screen.dart';
import 'package:roipayroll/screens/employees/edit_employee_screen.dart';
import 'package:roipayroll/screens/employees/employee_detail_screen.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final _employeeService = EmployeeService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  EmploymentType? _filterType;
  int _currentPage = 0;
  final Set<String> _selectedEmployeeIds = <String>{};
  String _sortField = 'name';
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final dashboardSummaryAsync = ref.watch(dashboardSummaryProvider);

    return AppScaffold(
      title: AppStrings.employees,
      showSearch: true,
      padding: EdgeInsets.zero,
      headerActions: _buildTopBarActions(profileAsync.value),
      body: profileAsync.when(
        loading: () => const Center(
          child: ModernLoadingState(message: 'Loading employee access...'),
        ),
        error: (error, _) => Center(
          child: ModernErrorState(
            message: 'Failed to load employee access',
            subtitle: error.toString(),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: ModernEmptyState(
                icon: Icons.person_off_outlined,
                title: 'User profile unavailable',
                subtitle:
                    'Please sign in again to load the employee directory.',
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              return _buildBody(
                employeesAsync,
                profile: profile,
                dashboardSummaryAsync: dashboardSummaryAsync,
                compact: compact,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Employee>> employeesAsync, {
    required AppUser profile,
    required AsyncValue<DashboardSummary> dashboardSummaryAsync,
    required bool compact,
  }) {
    final roleConfig = _EmployeeRoleConfig.fromUser(profile);

    return employeesAsync.when(
      loading: () => const Center(child: ListSkeleton(itemCount: 6)),
      error: (error, _) => Center(
        child: ModernErrorState(
          message: 'Failed to load employees',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(employeeListProvider),
        ),
      ),
      data: (employees) => _buildDirectoryView(
        employees,
        profile: profile,
        dashboardSummaryAsync: dashboardSummaryAsync,
        roleConfig: roleConfig,
        compact: compact,
      ),
    );
  }

  Widget _buildTopBarActions(AppUser? user) {
    final canCreate =
        user != null &&
        PermissionService.hasPermission(user, Permission.createEmployee);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute == AppRoutes.notifications) return;
            Navigator.pushNamed(context, AppRoutes.notifications);
          },
          tooltip: 'Notifications',
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF3A4A60),
            size: 22,
          ),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF3F6FB),
            foregroundColor: const Color(0xFF3A4A60),
            minimumSize: const Size(42, 42),
          ),
        ),
        if (canCreate) ...[
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _openAddEmployee,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF071A34),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Employee',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirectoryView(
    List<Employee> employees, {
    required AppUser profile,
    required AsyncValue<DashboardSummary> dashboardSummaryAsync,
    required _EmployeeRoleConfig roleConfig,
    required bool compact,
  }) {
    final filtered = _filterEmployees(employees);
    final departments = [
      'All',
      ...employees
          .map((employee) => employee.department.trim())
          .where((department) => department.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    ];
    final rowsPerPage = compact ? 4 : 5;
    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ rowsPerPage) + 1;
    final currentPage = _currentPage.clamp(0, pageCount - 1);
    final start = filtered.isEmpty ? 0 : currentPage * rowsPerPage;
    final visibleEmployees = filtered.skip(start).take(rowsPerPage).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        24,
        compact ? 16 : 24,
        28,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(roleConfig, employees),
              const SizedBox(height: 20),
              _buildControlSection(
                compact: compact,
                departments: departments,
                roleConfig: roleConfig,
              ),
              const SizedBox(height: 20),
              _buildSecurityBanner(roleConfig),
              const SizedBox(height: 22),
              if (employees.isEmpty)
                _buildDirectoryEmpty(roleConfig)
              else if (filtered.isEmpty)
                _buildDirectoryNoResults()
              else ...[
                _buildDirectoryTable(
                  visibleEmployees,
                  roleConfig: roleConfig,
                  compact: compact,
                  start: start,
                  end: start + visibleEmployees.length,
                  totalCount: filtered.length,
                  currentPage: currentPage,
                  pageCount: pageCount,
                ),
                const SizedBox(height: 22),
                _buildDirectorySummary(
                  employees,
                  profile: profile,
                  dashboardSummaryAsync: dashboardSummaryAsync,
                  roleConfig: roleConfig,
                  compact: compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(
    _EmployeeRoleConfig roleConfig,
    List<Employee> employees,
  ) {
    final activeCount = employees
        .where((employee) => employee.status.toLowerCase() == 'active')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Directory',
              style: TextStyle(
                fontSize: constraints.maxWidth < 720 ? 34 : 44,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A1730),
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dashboard  /  Employee Management',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                roleConfig.canViewSalary
                    ? Icons.verified_user_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: const Color(0xFF35548A),
              ),
              const SizedBox(width: 8),
              Text(
                '$activeCount active employees',
                style: const TextStyle(
                  color: Color(0xFF0A1730),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), badge],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            badge,
          ],
        );
      },
    );
  }

  Widget _buildControlSection({
    required bool compact,
    required List<String> departments,
    required _EmployeeRoleConfig roleConfig,
  }) {
    final tabs = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildFilterPill('All', _filterType == null, () {
            setState(() {
              _filterType = null;
              _currentPage = 0;
            });
          }),
          _buildFilterPill(
            'Permanent',
            _filterType == EmploymentType.permanent,
            () {
              setState(() {
                _filterType = EmploymentType.permanent;
                _currentPage = 0;
              });
            },
          ),
          _buildFilterPill(
            'Probation',
            _filterType == EmploymentType.probation,
            () {
              setState(() {
                _filterType = EmploymentType.probation;
                _currentPage = 0;
              });
            },
          ),
          _buildFilterPill(
            'Contract',
            _filterType == EmploymentType.contract,
            () {
              setState(() {
                _filterType = EmploymentType.contract;
                _currentPage = 0;
              });
            },
          ),
        ],
      ),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search employees, departments, IDs...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6E0EC)),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
          _currentPage = 0;
        });
      },
    );

    final actionWrap = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildDepartmentSelector(departments),
        if (roleConfig.canCreate)
          _buildSecondaryButton(
            icon: Icons.upload_file_outlined,
            label: 'Import CSV',
            onTap: _openImportCsv,
          ),
        if (_hasActiveDirectoryFilters)
          _buildSecondaryButton(
            icon: Icons.filter_alt_off_outlined,
            label: 'Clear',
            onTap: _clearDirectoryFilters,
          ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          search,
          const SizedBox(height: 14),
          tabs,
          const SizedBox(height: 14),
          actionWrap,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 5, child: search),
            const SizedBox(width: 14),
            Expanded(flex: 7, child: tabs),
          ],
        ),
        const SizedBox(height: 14),
        actionWrap,
      ],
    );
  }

  Widget _buildFilterPill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A1730).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF0A1730) : const Color(0xFF3E4E64),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSelector(List<String> departments) {
    return PopupMenuButton<String>(
      initialValue: _selectedDepartment,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => departments
          .map(
            (department) => PopupMenuItem<String>(
              value: department,
              child: Text(department),
            ),
          )
          .toList(),
      onSelected: (value) {
        setState(() {
          _selectedDepartment = value;
          _currentPage = 0;
        });
      },
      child: _buildSecondaryButton(
        icon: Icons.filter_list_rounded,
        label: _selectedDepartment == 'All'
            ? 'Department'
            : _selectedDepartment,
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBF3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF17263D)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF17263D),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: child,
    );
  }

  Widget _buildSecurityBanner(_EmployeeRoleConfig roleConfig) {
    final title = roleConfig.canViewSalary
        ? 'End-to-End Encrypted Data Access'
        : 'Role-Governed Employee Data Access';
    final subtitle = roleConfig.canViewSalary
        ? 'Only authorized payroll officers can view full salary details. Audit logging is active.'
        : 'Compensation figures are masked for your role. Audit logging remains active.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF355079),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF213654)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1730),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'SECURE SESSION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          );

          final text = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD4E0F1),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white),
                    const SizedBox(width: 14),
                    text,
                  ],
                ),
                const SizedBox(height: 14),
                badge,
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white),
              const SizedBox(width: 14),
              text,
              const SizedBox(width: 16),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDirectoryTable(
    List<Employee> employees, {
    required _EmployeeRoleConfig roleConfig,
    required bool compact,
    required int start,
    required int end,
    required int totalCount,
    required int currentPage,
    required int pageCount,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!compact) _buildDirectoryTableHeader(),
          ...employees.map(
            (employee) => compact
                ? _buildDirectoryCardItem(employee, roleConfig)
                : _buildDirectoryRow(employee, roleConfig),
          ),
          _buildDirectoryPagination(
            start: start,
            end: end,
            totalCount: totalCount,
            currentPage: currentPage,
            pageCount: pageCount,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryTableHeader() {
    Widget header(String text, int flex, {bool right = false}) {
      return Expanded(
        flex: flex,
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF394A61),
              letterSpacing: 2.1,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          header('EMPLOYEE NAME', 30),
          header('ID', 11),
          header('DEPARTMENT', 15),
          header('POSITION', 17),
          header('SALARY (NGN)', 15, right: true),
          header('STATUS', 10),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildDirectoryRow(Employee employee, _EmployeeRoleConfig roleConfig) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAEFF5))),
      ),
      child: Row(
        children: [
          Expanded(flex: 30, child: _buildEmployeeIdentity(employee)),
          Expanded(
            flex: 11,
            child: Text(
              _formatEmployeeId(employee.id),
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
          Expanded(flex: 15, child: Text(employee.department)),
          Expanded(
            flex: 17,
            child: Text(
              employee.position,
              style: const TextStyle(height: 1.45),
            ),
          ),
          Expanded(
            flex: 15,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                roleConfig.canViewSalary
                    ? CurrencyFormatter.formatCurrency(
                        employee.basicSalary,
                        currencyCode: 'NGN',
                      )
                    : 'Restricted',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: roleConfig.canViewSalary
                      ? const Color(0xFF0A1730)
                      : const Color(0xFF7A8CA3),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DirectoryStatusPill(status: employee.status),
            ),
          ),
          SizedBox(
            width: 28,
            child: _DirectoryActionMenu(
              canEdit: roleConfig.canEdit,
              canDelete: roleConfig.canDelete,
              onView: () => _viewEmployee(employee),
              onEdit: () => _editEmployee(employee),
              onDelete: () => _deleteEmployee(employee),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeIdentity(Employee employee) {
    return Row(
      children: [
        _DirectoryAvatar(name: employee.fullName, seed: employee.id),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1730),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employee.email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryCardItem(
    Employee employee,
    _EmployeeRoleConfig roleConfig,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DirectoryAvatar(name: employee.fullName, seed: employee.id),
              const SizedBox(width: 14),
              Expanded(child: _buildEmployeeIdentityText(employee)),
              _DirectoryActionMenu(
                canEdit: roleConfig.canEdit,
                canDelete: roleConfig.canDelete,
                onView: () => _viewEmployee(employee),
                onEdit: () => _editEmployee(employee),
                onDelete: () => _deleteEmployee(employee),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DirectoryInfoChip(
                label: 'ID',
                value: _formatEmployeeId(employee.id),
              ),
              _DirectoryInfoChip(
                label: 'Department',
                value: employee.department,
              ),
              _DirectoryInfoChip(label: 'Position', value: employee.position),
              _DirectoryInfoChip(
                label: 'Salary',
                value: roleConfig.canViewSalary
                    ? CurrencyFormatter.formatCurrency(
                        employee.basicSalary,
                        currencyCode: 'NGN',
                      )
                    : 'Restricted',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DirectoryStatusPill(status: employee.status),
        ],
      ),
    );
  }

  Widget _buildEmployeeIdentityText(Employee employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          employee.fullName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A1730),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          employee.email,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDirectoryPagination({
    required int start,
    required int end,
    required int totalCount,
    required int currentPage,
    required int pageCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final pages = _visibleDirectoryPages(currentPage, pageCount);
          final pager = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: currentPage > 0
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              ...pages.map((page) {
                if (page == -1) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...'),
                  );
                }
                final selected = page == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _currentPage = page),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF071A34)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${page + 1}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF17263D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              IconButton(
                onPressed: currentPage < pageCount - 1
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Showing ${start + 1}-$end of $totalCount employees'),
                const SizedBox(height: 12),
                pager,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  'Showing ${start + 1}-$end of $totalCount employees',
                ),
              ),
              pager,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDirectorySummary(
    List<Employee> employees, {
    required AppUser profile,
    required AsyncValue<DashboardSummary> dashboardSummaryAsync,
    required _EmployeeRoleConfig roleConfig,
    required bool compact,
  }) {
    final hiresThisMonth = employees.where(_isEmployeeHiredThisMonth).length;
    final currentMonthPayroll =
        dashboardSummaryAsync.asData?.value.currentMonthPayroll ?? 0.0;
    final payrollSubtitle = roleConfig.canViewSalary
        ? currentMonthPayroll > 0
              ? 'Processed payroll total for ${_monthLabel(DateTime.now())}'
              : 'No payroll processed yet for ${_monthLabel(DateTime.now())}'
        : 'Payroll amounts are hidden for your role';

    final cards = [
      _DirectorySummaryCard(
        label: 'TOTAL HEADCOUNT',
        value: '${employees.length}',
        subtitle: hiresThisMonth == 0
            ? 'No new hires this month'
            : '+$hiresThisMonth this month',
        icon: Icons.groups_2_outlined,
        subtitleColor: hiresThisMonth == 0
            ? const Color(0xFF7C8DA5)
            : AppColors.success,
      ),
      _DirectorySummaryCard(
        label: 'MONTHLY PAYROLL',
        value: roleConfig.canViewSalary
            ? CurrencyFormatter.formatCurrency(
                currentMonthPayroll,
                currencyCode: 'NGN',
              )
            : 'Restricted',
        subtitle: payrollSubtitle,
        icon: Icons.account_balance_wallet_outlined,
        subtitleColor: const Color(0xFF7C8DA5),
      ),
      _DirectorySummaryCard(
        label: 'SECURITY STATUS',
        value: roleConfig.canEdit || roleConfig.canDelete
            ? 'Compliant'
            : 'Monitored',
        subtitle: roleConfig.canViewSalary
            ? 'Salary access verified for ${profile.getRoleName().toLowerCase()} role'
            : 'Employee records remain access-controlled and auditable',
        icon: Icons.shield_outlined,
        dark: true,
      ),
    ];

    if (compact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 18),
        Expanded(child: cards[1]),
        const SizedBox(width: 18),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildDirectoryEmpty(_EmployeeRoleConfig roleConfig) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ModernEmptyState(
        icon: Icons.people_outline,
        title: 'No employees yet',
        subtitle: roleConfig.canCreate
            ? 'Add your first employee to populate the directory.'
            : 'Employee records will appear here once your company data is populated.',
        actionLabel: roleConfig.canCreate ? 'Add Employee' : null,
        onAction: roleConfig.canCreate ? _openAddEmployee : null,
      ),
    );
  }

  Widget _buildDirectoryNoResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ModernEmptyState(
        icon: Icons.search_off,
        title: 'No employees match this view',
        subtitle: 'Try another search term, department, or employment filter.',
        actionLabel: _hasActiveDirectoryFilters ? 'Clear Filters' : null,
        onAction: _hasActiveDirectoryFilters ? _clearDirectoryFilters : null,
      ),
    );
  }

  List<int> _visibleDirectoryPages(int currentPage, int pageCount) {
    if (pageCount <= 5) {
      return List<int>.generate(pageCount, (index) => index);
    }
    if (currentPage <= 2) {
      return [0, 1, 2, -1, pageCount - 1];
    }
    if (currentPage >= pageCount - 3) {
      return [0, -1, pageCount - 3, pageCount - 2, pageCount - 1];
    }
    return [0, -1, currentPage, -1, pageCount - 1];
  }

  bool _isEmployeeHiredThisMonth(Employee employee) {
    final now = DateTime.now();
    return employee.hireDate.year == now.year &&
        employee.hireDate.month == now.month;
  }

  String _formatEmployeeId(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'N/A';
    if (normalized.contains('-')) return normalized.toUpperCase();
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return 'RP-\n${digits.padLeft(5, '0')}';
    }
    return normalized.toUpperCase();
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openAddEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
    );
    if (result == true && mounted) {
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _openImportCsv() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.employeeImport,
      arguments: {'returnRoute': AppRoutes.employeeList},
    );
    if (result == true && mounted) {
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  void _clearDirectoryFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDepartment = 'All';
      _filterType = null;
      _currentPage = 0;
    });
  }

  bool get _hasActiveDirectoryFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedDepartment != 'All' ||
      _filterType != null;

  // ignore: unused_element
  Widget _buildFilterToolbar({required bool compact}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          if (compact)
            Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildDepartmentDropdown(),
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 3, child: _buildSearchField()),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildDepartmentDropdown()),
              ],
            ),
          const SizedBox(height: 10),
          _buildEmploymentTypeFilters(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearFiltersAndSelection,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search employees...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
    );
  }

  Widget _buildDepartmentDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDepartment,
          isExpanded: true,
          items: ['All', ...AppStrings.departments].map((dept) {
            return DropdownMenuItem(value: dept, child: Text(dept));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDepartment = value!;
            });
          },
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActiveFiltersBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_searchQuery.trim().isNotEmpty)
            InputChip(
              label: Text('Search: ${_searchQuery.trim()}'),
              onDeleted: () {
                setState(() => _searchQuery = '');
              },
            ),
          if (_selectedDepartment != 'All')
            InputChip(
              label: Text('Department: $_selectedDepartment'),
              onDeleted: () {
                setState(() => _selectedDepartment = 'All');
              },
            ),
          if (_filterType != null)
            InputChip(
              label: Text('Type: ${_filterType!.name}'),
              onDeleted: () {
                setState(() => _filterType = null);
              },
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBulkActionBar(
    List<Employee> filtered,
    List<Employee> allEmployees,
  ) {
    final selectedVisibleCount = filtered
        .where((employee) => _selectedEmployeeIds.contains(employee.id))
        .length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedVisibleCount selected in view (${_selectedEmployeeIds.length} total selected)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedEmployeeIds.clear());
            },
            child: const Text('Clear Selection'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _exportSelectedToCsv(allEmployees),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export Selected'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _bulkChangeDepartment(allEmployees),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Change Department'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _bulkDeleteSelected(allEmployees),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Selected'),
          ),
        ],
      ),
    );
  }

  List<Employee> _filterEmployees(List<Employee> employees) {
    var filtered = List<Employee>.from(employees);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((employee) {
        return employee.fullName.toLowerCase().contains(q) ||
            employee.email.toLowerCase().contains(q) ||
            employee.department.toLowerCase().contains(q) ||
            employee.position.toLowerCase().contains(q) ||
            employee.id.toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedDepartment != 'All') {
      filtered = filtered
          .where((employee) => employee.department == _selectedDepartment)
          .toList();
    }

    if (_filterType != null) {
      filtered = filtered
          .where((employee) => employee.employmentType == _filterType)
          .toList();
    }

    int compareText(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'employeeId':
          result = compareText(a.id, b.id);
          break;
        case 'department':
          result = compareText(a.department, b.department);
          break;
        case 'position':
          result = compareText(a.position, b.position);
          break;
        case 'salary':
          result = a.basicSalary.compareTo(b.basicSalary);
          break;
        case 'status':
          result = compareText(a.status, b.status);
          break;
        case 'name':
        default:
          result = compareText(a.fullName, b.fullName);
      }
      return _sortAscending ? result : -result;
    });

    return filtered;
  }

  Future<void> _viewEmployee(Employee employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailScreen(employee: employee),
      ),
    );
    if (result == true && mounted) {
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeeScreen(employee: employee),
      ),
    );
    if (result == true && mounted) {
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await ModernDialogs.confirm(
      context,
      title: 'Delete Employee',
      message:
          'Delete ${employee.fullName}? This action can be restored from archive.',
      confirmText: 'Delete',
    );
    if (!confirmed) return;

    try {
      await _employeeService.deleteEmployee(
        employee.id,
        reason: 'Deleted from employee list table',
      );
      if (!mounted) return;
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Employee deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _bulkDeleteSelected(List<Employee> employees) async {
    if (_selectedEmployeeIds.isEmpty) return;

    final selected = employees
        .where((employee) => _selectedEmployeeIds.contains(employee.id))
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await ModernDialogs.confirm(
      context,
      title: 'Delete Selected Employees',
      message:
          'Delete ${selected.length} selected employee(s)? This action can be restored from archive.',
      confirmText: 'Delete All',
    );
    if (!confirmed) return;

    var successCount = 0;
    var failedCount = 0;
    String? firstError;
    for (final employee in selected) {
      try {
        await _employeeService.deleteEmployee(
          employee.id,
          reason: 'Bulk delete from employee list table',
        );
        successCount += 1;
      } catch (e) {
        failedCount += 1;
        firstError ??= e.toString();
      }
    }

    if (!mounted) return;
    if (successCount > 0) {
      setState(() => _selectedEmployeeIds.clear());
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      final message = failedCount > 0
          ? 'Deleted $successCount of ${selected.length} selected employees ($failedCount failed)'
          : 'Deleted $successCount selected employees';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      final message = firstError != null
          ? 'Delete failed: $firstError'
          : 'Delete failed';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportSelectedToCsv(List<Employee> employees) async {
    if (_selectedEmployeeIds.isEmpty) return;
    final selected = employees
        .where((employee) => _selectedEmployeeIds.contains(employee.id))
        .toList();
    if (selected.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'employee_id,first_name,last_name,email,phone,department,position,basic_salary,status',
    );
    for (final employee in selected) {
      final row = [
        _csvEscape(employee.id),
        _csvEscape(employee.firstName),
        _csvEscape(employee.lastName),
        _csvEscape(employee.email),
        _csvEscape(employee.phone),
        _csvEscape(employee.department),
        _csvEscape(employee.position),
        employee.basicSalary.toStringAsFixed(2),
        _csvEscape(employee.status),
      ];
      buffer.writeln(row.join(','));
    }

    try {
      await downloadCsvFile(
        fileName: 'selected_employees.csv',
        csv: buffer.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${selected.length} selected employees'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  Future<void> _bulkChangeDepartment(List<Employee> employees) async {
    if (_selectedEmployeeIds.isEmpty) return;
    final selected = employees
        .where((employee) => _selectedEmployeeIds.contains(employee.id))
        .toList();
    if (selected.isEmpty) return;

    String nextDepartment = _selectedDepartment == 'All'
        ? AppStrings.departments.first
        : _selectedDepartment;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Department'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apply to ${selected.length} selected employee(s).'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: nextDepartment,
                    decoration: const InputDecoration(
                      labelText: 'New Department',
                      border: OutlineInputBorder(),
                    ),
                    items: AppStrings.departments
                        .map(
                          (dept) =>
                              DropdownMenuItem(value: dept, child: Text(dept)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => nextDepartment = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    var updated = 0;
    for (final employee in selected) {
      try {
        await _employeeService.updateEmployee(
          employee.copyWith(department: nextDepartment),
        );
        updated += 1;
      } catch (_) {}
    }

    if (!mounted) return;
    ref.invalidate(employeeListProvider);
    ref.invalidate(dashboardSummaryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated $updated of ${selected.length} employees'),
      ),
    );
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  void _clearFiltersAndSelection() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDepartment = 'All';
      _filterType = null;
      _selectedEmployeeIds.clear();
      _sortField = 'name';
      _sortAscending = true;
    });
  }

  Widget _buildEmploymentTypeFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _filterType == null,
          onSelected: (_) => setState(() => _filterType = null),
        ),
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, size: 16, color: AppColors.success),
              SizedBox(width: 4),
              Text('Permanent'),
            ],
          ),
          selected: _filterType == EmploymentType.permanent,
          onSelected: (_) =>
              setState(() => _filterType = EmploymentType.permanent),
        ),
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_bottom, size: 16, color: AppColors.warning),
              SizedBox(width: 4),
              Text('Probation'),
            ],
          ),
          selected: _filterType == EmploymentType.probation,
          onSelected: (_) =>
              setState(() => _filterType = EmploymentType.probation),
        ),
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.description, size: 16, color: AppColors.info),
              SizedBox(width: 4),
              Text('Contract'),
            ],
          ),
          selected: _filterType == EmploymentType.contract,
          onSelected: (_) =>
              setState(() => _filterType = EmploymentType.contract),
        ),
      ],
    );
  }
}

class _EmployeeRoleConfig {
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canViewSalary;

  const _EmployeeRoleConfig({
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.canViewSalary,
  });

  factory _EmployeeRoleConfig.fromUser(AppUser user) {
    return _EmployeeRoleConfig(
      canCreate: PermissionService.hasPermission(
        user,
        Permission.createEmployee,
      ),
      canEdit: PermissionService.hasPermission(user, Permission.editEmployee),
      canDelete: PermissionService.hasPermission(
        user,
        Permission.deleteEmployee,
      ),
      canViewSalary: PermissionService.hasPermission(
        user,
        Permission.viewPayroll,
      ),
    );
  }
}

class _DirectoryAvatar extends StatelessWidget {
  final String name;
  final String seed;

  const _DirectoryAvatar({required this.name, required this.seed});

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    const palettes = [
      [Color(0xFF172A45), Color(0xFF30598C)],
      [Color(0xFF7C2D12), Color(0xFFEA580C)],
      [Color(0xFF0F766E), Color(0xFF14B8A6)],
      [Color(0xFF7E22CE), Color(0xFFA855F7)],
      [Color(0xFF9F1239), Color(0xFFFB7185)],
    ];
    final palette = palettes[hash % palettes.length];

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DirectoryStatusPill extends StatelessWidget {
  final String status;

  const _DirectoryStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final active = normalized == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCE7FF) : const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? 'UNKNOWN' : normalized.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: active ? const Color(0xFF1E4DA1) : const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _DirectoryActionMenu extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DirectoryActionMenu({
    required this.canEdit,
    required this.canDelete,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView();
            break;
          case 'edit':
            onEdit();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'view',
          child: _DirectoryMenuLabel(
            icon: Icons.visibility_outlined,
            label: 'View details',
          ),
        ),
        if (canEdit)
          const PopupMenuItem<String>(
            value: 'edit',
            child: _DirectoryMenuLabel(
              icon: Icons.edit_outlined,
              label: 'Edit employee',
            ),
          ),
        if (canDelete)
          const PopupMenuItem<String>(
            value: 'delete',
            child: _DirectoryMenuLabel(
              icon: Icons.delete_outline,
              label: 'Delete employee',
              destructive: true,
            ),
          ),
      ],
      child: const Icon(Icons.more_vert_rounded, color: Color(0xFF394A61)),
    );
  }
}

class _DirectoryMenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _DirectoryMenuLabel({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : const Color(0xFF17263D);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _DirectoryInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _DirectoryInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7F99),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF17263D),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectorySummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool dark;
  final Color subtitleColor;

  const _DirectorySummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.dark = false,
    this.subtitleColor = const Color(0xFF7C8DA5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF071A34) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0A1730).withValues(alpha: 0.04),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                    color: dark
                        ? const Color(0xFFC8D5EA)
                        : const Color(0xFF394A61),
                  ),
                ),
              ),
              Icon(
                icon,
                color: dark ? Colors.white : const Color(0xFFB0C4E9),
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: dark ? Colors.white : const Color(0xFF0A1730),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: dark ? Colors.white70 : subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
