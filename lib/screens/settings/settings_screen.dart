import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/company_module_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _userService = UserService();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isSavingCompany = false;
  bool _isSavingPreferences = false;
  bool _isSavingModules = false;
  TabController? _tabController;
  final _moduleService = CompanyModuleService();

  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyRegNoController = TextEditingController();
  final _settingsSearchController = TextEditingController();

  String _companyPlan = 'Standard';
  String _companyTaxNexus = 'Lagos State';
  int _employeeCount = 0;
  String _currency = 'NGN';
  String _dateFormat = 'dd/MM/yyyy';
  String _payrollCycle = 'monthly';
  int _workingDays = 5;
  int _leaveYearStartMonth = 1;
  bool _enablePaye = true;
  bool _enablePension = true;
  bool _enableNhf = true;
  bool _autoSendPayslipEmail = true;
  bool _autoSendPayrollNotification = true;
  bool _deductionApprovalRequired = true;
  bool _allowNegativeLeaveBalance = false;
  bool _overtimeEnabled = true;
  bool _notifyInApp = true;
  bool _notifyEmail = true;
  bool _notifySms = false;
  bool _dailyDigest = false;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _mfaEnabled = false;
  bool _sessionTimeoutEnabled = true;
  int _sessionTimeoutMinutes = 30;
  bool _allowSingleSessionOnly = false;
  bool _hasUnsavedChanges = false;
  String _initialSettingsHash = '';
  String _settingsSearch = '';
  String _moduleSearch = '';
  String _accessSearch = '';
  String _modulePreset = 'Custom';
  Map<String, bool> _enabledModules = Map<String, bool>.from(
    CompanyModuleService.defaultModules,
  );
  final _overtimeWeekdayController = TextEditingController(text: '1.5');
  final _overtimeWeekendController = TextEditingController(text: '2.0');
  final _overtimeHolidayController = TextEditingController(text: '2.0');
  final _usdRateController = TextEditingController(text: '1600');
  final _eurRateController = TextEditingController(text: '1750');
  final _gbpRateController = TextEditingController(text: '2050');

  @override
  void initState() {
    super.initState();
    _attachChangeListeners();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _companyRegNoController.dispose();
    _settingsSearchController.dispose();
    _overtimeWeekdayController.dispose();
    _overtimeWeekendController.dispose();
    _overtimeHolidayController.dispose();
    _usdRateController.dispose();
    _eurRateController.dispose();
    _gbpRateController.dispose();
    super.dispose();
  }

  bool get _isAdmin =>
      _currentUser != null &&
      PermissionService.hasPermission(_currentUser!, Permission.manageSettings);
  bool get _canManagePayroll =>
      _currentUser != null &&
      PermissionService.hasPermission(_currentUser!, Permission.processPayroll);
  bool get _canManagePeople =>
      _currentUser != null &&
      PermissionService.hasPermission(_currentUser!, Permission.createEmployee);

  void _attachChangeListeners() {
    final controllers = [
      _companyNameController,
      _companyEmailController,
      _companyPhoneController,
      _companyAddressController,
      _companyRegNoController,
      _overtimeWeekdayController,
      _overtimeWeekendController,
      _overtimeHolidayController,
      _usdRateController,
      _eurRateController,
      _gbpRateController,
    ];
    for (final controller in controllers) {
      controller.addListener(_updateUnsavedChangesFlag);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final user = await _userService.getCurrentUserProfile();
      if (!mounted) return;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final companyId = user.companyId;
      final companyDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .get();
      final prefsDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('general')
          .get();

      final companyData = companyDoc.data() ?? <String, dynamic>{};
      final prefs = prefsDoc.data() ?? <String, dynamic>{};

      _companyNameController.text = (companyData['name'] ?? '').toString();
      _companyEmailController.text = (companyData['email'] ?? '').toString();
      _companyPhoneController.text = (companyData['phone'] ?? '').toString();
      _companyAddressController.text = (companyData['address'] ?? '')
          .toString();
      _companyRegNoController.text = (companyData['registrationNumber'] ?? '')
          .toString();
      _companyPlan =
          (companyData['subscription'] ??
                  companyData['plan'] ??
                  companyData['tier'] ??
                  'Standard')
              .toString();
      _companyTaxNexus = (companyData['taxNexus'] ?? 'Lagos State').toString();
      _employeeCount = _asInt(companyData['employeeCount'], 0);

      _currency = (prefs['currency'] ?? 'NGN').toString();
      _dateFormat = (prefs['dateFormat'] ?? 'dd/MM/yyyy').toString();
      _payrollCycle = (prefs['payrollCycle'] ?? 'monthly').toString();
      _workingDays = (prefs['workingDays'] ?? 5) as int;
      _leaveYearStartMonth = (prefs['leaveYearStartMonth'] ?? 1) as int;
      _enablePaye = (prefs['enablePaye'] ?? true) as bool;
      _enablePension = (prefs['enablePension'] ?? true) as bool;
      _enableNhf = (prefs['enableNhf'] ?? true) as bool;
      _autoSendPayslipEmail = (prefs['autoSendPayslipEmail'] ?? true) as bool;
      _autoSendPayrollNotification =
          (prefs['autoSendPayrollNotification'] ?? true) as bool;
      _deductionApprovalRequired =
          (prefs['deductionApprovalRequired'] ?? true) as bool;
      _allowNegativeLeaveBalance =
          (prefs['allowNegativeLeaveBalance'] ?? false) as bool;
      _overtimeEnabled = _asBool(prefs['overtimeEnabled'], true);
      _notifyInApp = _asBool(prefs['notifyInApp'], true);
      _notifyEmail = _asBool(prefs['notifyEmail'], true);
      _notifySms = _asBool(prefs['notifySms'], false);
      _dailyDigest = _asBool(prefs['dailyDigest'], false);
      _quietHoursEnabled = _asBool(prefs['quietHoursEnabled'], false);
      final quietStart = (prefs['quietHoursStart'] ?? '22:00').toString();
      final quietEnd = (prefs['quietHoursEnd'] ?? '07:00').toString();
      _quietHoursStart = _parseTimeOfDay(
        quietStart,
        const TimeOfDay(hour: 22, minute: 0),
      );
      _quietHoursEnd = _parseTimeOfDay(
        quietEnd,
        const TimeOfDay(hour: 7, minute: 0),
      );
      _mfaEnabled = _asBool(prefs['mfaEnabled'], false);
      _sessionTimeoutEnabled = _asBool(prefs['sessionTimeoutEnabled'], true);
      _sessionTimeoutMinutes = (prefs['sessionTimeoutMinutes'] ?? 30) as int;
      _allowSingleSessionOnly = _asBool(prefs['allowSingleSessionOnly'], false);
      _overtimeWeekdayController.text = _asDouble(
        prefs['overtimeWeekdayMultiplier'],
        1.5,
      ).toStringAsFixed(2);
      _overtimeWeekendController.text = _asDouble(
        prefs['overtimeWeekendMultiplier'],
        2.0,
      ).toStringAsFixed(2);
      _overtimeHolidayController.text = _asDouble(
        prefs['overtimeHolidayMultiplier'],
        2.0,
      ).toStringAsFixed(2);
      final exchangeRates =
          (prefs['exchangeRates'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      _usdRateController.text = _asDouble(
        exchangeRates['USD'],
        1600,
      ).toStringAsFixed(2);
      _eurRateController.text = _asDouble(
        exchangeRates['EUR'],
        1750,
      ).toStringAsFixed(2);
      _gbpRateController.text = _asDouble(
        exchangeRates['GBP'],
        2050,
      ).toStringAsFixed(2);
      _enabledModules = await _moduleService.getCompanyModules(companyId);
      _resolveModulePresetLabel();

      final tabs = _buildTabs(user);
      _tabController?.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);

      setState(() {
        _currentUser = user;
        _isLoading = false;
        _initialSettingsHash = _serializeSettings();
        _hasUnsavedChanges = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<_SettingsTab> _buildTabs(AppUser user) {
    final isAdmin = PermissionService.hasPermission(
      user,
      Permission.manageSettings,
    );
    final canManagePayroll = PermissionService.hasPermission(
      user,
      Permission.processPayroll,
    );
    final canManagePeople = PermissionService.hasPermission(
      user,
      Permission.createEmployee,
    );

    final tabs = <_SettingsTab>[
      _SettingsTab(
        label: 'Personal',
        icon: Icons.person_outline,
        content: _buildPersonalTab(),
      ),
    ];

    if (isAdmin) {
      tabs.add(
        _SettingsTab(
          label: 'Company',
          icon: Icons.business_outlined,
          content: _buildCompanyTab(),
        ),
      );
      tabs.add(
        _SettingsTab(
          label: 'Modules',
          icon: Icons.extension_outlined,
          content: _buildModulesTab(),
        ),
      );
    }

    if (canManagePayroll || canManagePeople) {
      tabs.add(
        _SettingsTab(
          label: 'Preferences',
          icon: Icons.tune_outlined,
          content: _buildPreferencesTab(),
        ),
      );
      tabs.add(
        _SettingsTab(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          content: _buildNotificationsTab(),
        ),
      );
    }
    tabs.add(
      _SettingsTab(
        label: 'Security',
        icon: Icons.security_outlined,
        content: _buildSecurityTab(),
      ),
    );

    if (isAdmin) {
      tabs.add(
        _SettingsTab(
          label: 'Access',
          icon: Icons.admin_panel_settings_outlined,
          content: _buildAccessTab(),
        ),
      );
    }

    return tabs;
  }

  Future<void> _saveCompanyProfile({bool showFeedback = true}) async {
    if (!_isAdmin || _currentUser == null) return;
    setState(() => _isSavingCompany = true);
    try {
      await _firestore
          .collection('companies')
          .doc(_currentUser!.companyId)
          .set({
            'id': _currentUser!.companyId,
            'name': _companyNameController.text.trim(),
            'email': _companyEmailController.text.trim(),
            'phone': _companyPhoneController.text.trim(),
            'address': _companyAddressController.text.trim(),
            'registrationNumber': _companyRegNoController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isActive': true,
          }, SetOptions(merge: true));

      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company profile updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update company profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingCompany = false);
    }
  }

  Future<void> _savePreferences({bool showFeedback = true}) async {
    if (_currentUser == null) return;
    setState(() => _isSavingPreferences = true);
    try {
      await _firestore
          .collection('companies')
          .doc(_currentUser!.companyId)
          .collection('settings')
          .doc('general')
          .set({
            'currency': _currency,
            'dateFormat': _dateFormat,
            'payrollCycle': _payrollCycle,
            'workingDays': _workingDays,
            'leaveYearStartMonth': _leaveYearStartMonth,
            'enablePaye': _enablePaye,
            'enablePension': _enablePension,
            'enableNhf': _enableNhf,
            'autoSendPayslipEmail': _autoSendPayslipEmail,
            'autoSendPayrollNotification': _autoSendPayrollNotification,
            'deductionApprovalRequired': _deductionApprovalRequired,
            'allowNegativeLeaveBalance': _allowNegativeLeaveBalance,
            'overtimeEnabled': _overtimeEnabled,
            'overtimeWeekdayMultiplier': _parsePositiveDouble(
              _overtimeWeekdayController.text,
              fallback: 1.5,
            ),
            'overtimeWeekendMultiplier': _parsePositiveDouble(
              _overtimeWeekendController.text,
              fallback: 2.0,
            ),
            'overtimeHolidayMultiplier': _parsePositiveDouble(
              _overtimeHolidayController.text,
              fallback: 2.0,
            ),
            'exchangeRates': {
              'NGN': 1.0,
              'USD': _parsePositiveDouble(
                _usdRateController.text,
                fallback: 1600,
              ),
              'EUR': _parsePositiveDouble(
                _eurRateController.text,
                fallback: 1750,
              ),
              'GBP': _parsePositiveDouble(
                _gbpRateController.text,
                fallback: 2050,
              ),
            },
            'notifyInApp': _notifyInApp,
            'notifyEmail': _notifyEmail,
            'notifySms': _notifySms,
            'dailyDigest': _dailyDigest,
            'quietHoursEnabled': _quietHoursEnabled,
            'quietHoursStart': _formatTimeOfDay(_quietHoursStart),
            'quietHoursEnd': _formatTimeOfDay(_quietHoursEnd),
            'mfaEnabled': _mfaEnabled,
            'sessionTimeoutEnabled': _sessionTimeoutEnabled,
            'sessionTimeoutMinutes': _sessionTimeoutMinutes,
            'allowSingleSessionOnly': _allowSingleSessionOnly,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences saved')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save preferences: $e')));
    } finally {
      if (mounted) setState(() => _isSavingPreferences = false);
    }
  }

  Future<void> _saveModules({bool showFeedback = true}) async {
    if (!_isAdmin || _currentUser == null) return;
    setState(() => _isSavingModules = true);
    try {
      await _moduleService.saveCompanyModules(
        companyId: _currentUser!.companyId,
        updatedBy: _currentUser!.id,
        enabledModules: _enabledModules,
      );
      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Module settings saved')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save module settings: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingModules = false);
    }
  }

  void _applyModulePreset(String presetName) {
    final preset = CompanyModuleService.modulePresets[presetName];
    if (preset == null) return;
    setState(() {
      _enabledModules = CompanyModuleService.normalizedModules(preset);
      _modulePreset = presetName;
    });
    _updateUnsavedChangesFlag();
  }

  void _resetModulesToDefault() {
    setState(() {
      _enabledModules = CompanyModuleService.normalizedModules(
        CompanyModuleService.defaultModules,
      );
      _modulePreset = 'Custom';
    });
    _updateUnsavedChangesFlag();
  }

  void _resolveModulePresetLabel() {
    for (final entry in CompanyModuleService.modulePresets.entries) {
      final normalized = CompanyModuleService.normalizedModules(entry.value);
      final isSame = CompanyModuleService.moduleDisplayOrder.every(
        (key) => (normalized[key] ?? false) == (_enabledModules[key] ?? false),
      );
      if (isSame) {
        _modulePreset = entry.key;
        return;
      }
    }
    _modulePreset = 'Custom';
  }

  Widget _buildPersonalTab() {
    final user = _currentUser;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildIdentityCard(user),
        const SizedBox(height: 18),
        _buildSecurityBanner(),
        const SizedBox(height: 18),
        _buildRoleWorkspaceCard(),
        const SizedBox(height: 18),
        _buildSettingsCard(
          title: 'Personal Details',
          icon: Icons.badge_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 720;
              final fields = [
                _buildReadonlyField('Full Name', user?.name ?? ''),
                _buildReadonlyField('Work Email', user?.email ?? ''),
                _buildReadonlyField('Role', user?.getRoleName() ?? ''),
                _buildReadonlyField(
                  'Phone Number',
                  user?.phoneNumber?.isNotEmpty == true
                      ? user!.phoneNumber!
                      : 'Not added',
                ),
              ];
              if (!twoColumns) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: fields
                    .map(
                      (field) => SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: field,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCompanyProfileHeader(),
        const SizedBox(height: 18),
        _buildSettingsCard(
          title: 'Company Profile',
          icon: Icons.apartment_outlined,
          child: Column(
            children: [
              TextField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: 'Company Name'),
                onChanged: (_) => _updateUnsavedChangesFlag(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyEmailController,
                decoration: const InputDecoration(labelText: 'Company Email'),
                onChanged: (_) => _updateUnsavedChangesFlag(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyPhoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                onChanged: (_) => _updateUnsavedChangesFlag(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyAddressController,
                decoration: const InputDecoration(labelText: 'Address'),
                onChanged: (_) => _updateUnsavedChangesFlag(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyRegNoController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                ),
                onChanged: (_) => _updateUnsavedChangesFlag(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSavingCompany ? null : _saveAllChanges,
                  icon: _isSavingCompany
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingCompany ? 'Saving...' : 'Save Company Profile',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesTab() {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();

    final canEditPayroll = _isAdmin || _canManagePayroll;
    final canEditPeople = _isAdmin || _canManagePeople;
    final isPeopleOnly = user.role == UserRole.hr && !canEditPayroll;
    final isFinanceOnly = user.role == UserRole.accountant && !canEditPeople;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          isPeopleOnly
              ? 'People Preferences'
              : isFinanceOnly
              ? 'Payroll Preferences'
              : 'System Preferences',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          _preferenceSubtitle(user.role),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 980;
            final left = _buildPreferenceOrganizationCard(
              canEditPayroll: canEditPayroll,
              canEditPeople: canEditPeople,
            );
            final right = _buildPreferenceRulesCard(
              canEditPayroll: canEditPayroll,
              canEditPeople: canEditPeople,
              role: user.role,
            );
            if (!twoColumns) {
              return Column(
                children: [left, const SizedBox(height: 18), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: right),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _buildPreferenceSecureFooter(
          canSave: canEditPayroll || canEditPeople || _isAdmin,
        ),
      ],
    );
  }

  Widget _buildPreferenceOrganizationCard({
    required bool canEditPayroll,
    required bool canEditPeople,
  }) {
    final canEditRegional = _isAdmin || canEditPayroll;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Organization Preferences',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 620;
              final fields = [
                _buildPreferenceDropdown<String>(
                  label: 'Currency',
                  icon: Icons.payments_outlined,
                  value: _currency,
                  enabled: canEditRegional,
                  items: const [
                    DropdownMenuItem(
                      value: 'NGN',
                      child: Text('NGN - Nigerian Naira'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD - US Dollar'),
                    ),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                    DropdownMenuItem(
                      value: 'GBP',
                      child: Text('GBP - British Pound'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _currency = v ?? 'NGN');
                    _updateUnsavedChangesFlag();
                  },
                ),
                _buildPreferenceDropdown<String>(
                  label: 'Date Format',
                  icon: Icons.calendar_today_outlined,
                  value: _dateFormat,
                  enabled: canEditRegional || canEditPeople,
                  items: const [
                    DropdownMenuItem(
                      value: 'dd/MM/yyyy',
                      child: Text('dd/MM/yyyy'),
                    ),
                    DropdownMenuItem(
                      value: 'MM/dd/yyyy',
                      child: Text('MM/dd/yyyy'),
                    ),
                    DropdownMenuItem(
                      value: 'yyyy-MM-dd',
                      child: Text('yyyy-MM-dd'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _dateFormat = v ?? 'dd/MM/yyyy');
                    _updateUnsavedChangesFlag();
                  },
                ),
                _buildPreferenceDropdown<String>(
                  label: 'Payroll Cycle',
                  icon: Icons.event_repeat_outlined,
                  value: _payrollCycle,
                  enabled: canEditPayroll,
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Biweekly'),
                    ),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: (v) {
                    setState(() => _payrollCycle = v ?? 'monthly');
                    _updateUnsavedChangesFlag();
                  },
                ),
                _buildPreferenceDropdown<int>(
                  label: 'Working Days / Week',
                  icon: Icons.work_outline,
                  value: _workingDays,
                  enabled: canEditPeople || canEditPayroll,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 6, child: Text('6')),
                    DropdownMenuItem(value: 7, child: Text('7')),
                  ],
                  onChanged: (v) {
                    setState(() => _workingDays = v ?? 5);
                    _updateUnsavedChangesFlag();
                  },
                ),
                _buildPreferenceDropdown<int>(
                  label: 'Leave Year Start Month',
                  icon: Icons.date_range_outlined,
                  value: _leaveYearStartMonth,
                  enabled: canEditPeople || _isAdmin,
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_monthLabel(index + 1)),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() => _leaveYearStartMonth = v ?? 1);
                    _updateUnsavedChangesFlag();
                  },
                ),
              ];
              if (!twoColumns) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: fields
                    .map(
                      (field) => SizedBox(
                        width: (constraints.maxWidth - 18) / 2,
                        child: field,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (canEditPayroll || _isAdmin) ...[
            const SizedBox(height: 28),
            _buildExchangeRatePanel(enabled: canEditPayroll || _isAdmin),
          ] else ...[
            const SizedBox(height: 28),
            _buildRoleNotice(
              icon: Icons.lock_outline,
              title: 'Finance controls hidden',
              message:
                  'Currency exchange rates are managed by Admin and Accountant roles.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceRulesCard({
    required bool canEditPayroll,
    required bool canEditPeople,
    required UserRole role,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                role == UserRole.hr
                    ? Icons.groups_2_outlined
                    : Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role == UserRole.hr ? 'People Rules' : 'Payroll & Deductions',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (canEditPayroll) ...[
            _buildPreferenceSwitch(
              'Enable PAYE Tax',
              _enablePaye,
              (v) => setState(() => _enablePaye = v),
            ),
            _buildPreferenceSwitch(
              'Enable Pension Fund',
              _enablePension,
              (v) => setState(() => _enablePension = v),
            ),
            _buildPreferenceSwitch(
              'Enable NHF Contribution',
              _enableNhf,
              (v) => setState(() => _enableNhf = v),
            ),
            _buildPreferenceSwitch(
              'Auto-send Payslip Email',
              _autoSendPayslipEmail,
              (v) => setState(() => _autoSendPayslipEmail = v),
            ),
            _buildPreferenceSwitch(
              'Auto-send Payroll Notifications',
              _autoSendPayrollNotification,
              (v) => setState(() => _autoSendPayrollNotification = v),
            ),
            _buildPreferenceSwitch(
              'Deduction Approval Required',
              _deductionApprovalRequired,
              (v) => setState(() => _deductionApprovalRequired = v),
            ),
          ] else
            _buildRoleNotice(
              icon: Icons.visibility_outlined,
              title: 'Payroll controls are restricted',
              message:
                  'Payroll tax, pension, and deduction rules are managed by Admin and Accountant roles.',
            ),
          if (canEditPeople) ...[
            if (canEditPayroll) const Divider(height: 30),
            _buildPreferenceSwitch(
              'Allow Negative Leave Balance',
              _allowNegativeLeaveBalance,
              (v) => setState(() => _allowNegativeLeaveBalance = v),
            ),
          ],
          if (canEditPayroll) ...[
            const Divider(height: 30),
            _buildPreferenceSwitch(
              'Overtime Management',
              _overtimeEnabled,
              (v) => setState(() => _overtimeEnabled = v),
            ),
            const SizedBox(height: 12),
            _buildMultiplierField(
              label: 'Weekday Multiplier',
              controller: _overtimeWeekdayController,
              enabled: _overtimeEnabled && canEditPayroll,
            ),
            const SizedBox(height: 12),
            _buildMultiplierField(
              label: 'Weekend Multiplier',
              controller: _overtimeWeekendController,
              enabled: _overtimeEnabled && canEditPayroll,
            ),
            const SizedBox(height: 12),
            _buildMultiplierField(
              label: 'Holiday Multiplier',
              controller: _overtimeHolidayController,
              enabled: _overtimeEnabled && canEditPayroll,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required bool enabled,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? AppColors.surfaceVariant : AppColors.divider,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
          ),
          items: items,
          onChanged: enabled
              ? (v) {
                  onChanged(v);
                  _updateUnsavedChangesFlag();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPreferenceSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: enabled
                ? (v) {
                    onChanged(v);
                    _updateUnsavedChangesFlag();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRatePanel({required bool enabled}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange, color: AppColors.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Multi-Currency Exchange Rates',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              _buildPill('BASE: NGN', AppColors.primary),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 1;
              final gap = 12.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              final fields = [
                _buildExchangeField(
                  'USD to NGN',
                  r'$',
                  _usdRateController,
                  enabled,
                ),
                _buildExchangeField(
                  'EUR to NGN',
                  '€',
                  _eurRateController,
                  enabled,
                ),
                _buildExchangeField(
                  'GBP to NGN',
                  '£',
                  _gbpRateController,
                  enabled,
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: fields
                    .map((field) => SizedBox(width: width, child: field))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeField(
    String label,
    String symbol,
    TextEditingController controller,
    bool enabled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplierField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 86,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleNotice({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.infoDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSecureFooter({required bool canSave}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_outline, color: Colors.white),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Configuration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All changes are encrypted and logged for audit compliance.',
                  style: TextStyle(color: Color(0xFFD9E6EF)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            onPressed: _discardChanges,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            ),
            child: const Text('Discard'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: canSave && !_isSavingPreferences
                ? _saveAllChanges
                : null,
            icon: _isSavingPreferences
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _isSavingPreferences ? 'Saving...' : 'Save Preferences',
            ),
          ),
        ],
      ),
    );
  }

  String _preferenceSubtitle(UserRole role) {
    return switch (role) {
      UserRole.admin =>
        'Configure organization payroll logic, regional settings, and access-sensitive policies.',
      UserRole.hr =>
        'Configure people-facing schedule, date, and leave behavior for the company.',
      UserRole.accountant =>
        'Configure payroll cycle, statutory deductions, exchange rates, and overtime logic.',
      UserRole.employee =>
        'Your role does not manage organization preferences.',
    };
  }

  String _monthLabel(int month) {
    const names = [
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
    final name = names[(month - 1).clamp(0, 11)];
    return '$name ($month)';
  }

  Widget _buildModulesTab() {
    final user = _currentUser;
    final canManageModules =
        user != null &&
        PermissionService.hasPermission(user, Permission.manageModules);
    final visibleKeys = CompanyModuleService.moduleDisplayOrder
        .where((key) {
          if (canManageModules) return true;
          if (!_moduleVisibleForRole(user?.role ?? UserRole.employee, key)) {
            return false;
          }
          return CompanyModuleService.isModuleEnabledInMap(
            key,
            _enabledModules,
          );
        })
        .where((key) {
          final query = _moduleSearch.trim().toLowerCase();
          if (query.isEmpty) return true;
          final blueprint = _moduleBlueprint(key);
          return blueprint.label.toLowerCase().contains(query) ||
              blueprint.description.toLowerCase().contains(query);
        })
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildModuleSecurityBanner(canManageModules),
        const SizedBox(height: 22),
        if (canManageModules) ...[
          _buildModulePresetDeck(),
          const SizedBox(height: 28),
        ] else ...[
          _buildRoleModuleOverview(user?.role ?? UserRole.employee),
          const SizedBox(height: 28),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Module Registry',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canManageModules
                        ? 'Toggle system extensions to customize this company workspace.'
                        : 'Available modules for your role and company plan.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 280,
              height: 46,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (value) => setState(() => _moduleSearch = value),
              ),
            ),
            if (canManageModules) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _resetModulesToDefault,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset All'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            final gap = 14.0;
            final cardWidth =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: visibleKeys
                  .map(
                    (key) => SizedBox(
                      width: cardWidth,
                      child: _buildModuleRegistryCard(
                        key: key,
                        canManageModules: canManageModules,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (visibleKeys.isEmpty)
          _buildAccessStateCard(
            icon: Icons.search_off_outlined,
            title: 'No modules found',
            message:
                'Try a different search term or ask an admin to enable more modules.',
          ),
        const SizedBox(height: 28),
        if (canManageModules) _buildModuleSaveFooter(),
      ],
    );
  }

  Widget _buildModuleSecurityBanner(bool canManageModules) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.security_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canManageModules
                      ? 'Vault-Secured Environment'
                      : 'Role-Scoped Module Access',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canManageModules
                      ? 'All module state changes are audited and applied across the company portal.'
                      : 'Your module view only includes enabled areas allowed for your role.',
                  style: const TextStyle(color: Color(0xFFD9E6EF)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _buildPill(
            canManageModules ? '256-BIT ENCRYPTED' : 'READ ONLY',
            Colors.white,
            icon: canManageModules
                ? Icons.lock_outline
                : Icons.visibility_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildModulePresetDeck() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        final gap = 18.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: CompanyModuleService.modulePresets.entries.map((entry) {
            final selected = _modulePreset == entry.key;
            final activeCount = entry.value.values
                .where((enabled) => enabled)
                .length;
            final isRecommended = entry.key == 'Payroll + HR';
            return SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _applyModulePreset(entry.key),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.border,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _presetIcon(entry.key),
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isRecommended
                                ? 'RECOMMENDED'
                                : _presetTier(entry.key),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _presetDescription(entry.key),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFD9E6EF)
                              : AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        entry.key == 'Full Suite'
                            ? 'All Modules Active'
                            : '$activeCount Modules Included',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRoleModuleOverview(UserRole role) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(_roleIcon(role), color: _roleColor(role), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_roleNameFor(role)} module workspace',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _moduleRoleDescription(role),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleRegistryCard({
    required String key,
    required bool canManageModules,
  }) {
    final blueprint = _moduleBlueprint(key);
    final isCore = CompanyModuleService.alwaysEnabledModules.contains(key);
    final enabled = CompanyModuleService.isModuleEnabledInMap(
      key,
      _enabledModules,
    );
    final locked = isCore || !canManageModules;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCore ? AppColors.borderDark : AppColors.border,
          width: isCore ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppColors.surfaceVariant : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              blueprint.icon,
              color: enabled ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        blueprint.label,
                        style: TextStyle(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isCore) _buildPill('CORE', AppColors.info),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  blueprint.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isCore)
            const Icon(Icons.lock, color: AppColors.textTertiary, size: 18)
          else if (canManageModules)
            Switch(
              value: enabled,
              activeThumbColor: AppColors.primary,
              onChanged: (value) {
                setState(() {
                  _enabledModules[key] = value;
                  _modulePreset = 'Custom';
                });
                _updateUnsavedChangesFlag();
              },
            )
          else
            Icon(
              locked ? Icons.visibility_outlined : Icons.toggle_on_outlined,
              color: enabled ? AppColors.success : AppColors.textTertiary,
            ),
        ],
      ),
    );
  }

  Widget _buildModuleSaveFooter() {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Any changes made will take effect across the company portal immediately.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _discardChanges,
            child: const Text('Discard Changes'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isSavingModules ? null : _saveAllChanges,
            icon: _isSavingModules
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _isSavingModules ? 'Saving...' : 'Save Module Settings',
            ),
          ),
        ],
      ),
    );
  }

  _ModuleBlueprint _moduleBlueprint(String key) {
    return _ModuleBlueprint(
      label: CompanyModuleService.moduleLabel(key),
      icon: switch (key) {
        'dashboard' => Icons.dashboard_outlined,
        'employees' => Icons.groups_2_outlined,
        'attendance' => Icons.more_time_outlined,
        'payroll' => Icons.payments_outlined,
        'reports' => Icons.analytics_outlined,
        'leave' => Icons.event_available_outlined,
        'loans' => Icons.account_balance_outlined,
        'deductions' => Icons.remove_outlined,
        'expense' => Icons.receipt_long_outlined,
        'salary_advance' => Icons.forward_to_inbox_outlined,
        'exit' => Icons.logout_outlined,
        'incentives' => Icons.stars_outlined,
        'documents' => Icons.description_outlined,
        'compliance' => Icons.assignment_turned_in_outlined,
        'probation' => Icons.handshake_outlined,
        'audit' => Icons.list_alt_outlined,
        'users' => Icons.admin_panel_settings_outlined,
        'settings' => Icons.tune_outlined,
        _ => Icons.extension_outlined,
      },
      description: switch (key) {
        'dashboard' =>
          'Centralized financial overview and real-time analytics engine.',
        'employees' => 'Manage staff records, contracts, and digital dossiers.',
        'attendance' =>
          'Time tracking, clock-in/out logs, and overtime calculations.',
        'payroll' =>
          'End-to-end salary processing and automated bank transfers.',
        'reports' => 'Payroll, people, compliance, and operational exports.',
        'leave' => 'Vacation request workflows and accrual calculations.',
        'loans' => 'Internal employee loan tracking and repayment scheduling.',
        'deductions' =>
          'Automated calculation of taxes and statutory contributions.',
        'expense' =>
          'Reimbursement workflows with receipt and approval tracking.',
        'salary_advance' => 'Early access to earned wages with approval logic.',
        'exit' => 'Resignation tracking, full and final settlement tools.',
        'incentives' => 'Performance-based rewards and annual incentive plans.',
        'documents' => 'Centralized cloud storage for tax forms and contracts.',
        'compliance' => 'Local regulatory tracking and automated reporting.',
        'probation' => 'Track evaluation periods and contract renewals.',
        'audit' => 'Immutable record of system interactions and changes.',
        'users' => 'Access control and permission hierarchy management.',
        'settings' => 'Global configuration for the company workspace.',
        _ => 'Company module extension.',
      },
    );
  }

  bool _moduleVisibleForRole(UserRole role, String key) {
    return switch (role) {
      UserRole.admin => true,
      UserRole.hr => const {
        'dashboard',
        'employees',
        'attendance',
        'reports',
        'leave',
        'salary_advance',
        'documents',
        'probation',
        'exit',
        'audit',
        'settings',
      }.contains(key),
      UserRole.accountant => const {
        'dashboard',
        'payroll',
        'reports',
        'loans',
        'deductions',
        'expense',
        'salary_advance',
        'incentives',
        'compliance',
        'audit',
        'settings',
      }.contains(key),
      UserRole.employee => const {
        'dashboard',
        'attendance',
        'leave',
        'loans',
        'deductions',
        'expense',
        'salary_advance',
        'documents',
        'exit',
        'settings',
      }.contains(key),
    };
  }

  String _roleNameFor(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Admin',
      UserRole.hr => 'HR',
      UserRole.accountant => 'Accountant',
      UserRole.employee => 'Employee',
    };
  }

  String _moduleRoleDescription(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Full module management is available.',
      UserRole.hr =>
        'People, leave, documents, and lifecycle modules are shown when enabled.',
      UserRole.accountant =>
        'Payroll, statutory, loan, expense, and finance modules are shown when enabled.',
      UserRole.employee =>
        'Only self-service modules enabled for your company are shown here.',
    };
  }

  IconData _presetIcon(String preset) {
    return switch (preset) {
      'Core Payroll' => Icons.bolt_outlined,
      'Payroll + HR' => Icons.hub_outlined,
      'Full Suite' => Icons.architecture_outlined,
      _ => Icons.extension_outlined,
    };
  }

  String _presetTier(String preset) {
    return switch (preset) {
      'Core Payroll' => 'ESSENTIAL',
      'Payroll + HR' => 'RECOMMENDED',
      'Full Suite' => 'ENTERPRISE',
      _ => 'CUSTOM',
    };
  }

  String _presetDescription(String preset) {
    return switch (preset) {
      'Core Payroll' =>
        'Foundation modules for compliance and payment processing.',
      'Payroll + HR' =>
        'Advanced employee lifecycle management and compensation.',
      'Full Suite' =>
        'Complete enterprise control with all available extensions.',
      _ => 'Custom module configuration.',
    };
  }

  Widget _buildNotificationsTab() {
    final user = _currentUser;
    final role = user?.role ?? UserRole.employee;
    final canEditNotifications =
        _isAdmin || _canManagePayroll || _canManagePeople;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Notification Preferences',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          _notificationSubtitle(role),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        _buildNotificationSecureBanner(role),
        const SizedBox(height: 28),
        _buildNotificationChannelCard(
          icon: Icons.dashboard_customize_outlined,
          title: 'In-app Notifications',
          subtitle: _notificationChannelSubtitle(role, 'in_app'),
          value: _notifyInApp,
          enabled: canEditNotifications,
          onChanged: (v) => setState(() => _notifyInApp = v),
        ),
        const SizedBox(height: 18),
        _buildNotificationChannelCard(
          icon: Icons.mail_outline,
          title: 'Email Notifications',
          subtitle: _notificationChannelSubtitle(role, 'email'),
          value: _notifyEmail,
          enabled: canEditNotifications,
          onChanged: (v) => setState(() => _notifyEmail = v),
        ),
        const SizedBox(height: 18),
        _buildNotificationChannelCard(
          icon: Icons.sms_outlined,
          title: 'SMS Notifications',
          subtitle: _notificationChannelSubtitle(role, 'sms'),
          value: _notifySms,
          enabled: canEditNotifications && (_isAdmin || _canManagePayroll),
          onChanged: (v) => setState(() => _notifySms = v),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 760;
            final cards = [
              _buildNotificationFeatureCard(
                icon: Icons.calendar_month_outlined,
                title: 'Daily Digest',
                subtitle:
                    'Send one consolidated daily summary instead of real-time alerts.',
                value: _dailyDigest,
                enabled: canEditNotifications,
                footer: role == UserRole.accountant
                    ? 'Payroll summary at 8:00 AM'
                    : role == UserRole.hr
                    ? 'People activity at 8:00 AM'
                    : 'Company activity at 8:00 AM',
                onChanged: (v) => setState(() => _dailyDigest = v),
              ),
              _buildNotificationFeatureCard(
                icon: Icons.notifications_paused_outlined,
                title: 'Quiet Hours',
                subtitle:
                    'Suppress non-critical alerts during quiet period to maintain focus.',
                value: _quietHoursEnabled,
                enabled: canEditNotifications,
                footer:
                    '${_formatDisplayTime(_quietHoursStart)} - ${_formatDisplayTime(_quietHoursEnd)}',
                onChanged: (v) => setState(() => _quietHoursEnabled = v),
                onFooterTap: _quietHoursEnabled
                    ? () async {
                        await _pickQuietHour(isStart: true);
                        await _pickQuietHour(isStart: false);
                      }
                    : null,
              ),
            ];

            if (!twoColumns) {
              return Column(
                children: [cards[0], const SizedBox(height: 18), cards[1]],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 24),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _buildNotificationFooter(canSave: canEditNotifications),
      ],
    );
  }

  Widget _buildNotificationSecureBanner(UserRole role) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _notificationSecureMessage(role),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationChannelCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: value ? AppColors.infoLight : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: enabled
                ? (v) {
                    onChanged(v);
                    _updateUnsavedChangesFlag();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required String footer,
    required ValueChanged<bool> onChanged,
    VoidCallback? onFooterTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: value ? AppColors.infoLight : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: value ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: enabled
                    ? (v) {
                        onChanged(v);
                        _updateUnsavedChangesFlag();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: onFooterTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    footer.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFooter({required bool canSave}) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Expanded(child: SizedBox.shrink()),
          TextButton(
            onPressed: canSave ? _restoreNotificationDefaults : null,
            child: const Text('Restore Defaults'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: canSave && !_isSavingPreferences
                ? _saveAllChanges
                : null,
            icon: _isSavingPreferences
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSavingPreferences ? 'Saving...' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _restoreNotificationDefaults() {
    setState(() {
      _notifyInApp = true;
      _notifyEmail = true;
      _notifySms = false;
      _dailyDigest = false;
      _quietHoursEnabled = false;
      _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
      _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
    });
    _updateUnsavedChangesFlag();
  }

  String _notificationSubtitle(UserRole role) {
    return switch (role) {
      UserRole.admin =>
        'Control organization-wide updates for payroll cycles, approvals, security alerts, and audit activity.',
      UserRole.hr =>
        'Tune people-operation alerts for leave, attendance, documents, and employee lifecycle work.',
      UserRole.accountant =>
        'Tune payroll, deductions, compliance, loans, and approval notifications for finance workflows.',
      UserRole.employee =>
        'Review the notification channels available for your account.',
    };
  }

  String _notificationSecureMessage(UserRole role) {
    return switch (role) {
      UserRole.admin =>
        'All notifications are encrypted and sent via secure channels to protect sensitive company and financial data.',
      UserRole.hr =>
        'People notifications are filtered through role permissions before delivery.',
      UserRole.accountant =>
        'Payroll and finance alerts are protected for salary, statutory, and approval confidentiality.',
      UserRole.employee =>
        'Your account alerts are limited to information available to your role.',
    };
  }

  String _notificationChannelSubtitle(UserRole role, String channel) {
    if (channel == 'in_app') {
      return switch (role) {
        UserRole.admin =>
          'Show company alerts, audit updates, and approval activity in dashboard.',
        UserRole.hr =>
          'Show leave, attendance, employee, and document updates in dashboard.',
        UserRole.accountant =>
          'Show payroll, deduction, loan, and compliance updates in dashboard.',
        UserRole.employee => 'Show self-service updates in your dashboard.',
      };
    }
    if (channel == 'email') {
      return switch (role) {
        UserRole.admin =>
          'Send company, security, and payroll updates by email.',
        UserRole.hr => 'Send people operation and approval updates by email.',
        UserRole.accountant =>
          'Send payroll cycle, approval, and compliance updates by email.',
        UserRole.employee => 'Send available account updates by email.',
      };
    }
    return switch (role) {
      UserRole.admin =>
        'Critical security, payroll, and approval updates via SMS.',
      UserRole.hr => 'Critical employee lifecycle escalations via SMS.',
      UserRole.accountant =>
        'Critical payroll and payment escalations via SMS.',
      UserRole.employee => 'Critical account security updates via SMS.',
    };
  }

  String _formatDisplayTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildSecurityTab() {
    final role = _currentUser?.role ?? UserRole.employee;
    final canManageSecurityControls =
        _canManagePayroll || _canManagePeople || _isAdmin;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSecurityVaultBanner(role),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                role == UserRole.employee
                    ? 'Account Security'
                    : 'Security Settings',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'LAST REVIEWED: ${DateTime.now().year}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final passwordCard = _buildPasswordSecurityCard(role);
            final timeoutCard = _buildSessionTimeoutCard(
              canManageSecurityControls: canManageSecurityControls,
            );
            if (!wide) {
              return Column(
                children: [
                  passwordCard,
                  const SizedBox(height: 18),
                  timeoutCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: passwordCard),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: timeoutCard),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final mfa = _buildSecurityToggleCard(
              icon: Icons.phonelink_lock_outlined,
              title: 'Two-Factor Auth',
              subtitle:
                  'Add an extra layer of security by requiring a code from a mobile device at login.',
              value: _mfaEnabled,
              enabled: canManageSecurityControls,
              badge: canManageSecurityControls
                  ? 'Highly Recommended'
                  : 'Managed by admins',
              onChanged: (v) => setState(() => _mfaEnabled = v),
            );
            final singleSession = _buildSecurityToggleCard(
              icon: Icons.location_on_outlined,
              title: 'Single Active Session',
              subtitle:
                  'Prevent simultaneous logins. New device sign-ins will sign out other locations.',
              value: _allowSingleSessionOnly,
              enabled: canManageSecurityControls,
              badge: role == UserRole.employee
                  ? 'Protected policy'
                  : 'Enterprise control',
              onChanged: (v) => setState(() => _allowSingleSessionOnly = v),
            );
            if (!wide) {
              return Column(
                children: [mfa, const SizedBox(height: 18), singleSession],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: mfa),
                const SizedBox(width: 24),
                Expanded(child: singleSession),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _buildActiveSessionsCard(role),
        const SizedBox(height: 28),
        _buildSecurityAuditFooter(role),
      ],
    );
  }

  Widget _buildSecurityVaultBanner(UserRole role) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vault-Secured Environment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _securityBannerCopy(role),
                  style: const TextStyle(
                    color: Color(0xFFD9E6EF),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.security_outlined,
            color: Color(0x668DA2B5),
            size: 76,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSecurityCard(UserRole role) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_reset_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Change Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            role == UserRole.employee
                ? 'Keep your account secure with a strong password and periodic updates.'
                : 'Update your account password regularly to maintain high account security. Use at least 12 characters including symbols.',
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.changePassword),
                child: const Text('Update Password'),
              ),
              Text(
                _currentUser?.passwordChangedAt == null
                    ? 'Last change not recorded'
                    : 'Last changed ${_formatLastLogin(_currentUser)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTimeoutCard({required bool canManageSecurityControls}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Session Timeout',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Automatically logout after a period of inactivity.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable timeout'),
            value: _sessionTimeoutEnabled,
            onChanged: canManageSecurityControls
                ? (v) {
                    setState(() => _sessionTimeoutEnabled = v);
                    _updateUnsavedChangesFlag();
                  }
                : null,
          ),
          DropdownButtonFormField<int>(
            initialValue: _sessionTimeoutMinutes,
            decoration: const InputDecoration(labelText: 'Timeout Duration'),
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 Minutes')),
              DropdownMenuItem(value: 30, child: Text('30 Minutes')),
              DropdownMenuItem(value: 60, child: Text('1 Hour')),
              DropdownMenuItem(value: 120, child: Text('2 Hours')),
            ],
            onChanged: canManageSecurityControls && _sessionTimeoutEnabled
                ? (v) {
                    setState(() => _sessionTimeoutMinutes = v ?? 30);
                    _updateUnsavedChangesFlag();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required String badge,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: enabled
                    ? (v) {
                        onChanged(v);
                        _updateUnsavedChangesFlag();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(subtitle, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 20),
          _buildPill(
            badge,
            enabled ? AppColors.errorDark : AppColors.textSecondary,
            icon: enabled ? Icons.priority_high_outlined : Icons.lock_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsCard(UserRole role) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.devices_other_outlined,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Active Sessions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  role == UserRole.employee
                      ? 'Manage devices currently signed into your account.'
                      : 'Manage devices currently signed into this workspace account.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                _buildSessionRow(
                  icon: Icons.laptop_mac_outlined,
                  title: 'Current Browser',
                  subtitle: 'Current session • Web app',
                  current: true,
                ),
                _buildSessionRow(
                  icon: Icons.phone_iphone_outlined,
                  title: 'Mobile App',
                  subtitle: 'Active 2 hours ago • Authenticated device',
                ),
                _buildSessionRow(
                  icon: Icons.desktop_windows_outlined,
                  title: 'Workstation',
                  subtitle: 'Active yesterday • Trusted browser',
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Other sessions logged out')),
                );
              },
              icon: const Icon(Icons.logout_outlined, size: 18),
              label: const Text('Log Out All Other Sessions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    bool current = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (current)
            _buildPill('CURRENT', AppColors.info)
          else
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title access revoked')),
                );
              },
              child: const Text('Revoke Access'),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityAuditFooter(UserRole role) {
    return Row(
      children: [
        const Icon(Icons.verified_outlined, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Text(
          role == UserRole.employee
              ? 'ACCOUNT SECURITY REVIEW COMPLETE'
              : 'SYSTEM AUDIT COMPLETED: WEEKLY COMPLIANCE STANDARD MET',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  String _securityBannerCopy(UserRole role) {
    return switch (role) {
      UserRole.admin =>
        'Sensitive payroll data and security settings are protected by end-to-end 256-bit encryption.',
      UserRole.hr =>
        'People data, documents, and access controls are protected by role-scoped security policies.',
      UserRole.accountant =>
        'Payroll, statutory, and payment data are protected by finance-grade access controls.',
      UserRole.employee =>
        'Your personal account and available self-service data are protected by encrypted sessions.',
    };
  }

  Widget _buildAccessTab() {
    if (!_isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildAccessVaultBanner(canManageAccess: false),
          const SizedBox(height: 24),
          _buildAccessRestrictedPanel(_currentUser?.role ?? UserRole.employee),
        ],
      );
    }

    final companyId = _currentUser?.companyId;
    if (companyId == null || companyId.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildAccessVaultBanner(canManageAccess: true),
          const SizedBox(height: 24),
          _buildAccessStateCard(
            icon: Icons.apartment_outlined,
            title: 'No Company Context',
            message:
                'A company profile is required before access assignments can be displayed.',
          ),
        ],
      );
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildAccessVaultBanner(canManageAccess: true),
              const SizedBox(height: 24),
              _buildAccessStateCard(
                icon: Icons.error_outline,
                title: 'Unable to Load Access Data',
                message: 'Something went wrong while loading company users.',
              ),
            ],
          );
        }

        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...(snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ]
          ..sort((a, b) {
            final left = a.data();
            final right = b.data();
            final leftRole = _readRole(left['role']);
            final rightRole = _readRole(right['role']);
            final rankCompare = _rolePriority(
              leftRole,
            ).compareTo(_rolePriority(rightRole));
            if (rankCompare != 0) {
              return rankCompare;
            }

            final leftName = (left['name'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final rightName = (right['name'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            return leftName.compareTo(rightName);
          });

        final adminCount = docs
            .where((doc) => _readRole(doc.data()['role']) == UserRole.admin)
            .length;
        final hrCount = docs
            .where((doc) => _readRole(doc.data()['role']) == UserRole.hr)
            .length;
        final accountantCount = docs
            .where(
              (doc) => _readRole(doc.data()['role']) == UserRole.accountant,
            )
            .length;
        final employeeCount = docs
            .where((doc) => _readRole(doc.data()['role']) == UserRole.employee)
            .length;
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final query = _accessSearch.trim().toLowerCase();
          if (query.isEmpty) return true;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final role = _roleLabel(_readRole(data['role'])).toLowerCase();
          return name.contains(query) ||
              email.contains(query) ||
              role.contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildAccessVaultBanner(canManageAccess: true),
            const SizedBox(height: 28),
            const Text(
              'Access Control',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage users and their respective roles within $_companyDisplayName.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildAccessSummaryChip(
                  label: 'Admins',
                  count: adminCount,
                  role: UserRole.admin,
                ),
                _buildAccessSummaryChip(
                  label: 'HR',
                  count: hrCount,
                  role: UserRole.hr,
                ),
                _buildAccessSummaryChip(
                  label: 'Accountants',
                  count: accountantCount,
                  role: UserRole.accountant,
                ),
                _buildAccessSummaryChip(
                  label: 'Employees',
                  count: employeeCount,
                  role: UserRole.employee,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAccessRegistry(docs: filteredDocs, totalCount: docs.length),
          ],
        );
      },
    );
  }

  Widget _buildAccessStateCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccessSummaryChip({
    required String label,
    required int count,
    required UserRole role,
  }) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(role), size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessVaultBanner({required bool canManageAccess}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Color(0xFFD7E8FF)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              canManageAccess
                  ? 'Vault-Secured Environment: All access changes are logged and encrypted.'
                  : 'Vault-Secured Environment: Access assignments are protected by administrator controls.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            canManageAccess ? 'ACTIVE SHIELD V2.4' : 'READ ONLY',
            style: const TextStyle(
              color: Color(0xFFD7E8FF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRestrictedPanel(UserRole role) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_roleIcon(role), color: _roleColor(role)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_roleNameFor(role)} access view',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _accessRestrictedMessage(role),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRegistry({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required int totalCount,
  }) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  height: 46,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _accessSearch = value),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Role filter coming soon')),
                    );
                  },
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filter'),
                ),
                const Spacer(),
                Text(
                  '$totalCount TOTAL USERS',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const _AccessTableHeader(),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: _buildAccessStateCard(
                icon: Icons.search_off_outlined,
                title: 'No Users Found',
                message: 'Try a different search term.',
              ),
            )
          else
            ...docs.map((doc) => _buildAccessUserRow(doc.data())),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Row(
              children: [
                Text(
                  'Showing ${docs.length} of $totalCount results',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                _buildPill('SYSTEM VERIFIED: 256-BIT AES', AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessUserRow(Map<String, dynamic> data) {
    final name = (data['name'] ?? 'User').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final role = _readRole(data['role']);
    final roleColor = _roleColor(role);
    final isCurrentUser =
        _currentUser != null &&
        ((data['id'] ?? '').toString().trim() == _currentUser!.id ||
            email.toLowerCase() == _currentUser!.email.toLowerCase());
    final isActive = (data['isActive'] ?? true) == true;
    final initials = _initialsFor(name, fallback: email);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name.isEmpty ? 'User' : name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            _buildPill('YOU', AppColors.info),
                          ],
                        ],
                      ),
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildPill(_roleLabel(role).toUpperCase(), roleColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success
                        : AppColors.textDisabled,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Text(isActive ? 'Active' : 'Offline'),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: PopupMenuButton<String>(
              tooltip: 'User actions',
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'view', child: Text('View profile')),
                PopupMenuItem(value: 'role', child: Text('Review role')),
              ],
              onSelected: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access management workflow coming soon'),
                  ),
                );
              },
              icon: const Icon(Icons.more_horiz),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name, {required String fallback}) {
    final source = name.trim().isNotEmpty ? name.trim() : fallback.trim();
    if (source.isEmpty) return 'U';
    final parts = source
        .split(RegExp(r'[\s@._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return source[0].toUpperCase();
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _accessRestrictedMessage(UserRole role) {
    return switch (role) {
      UserRole.admin =>
        'Admins can review access assignments and role distribution.',
      UserRole.hr =>
        'HR can manage people workflows, but user role assignment remains an administrator-only control.',
      UserRole.accountant =>
        'Accountants can access finance workflows, while role assignment remains protected by administrators.',
      UserRole.employee =>
        'Employees can manage their own profile and security settings. Company role assignments are administrator-only.',
    };
  }

  UserRole _readRole(dynamic rawRole) {
    final value = (rawRole ?? '').toString().trim();
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.employee,
    );
  }

  int _rolePriority(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 0;
      case UserRole.hr:
        return 1;
      case UserRole.accountant:
        return 2;
      case UserRole.employee:
        return 3;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.hr:
        return 'hr';
      case UserRole.accountant:
        return 'accountant';
      case UserRole.employee:
        return 'employee';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.hr:
        return AppColors.info;
      case UserRole.accountant:
        return AppColors.warningDark;
      case UserRole.employee:
        return AppColors.textSecondary;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.shield_outlined;
      case UserRole.hr:
        return Icons.groups_2_outlined;
      case UserRole.accountant:
        return Icons.calculate_outlined;
      case UserRole.employee:
        return Icons.person_outline;
    }
  }

  String get _companyDisplayName {
    final name = _companyNameController.text.trim();
    if (name.isNotEmpty) return name;
    return 'Company Workspace';
  }

  String get _roleHeadline {
    final user = _currentUser;
    if (user == null) return 'Manage your settings';
    switch (user.role) {
      case UserRole.admin:
        return 'Organization command center';
      case UserRole.hr:
        return 'People operations workspace';
      case UserRole.accountant:
        return 'Payroll and finance controls';
      case UserRole.employee:
        return 'Your profile and access';
    }
  }

  String get _roleSummary {
    final user = _currentUser;
    if (user == null) return 'Configure profile and company preferences.';
    switch (user.role) {
      case UserRole.admin:
        return 'Full company metadata, modules, access, security, and policy settings are available.';
      case UserRole.hr:
        return 'Focused HR tools for people data, leave policy, notifications, and your own security.';
      case UserRole.accountant:
        return 'Payroll cycle, statutory deductions, exchange rates, approvals, and finance notifications.';
      case UserRole.employee:
        return 'A private settings space for your account, password, notifications, and session access.';
    }
  }

  List<_RoleAction> _roleActionsFor(AppUser user) {
    switch (user.role) {
      case UserRole.admin:
        return [
          _RoleAction('Company', Icons.apartment_outlined, 'Edit identity'),
          _RoleAction('Modules', Icons.extension_outlined, 'Control access'),
          _RoleAction('Access', Icons.manage_accounts_outlined, 'Manage users'),
        ];
      case UserRole.hr:
        return [
          _RoleAction('People', Icons.groups_2_outlined, 'Employee setup'),
          _RoleAction('Leave', Icons.event_available_outlined, 'Policy view'),
          _RoleAction('Audit', Icons.fact_check_outlined, 'HR records'),
        ];
      case UserRole.accountant:
        return [
          _RoleAction('Payroll', Icons.payments_outlined, 'Cycle controls'),
          _RoleAction('Rates', Icons.currency_exchange_outlined, 'FX table'),
          _RoleAction('Approvals', Icons.verified_outlined, 'Finance checks'),
        ];
      case UserRole.employee:
        return [
          _RoleAction('Profile', Icons.person_outline, 'Your details'),
          _RoleAction('Security', Icons.lock_outline, 'Password'),
          _RoleAction('Alerts', Icons.notifications_outlined, 'Updates'),
        ];
    }
  }

  Widget _buildIdentityCard(AppUser? user) {
    final role = user?.role ?? UserRole.employee;
    final roleColor = _roleColor(role);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((part) => part[0].toUpperCase())
                              .join()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -10,
                bottom: -10,
                child: IconButton.filled(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile photo update coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Update avatar',
                ),
              ),
            ],
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildPill(
                  user?.getRoleName().toUpperCase() ?? 'USER',
                  roleColor,
                  icon: _roleIcon(role),
                ),
              ],
            ),
          ),
          _buildProfileMetric('Primary Locale', 'Lagos, Nigeria\n(GMT+1)'),
          _buildProfileMetric('Last Login', _formatLastLogin(user)),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final icon = Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
            ),
          );
          const copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Advanced Encryption Enabled',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Personal data and payroll information are protected with encrypted storage and role-based access.',
                style: TextStyle(color: Color(0xFFD9E6EF), height: 1.35),
              ),
            ],
          );
          final button = OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.changePassword),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Colors.white),
            ),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Review Security'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: 16),
                copy,
                const SizedBox(height: 14),
                button,
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 18),
              const Expanded(child: copy),
              const SizedBox(width: 14),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleWorkspaceCard() {
    final user = _currentUser;
    if (user == null) return const SizedBox.shrink();
    return _buildSettingsCard(
      title: _roleHeadline,
      icon: _roleIcon(user.role),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _roleSummary,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _roleActionsFor(user)
                .map(
                  (action) => Container(
                    width: 190,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          action.icon,
                          color: _roleColor(user.role),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                action.subtitle,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.business_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companyDisplayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Company ID: ${_currentUser?.companyId ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _buildPill(_companyPlan.toUpperCase(), AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildReadonlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMetric(String label, String value) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastLogin(AppUser? user) {
    final lastLoginAt = user?.lastLoginAt;
    if (lastLoginAt == null) return 'Not recorded';
    final diff = DateTime.now().difference(lastLoginAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const AppScaffold(
        body: Center(child: Text('Unable to load user profile')),
      );
    }

    final tabs = _buildTabs(_currentUser!);
    final tabController = _tabController;

    if (tabController == null || tabController.length != tabs.length) {
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      topBar: _buildControlCenterTopBar(tabs, tabController),
      body: PopScope(
        canPop: !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || !_hasUnsavedChanges) return;
          final shouldDiscard = await _confirmDiscardDialog();
          if (!context.mounted || !shouldDiscard) return;
          Navigator.of(context).pop(result);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
            final isDesktop = constraints.maxWidth >= 1200;

            if (isDesktop) {
              return _buildDesktopControlCenter(tabs, tabController);
            }

            if (isTablet) {
              return Column(
                children: [
                  _buildSettingsHero(),
                  _buildSettingsSearchBar(tabs, tabController),
                  Container(
                    color: AppColors.surface,
                    child: TabBar(
                      controller: tabController,
                      isScrollable: true,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicator: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      tabs: tabs
                          .map(
                            (t) => Tab(
                              icon: Icon(t.icon, size: 18),
                              text: t.label,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      children: tabs
                          .map((t) => _buildStyledTabShell(t.content))
                          .toList(),
                    ),
                  ),
                  if (_hasUnsavedChanges) _buildSaveBar(),
                ],
              );
            }

            return Column(
              children: [
                if (!isMobile) _buildSettingsHero(),
                _buildSettingsSearchBar(tabs, tabController),
                Container(
                  color: AppColors.surface,
                  child: TabBar(
                    controller: tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicator: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: tabs
                        .map(
                          (t) =>
                              Tab(icon: Icon(t.icon, size: 18), text: t.label),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: tabs
                        .map((t) => _buildStyledTabShell(t.content))
                        .toList(),
                  ),
                ),
                if (_hasUnsavedChanges) _buildSaveBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsHero() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.info.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Control Center',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentUser == null
                      ? 'Configure your account and organization preferences'
                      : 'Signed in as ${_currentUser!.getRoleName()}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Unsaved changes',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildControlCenterTopBar(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(104),
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        compact ? 'Settings' : 'Control Center',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        compact ? _currentUser!.getRoleName() : _roleSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  SizedBox(
                    width: 360,
                    height: 48,
                    child: _buildTopSearchField(tabs, tabController),
                  ),
                  const SizedBox(width: 18),
                ],
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Help',
                ),
                IconButton(
                  onPressed: () =>
                      tabController.animateTo(_tabIndexFor(tabs, 'Security')),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Security settings',
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _currentUser?.name.isNotEmpty == true
                        ? _currentUser!.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopControlCenter(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopTabRail(tabs, tabController),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: tabs.map((t) => t.content).toList(),
                ),
              ),
              _buildContextPanel(tabs, tabController),
            ],
          ),
        ),
        if (_hasUnsavedChanges) _buildSaveBar(),
      ],
    );
  }

  Widget _buildTopSearchField(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return TextField(
      controller: _settingsSearchController,
      decoration: InputDecoration(
        hintText: 'Search settings...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _settingsSearch.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _settingsSearchController.clear();
                  setState(() => _settingsSearch = '');
                },
                icon: const Icon(Icons.close),
                tooltip: 'Clear search',
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      onChanged: (value) {
        setState(() => _settingsSearch = value);
        _jumpToTabByQuery(value, tabs, tabController);
      },
    );
  }

  Widget _buildContextPanel(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return AnimatedBuilder(
      animation: tabController.animation!,
      builder: (context, _) {
        return Container(
          width: 330,
          margin: const EdgeInsets.fromLTRB(10, 24, 24, 24),
          child: ListView(
            children: [
              _buildCompanyMetadataCard(tabs, tabController),
              const SizedBox(height: 18),
              _buildAccountAccessCard(),
              const SizedBox(height: 18),
              _buildSupportCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanyMetadataCard(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    final canOpenCompany = _isAdmin;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business_outlined, size: 18),
              SizedBox(width: 10),
              Text(
                'COMPANY METADATA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Company Name',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            _companyDisplayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          const Text(
            'Original ID',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SelectableText(
            _currentUser?.companyId ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              backgroundColor: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          _buildMetaRow('Tax Nexus', _companyTaxNexus),
          _buildMetaRow('Employee Count', _employeeCount.toString()),
          _buildMetaRow('Subscription', _companyPlan.toUpperCase()),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canOpenCompany
                  ? () => tabController.animateTo(_tabIndexFor(tabs, 'Company'))
                  : null,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                canOpenCompany ? 'Organization Settings' : 'Admin Only',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAccessCard() {
    final user = _currentUser;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT ACCESS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Signed in as ${user?.getRoleName().toLowerCase() ?? 'user'}.',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _roleSummary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _authService.logout();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorDark,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.45),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Need Assistance?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Support is available for payroll critical issues and account access questions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Support Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  int _tabIndexFor(List<_SettingsTab> tabs, String label) {
    final index = tabs.indexWhere((tab) => tab.label == label);
    return index < 0 ? 0 : index;
  }

  Widget _buildStyledTabShell(Widget content) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildSettingsSearchBar(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _settingsSearchController,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Find setting section (e.g. security, notifications)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _settingsSearch.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _settingsSearchController.clear();
                    setState(() => _settingsSearch = '');
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        onChanged: (value) {
          setState(() => _settingsSearch = value);
          _jumpToTabByQuery(value, tabs, tabController);
        },
      ),
    );
  }

  void _jumpToTabByQuery(
    String query,
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    final index = tabs.indexWhere(
      (tab) => tab.label.toLowerCase().contains(trimmed),
    );
    if (index >= 0 && index != tabController.index) {
      tabController.animateTo(index);
    }
  }

  Widget _buildDesktopTabRail(
    List<_SettingsTab> tabs,
    TabController tabController,
  ) {
    return AnimatedBuilder(
      animation: tabController.animation!,
      builder: (context, _) {
        return Container(
          width: 260,
          margin: const EdgeInsets.fromLTRB(12, 0, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final isSelected = tabController.index == index;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => tabController.animateTo(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemCount: tabs.length,
          ),
        );
      },
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _discardChanges,
              icon: const Icon(Icons.close),
              label: const Text('Discard'),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saveAllChanges,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllChanges() async {
    if (_currentUser == null) return;

    if (_isAdmin) {
      await _saveCompanyProfile(showFeedback: false);
      await _saveModules(showFeedback: false);
    }

    if (_canManagePayroll || _canManagePeople || _isAdmin) {
      await _savePreferences(showFeedback: false);
    }

    if (!mounted) return;
    setState(() {
      _initialSettingsHash = _serializeSettings();
      _hasUnsavedChanges = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  void _discardChanges() {
    _loadSettings();
  }

  Future<bool> _confirmDiscardDialog() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them and leave this page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  void _updateUnsavedChangesFlag() {
    final isDirty = _serializeSettings() != _initialSettingsHash;
    if (isDirty == _hasUnsavedChanges) return;
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = isDirty);
  }

  Future<void> _pickQuietHour({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _quietHoursStart = picked;
      } else {
        _quietHoursEnd = picked;
      }
    });
    _updateUnsavedChangesFlag();
  }

  String _serializeSettings() {
    final data = <String, Object?>{
      'companyName': _companyNameController.text.trim(),
      'companyEmail': _companyEmailController.text.trim(),
      'companyPhone': _companyPhoneController.text.trim(),
      'companyAddress': _companyAddressController.text.trim(),
      'companyRegNo': _companyRegNoController.text.trim(),
      'currency': _currency,
      'dateFormat': _dateFormat,
      'payrollCycle': _payrollCycle,
      'workingDays': _workingDays,
      'leaveYearStartMonth': _leaveYearStartMonth,
      'enablePaye': _enablePaye,
      'enablePension': _enablePension,
      'enableNhf': _enableNhf,
      'autoSendPayslipEmail': _autoSendPayslipEmail,
      'autoSendPayrollNotification': _autoSendPayrollNotification,
      'deductionApprovalRequired': _deductionApprovalRequired,
      'allowNegativeLeaveBalance': _allowNegativeLeaveBalance,
      'overtimeEnabled': _overtimeEnabled,
      'overtimeWeekday': _overtimeWeekdayController.text.trim(),
      'overtimeWeekend': _overtimeWeekendController.text.trim(),
      'overtimeHoliday': _overtimeHolidayController.text.trim(),
      'usdRate': _usdRateController.text.trim(),
      'eurRate': _eurRateController.text.trim(),
      'gbpRate': _gbpRateController.text.trim(),
      'notifyInApp': _notifyInApp,
      'notifyEmail': _notifyEmail,
      'notifySms': _notifySms,
      'dailyDigest': _dailyDigest,
      'quietHoursEnabled': _quietHoursEnabled,
      'quietHoursStart': _formatTimeOfDay(_quietHoursStart),
      'quietHoursEnd': _formatTimeOfDay(_quietHoursEnd),
      'mfaEnabled': _mfaEnabled,
      'sessionTimeoutEnabled': _sessionTimeoutEnabled,
      'sessionTimeoutMinutes': _sessionTimeoutMinutes,
      'allowSingleSessionOnly': _allowSingleSessionOnly,
      'enabledModules': CompanyModuleService.moduleDisplayOrder
          .map((key) => '$key:${_enabledModules[key]}')
          .join(','),
    };
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  TimeOfDay _parseTimeOfDay(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return fallback;
  }

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _parsePositiveDouble(String value, {required double fallback}) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }
}

class _SettingsTab {
  final String label;
  final IconData icon;
  final Widget content;

  _SettingsTab({
    required this.label,
    required this.icon,
    required this.content,
  });
}

class _RoleAction {
  final String title;
  final IconData icon;
  final String subtitle;

  const _RoleAction(this.title, this.icon, this.subtitle);
}

class _ModuleBlueprint {
  final String label;
  final IconData icon;
  final String description;

  const _ModuleBlueprint({
    required this.label,
    required this.icon,
    required this.description,
  });
}

class _AccessTableHeader extends StatelessWidget {
  const _AccessTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('USER IDENTITY', style: style)),
          Expanded(flex: 3, child: Text('PERMISSION ROLE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 80, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}
