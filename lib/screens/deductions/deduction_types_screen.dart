import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/services/deduction_type_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:uuid/uuid.dart';

class DeductionTypesScreen extends StatefulWidget {
  const DeductionTypesScreen({super.key});

  @override
  State<DeductionTypesScreen> createState() => _DeductionTypesScreenState();
}

class _DeductionTypesScreenState extends State<DeductionTypesScreen> {
  final _service = DeductionTypeService();
  final _userService = UserService();
  final _searchController = TextEditingController();

  List<DeductionType> _types = <DeductionType>[];
  bool _loading = true;
  bool _canManage = false;
  bool _initializingDefaults = false;
  String _roleLabel = 'Unknown';
  String _search = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUserProfile();
      final types = await _service.getAllDeductionTypes();
      if (!mounted) return;
      setState(() {
        _canManage =
            user != null &&
            PermissionService.hasPermission(user, Permission.manageDeductions);
        _roleLabel = user?.getRoleName() ?? 'Unknown';
        _types = types;
        _errorMessage = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initializeDefaults() async {
    if (_initializingDefaults) return;
    setState(() => _initializingDefaults = true);
    try {
      await _service.initializeDefaultTypes();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nigerian default deduction types ready.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _initializingDefaults = false);
      }
    }
  }

  Future<void> _toggleType(DeductionType type) async {
    await _service.toggleActive(type.id);
    await _load();
  }

  List<DeductionType> _filteredTypes() {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _types;

    return _types.where((type) {
      final haystack = [
        type.name,
        type.description ?? '',
        _categoryLabel(type.category),
        _methodLabel(type.calculationMethod),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Map<DeductionCategory, List<DeductionType>> _grouped(
    List<DeductionType> types,
  ) {
    final map = <DeductionCategory, List<DeductionType>>{};
    for (final type in types) {
      map.putIfAbsent(type.category, () => <DeductionType>[]);
      map[type.category]!.add(type);
    }
    return map;
  }

  Future<void> _showEditor({DeductionType? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(
      text: existing != null ? existing.defaultValue.toString() : '0',
    );
    DeductionCategory category = existing?.category ?? DeductionCategory.other;
    DeductionCalculationMethod method =
        existing?.calculationMethod ?? DeductionCalculationMethod.fixedAmount;
    bool isStatutory = existing?.isStatutory ?? false;
    bool isPreTax = existing?.isPreTax ?? false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New Deduction Type' : 'Edit Type'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DeductionCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: DeductionCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_categoryLabel(item)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocal(() => category = value ?? category),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DeductionCalculationMethod>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'Calculation Method',
                    ),
                    items: DeductionCalculationMethod.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_methodLabel(item)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocal(() => method = value ?? method),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: method == DeductionCalculationMethod.percentage
                          ? 'Default Percentage'
                          : 'Default Amount',
                    ),
                  ),
                  CheckboxListTile(
                    value: isStatutory,
                    onChanged: (value) =>
                        setLocal(() => isStatutory = value ?? false),
                    title: const Text('Statutory'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: isPreTax,
                    onChanged: (value) =>
                        setLocal(() => isPreTax = value ?? false),
                    title: const Text('Pre-tax'),
                    contentPadding: EdgeInsets.zero,
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final now = DateTime.now();
    final parsed = double.tryParse(valueCtrl.text.trim()) ?? 0;

    if (existing == null) {
      final type = DeductionType(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        category: category,
        calculationMethod: method,
        defaultValue: parsed,
        percentageRate: method == DeductionCalculationMethod.percentage
            ? parsed
            : null,
        isStatutory: isStatutory,
        isPreTax: isPreTax,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await _service.createDeductionType(type);
    } else {
      await _service.updateDeductionType(existing.id, <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty
            ? null
            : descCtrl.text.trim(),
        'category': category.name,
        'calculationMethod': method.name,
        'defaultValue': parsed,
        'percentageRate': method == DeductionCalculationMethod.percentage
            ? parsed
            : null,
        'isStatutory': isStatutory,
        'isPreTax': isPreTax,
      });
    }

    await _load();
  }

  String _categoryLabel(DeductionCategory category) {
    switch (category) {
      case DeductionCategory.statutory:
        return 'Statutory';
      case DeductionCategory.loan:
        return 'Loan';
      case DeductionCategory.advance:
        return 'Advance';
      case DeductionCategory.garnishment:
        return 'Garnishment';
      case DeductionCategory.insurance:
        return 'Insurance';
      case DeductionCategory.union:
        return 'Union';
      case DeductionCategory.other:
        return 'Other';
    }
  }

  String _methodLabel(DeductionCalculationMethod method) {
    switch (method) {
      case DeductionCalculationMethod.fixedAmount:
        return 'Fixed Amount';
      case DeductionCalculationMethod.percentage:
        return 'Percentage';
      case DeductionCalculationMethod.formula:
        return 'Formula';
    }
  }

  String _valueLabel(DeductionType type) {
    if (type.calculationMethod == DeductionCalculationMethod.percentage) {
      return '${type.defaultValue.toStringAsFixed(2)}%';
    }
    return CurrencyFormatter.formatNaira(type.defaultValue);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTypes = _filteredTypes();
    final grouped = _grouped(filteredTypes);
    final totalTypes = filteredTypes.length;
    final activeCount = filteredTypes.where((type) => type.isActive).length;
    final statutoryCount = filteredTypes
        .where((type) => type.isStatutory)
        .length;

    return AppScaffold(
      title: 'Deduction Types',
      body: _loading
          ? const ModernLoadingState(message: 'Loading deduction types...')
          : _errorMessage != null
          ? ModernErrorState(
              message: 'Failed to load deduction types',
              subtitle: _errorMessage,
              onRetry: _load,
            )
          : !_canManage
          ? _buildRestrictedState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildComplianceBanner(),
                  const SizedBox(height: 22),
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildSummaryRow(
                    totalTypes: totalTypes,
                    activeCount: activeCount,
                    statutoryCount: statutoryCount,
                  ),
                  const SizedBox(height: 20),
                  if (grouped.isEmpty)
                    _buildEmptyState()
                  else
                    ...grouped.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _buildCategorySection(entry.key, entry.value),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildFooterBar(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildRestrictedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.error,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only authorized deduction managers can configure deduction types. Current role: $_roleLabel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.infoDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'All financial deduction calculations are encrypted and compliant with Nigerian labor laws.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Compliance guidance is available in Compliance Hub.',
                  ),
                ),
              );
            },
            child: const Text(
              'LEARN MORE',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final searchField = SizedBox(
          width: isWide ? 320 : double.infinity,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search deductions...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryDark),
              ),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _initializingDefaults ? null : _initializeDefaults,
              icon: _initializingDefaults
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Initialize Nigerian Defaults'),
            ),
            ElevatedButton.icon(
              onPressed: () => _showEditor(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Type'),
            ),
          ],
        );

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deduction Management',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Configure and manage payroll deduction types for your organization.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  searchField,
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [actions],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deduction Management',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure and manage payroll deduction types for your organization.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            searchField,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required int totalTypes,
    required int activeCount,
    required int statutoryCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildMetricCard(
            title: 'TOTAL TYPES',
            value: totalTypes.toString(),
            helper: 'No changes this month',
            icon: Icons.list_alt_rounded,
          ),
          _buildMetricCard(
            title: 'ACTIVE',
            value: activeCount.toString(),
            helper: 'All types operational',
            icon: Icons.toggle_on_outlined,
          ),
          _buildMetricCard(
            title: 'STATUTORY',
            value: statutoryCount.toString(),
            helper: 'Regulatory mandates',
            icon: Icons.gavel_rounded,
          ),
        ];

        if (constraints.maxWidth >= 1100) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 16),
            cards[1],
            const SizedBox(height: 16),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String helper,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.infoDark),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(
              fontSize: 44,
              height: 1,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            helper,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    DeductionCategory category,
    List<DeductionType> types,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _categoryLabel(category).toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 1, color: AppColors.divider)),
          ],
        ),
        const SizedBox(height: 16),
        ...types.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildTypeCard(type),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(DeductionType type) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final leading = Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _categoryIcon(type.category),
                  color: AppColors.infoDark,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Text(
                          _methodLabel(type.calculationMethod),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          '-',
                          style: TextStyle(color: AppColors.textDisabled),
                        ),
                        Text(
                          _valueLabel(type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (type.isPreTax) ...[
                          const Text(
                            '-',
                            style: TextStyle(color: AppColors.textDisabled),
                          ),
                          const Text(
                            'Pre-Tax',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final trailing = Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: type.isActive
                      ? AppColors.infoLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  type.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: type.isActive
                        ? AppColors.infoDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showEditor(existing: type),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit type',
              ),
              Switch(value: type.isActive, onChanged: (_) => _toggleType(type)),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: leading),
                const SizedBox(width: 16),
                trailing,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [leading, const SizedBox(height: 16), trailing],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: const ModernEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No deduction types found',
        subtitle: 'Try a different search or create a new type.',
      ),
    );
  }

  Widget _buildFooterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final infoRow = const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.textSecondary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'All changes are logged for auditing purposes.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Compliance Hub is available from Compliance.',
                      ),
                    ),
                  );
                },
                child: const Text('COMPLIANCE HUB'),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final export = _types
                      .map(
                        (type) =>
                            '${type.name},${_categoryLabel(type.category)},${_methodLabel(type.calculationMethod)},${type.isActive ? 'ACTIVE' : 'INACTIVE'}',
                      )
                      .join('\n');
                  await Clipboard.setData(ClipboardData(text: export));
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Deduction type settings copied to clipboard.',
                      ),
                    ),
                  );
                },
                child: const Text('EXPORT SETTINGS'),
              ),
            ],
          );

          if (constraints.maxWidth >= 980) {
            return Row(
              children: [
                Expanded(child: infoRow),
                actions,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [infoRow, const SizedBox(height: 14), actions],
          );
        },
      ),
    );
  }

  IconData _categoryIcon(DeductionCategory category) {
    switch (category) {
      case DeductionCategory.statutory:
        return Icons.account_balance_outlined;
      case DeductionCategory.loan:
        return Icons.account_balance_wallet_outlined;
      case DeductionCategory.advance:
        return Icons.payments_outlined;
      case DeductionCategory.garnishment:
        return Icons.gavel_outlined;
      case DeductionCategory.insurance:
        return Icons.health_and_safety_outlined;
      case DeductionCategory.union:
        return Icons.groups_outlined;
      case DeductionCategory.other:
        return Icons.category_outlined;
    }
  }
}
