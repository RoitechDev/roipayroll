import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_document_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/providers/document_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class DocumentManagementScreen extends ConsumerStatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  ConsumerState<DocumentManagementScreen> createState() =>
      _DocumentManagementScreenState();
}

class _DocumentManagementScreenState
    extends ConsumerState<DocumentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  EmployeeDocumentType? _selectedType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(documentDataProvider);

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(documentDataProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () =>
            const ModernLoadingState(message: 'Loading documents...'),
        error: (e, _) => ModernErrorState(
          message: 'Failed to load documents',
          subtitle: e.toString(),
          onRetry: () => ref.invalidate(documentDataProvider),
        ),
        data: (data) => ResponsiveLayout(
          mobile: _buildPage(context, data, padding: 12),
          tablet: _buildPage(context, data, padding: 16),
          desktop: _buildPage(context, data, padding: 20),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    DocumentData data, {
    required double padding,
  }) {
    final visibleDocs = _visibleDocuments(data);
    final filteredDocs = _filterDocuments(visibleDocs);
    final recentDocs = filteredDocs.take(6).toList();

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildHeader(context, data),
        const SizedBox(height: 18),
        _buildMetrics(data),
        const SizedBox(height: 18),
        _buildActionBar(context, data),
        const SizedBox(height: 18),
        switch (data.scope) {
          DocumentRoleScope.employee => _buildEmployeeView(
            context,
            data,
            filteredDocs,
            recentDocs,
          ),
          DocumentRoleScope.accountant => _buildAccountantView(
            context,
            data,
            filteredDocs,
            recentDocs,
          ),
          DocumentRoleScope.hr => _buildHrView(
            context,
            data,
            filteredDocs,
            recentDocs,
          ),
          DocumentRoleScope.admin => _buildAdminView(
            context,
            data,
            filteredDocs,
            recentDocs,
          ),
        },
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DocumentData data) {
    final subtitle = switch (data.scope) {
      DocumentRoleScope.employee =>
        'Keep your personal employment documents organized and up to date.',
      DocumentRoleScope.accountant =>
        'Review payroll-facing files, finance records, and expiring documents.',
      DocumentRoleScope.hr =>
        'Manage employee records, monitor expiries, and keep document health clean.',
      DocumentRoleScope.admin =>
        'Oversee the full document vault, expiry risk, and recent document activity.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _headlineFor(data.scope),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _titleFor(data.scope),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (data.canUpload)
          FilledButton.icon(
            onPressed: () => _showUploadDialog(context),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Document'),
          ),
      ],
    );
  }

  Widget _buildMetrics(DocumentData data) {
    final docs = _visibleDocuments(data);
    final expiring = data.expiringDocuments.length;
    final expired = docs.where((doc) => doc.isExpired).length;
    final active = docs.where((doc) => !doc.isExpired).length;
    final verified = docs
        .where((doc) => doc.fileUrl?.trim().isNotEmpty == true)
        .length;
    final financeDocs = docs
        .where((doc) => _isFinanceDocument(doc.type))
        .length;
    final employeeOnly = data.myDocuments
        .where((doc) => doc.visibility == DocumentVisibility.employeeOnly)
        .length;

    final cards = switch (data.scope) {
      DocumentRoleScope.employee => [
        _MetricData(
          'My Files',
          data.myDocuments.length.toString(),
          'Personal vault',
          Icons.description_outlined,
          AppColors.primary,
        ),
        _MetricData(
          'Attention',
          expiring.toString(),
          'Expiring soon',
          Icons.error_outline,
          AppColors.warning,
        ),
        _MetricData(
          'Verified',
          active.toString(),
          'Currently valid',
          Icons.verified_outlined,
          AppColors.success,
        ),
        _MetricData(
          'Private',
          employeeOnly.toString(),
          'Employee-only access',
          Icons.lock_outline,
          AppColors.info,
        ),
      ],
      DocumentRoleScope.accountant => [
        _MetricData(
          'Finance Files',
          financeDocs.toString(),
          'Payroll and finance',
          Icons.receipt_long_outlined,
          AppColors.primary,
        ),
        _MetricData(
          'Expiring',
          expiring.toString(),
          'Need follow-up',
          Icons.event_busy_outlined,
          AppColors.warning,
        ),
        _MetricData(
          'Verified',
          verified.toString(),
          'Files with reference',
          Icons.task_alt_outlined,
          AppColors.success,
        ),
        _MetricData(
          'Archive',
          expired.toString(),
          'Expired records',
          Icons.history_outlined,
          AppColors.info,
        ),
      ],
      DocumentRoleScope.hr => [
        _MetricData(
          'All Files',
          docs.length.toString(),
          'Employee records',
          Icons.folder_open_outlined,
          AppColors.primary,
        ),
        _MetricData(
          'Attention',
          expiring.toString(),
          'Within 30 days',
          Icons.notification_important_outlined,
          AppColors.warning,
        ),
        _MetricData(
          'Verified',
          verified.toString(),
          'Linked to file reference',
          Icons.verified_user_outlined,
          AppColors.success,
        ),
        _MetricData(
          'Archive',
          expired.toString(),
          'Expired or outdated',
          Icons.archive_outlined,
          AppColors.info,
        ),
      ],
      DocumentRoleScope.admin => [
        _MetricData(
          'All Files',
          docs.length.toString(),
          'Organization vault',
          Icons.inventory_2_outlined,
          AppColors.primary,
        ),
        _MetricData(
          'Attention',
          expiring.toString(),
          'Expiring soon',
          Icons.priority_high_outlined,
          AppColors.warning,
        ),
        _MetricData(
          'Verified',
          verified.toString(),
          'Reference-backed',
          Icons.verified_outlined,
          AppColors.success,
        ),
        _MetricData(
          'Archive',
          expired.toString(),
          'Historical expiry',
          Icons.watch_later_outlined,
          AppColors.info,
        ),
      ],
    };

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards
          .map(
            (card) => Container(
              width: _panelWidth(context, 280),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(card.icon, color: card.color),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    card.title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.subtitle,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionBar(BuildContext context, DocumentData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (data.canSendReminders)
            OutlinedButton.icon(
              onPressed: () => _runReminders(context),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Send Expiry Reminders'),
            ),
          SizedBox(
            width: _panelWidth(context, 320),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search files, employees, or titles',
              ),
            ),
          ),
          SizedBox(
            width: _panelWidth(context, 250),
            child: DropdownButtonFormField<EmployeeDocumentType?>(
              isExpanded: true,
              initialValue: _selectedType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list_rounded),
                hintText: 'All Document Types',
              ),
              items: [
                const DropdownMenuItem<EmployeeDocumentType?>(
                  value: null,
                  child: Text(
                    'All Document Types',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...EmployeeDocumentType.values.map(
                  (type) => DropdownMenuItem<EmployeeDocumentType?>(
                    value: type,
                    child: Text(
                      _formatType(type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedType = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeView(
    BuildContext context,
    DocumentData data,
    List<EmployeeDocument> filteredDocs,
    List<EmployeeDocument> recentDocs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _panel(
                title: 'My Documents',
                subtitle: 'Your personal file vault',
                child: filteredDocs.isEmpty
                    ? _emptyState(
                        icon: Icons.folder_copy_outlined,
                        title: 'No documents uploaded yet',
                        subtitle:
                            'When documents are shared with your profile, they will appear here.',
                      )
                    : Column(
                        children: filteredDocs
                            .map((doc) => _documentRow(context, data, doc))
                            .toList(),
                      ),
              ),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: Column(
                children: [
                  _panel(
                    title: 'Expiring Within 30 Days',
                    subtitle: 'Personal attention queue',
                    child: data.expiringDocuments.isEmpty
                        ? _emptyState(
                            icon: Icons.event_available_outlined,
                            title: 'No upcoming expiries',
                            subtitle:
                                'All your visible documents are currently valid.',
                          )
                        : Column(
                            children: data.expiringDocuments
                                .take(4)
                                .map((doc) => _compactExpiryTile(doc))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _securityPanel(
                    title: 'Military-Grade Encryption',
                    subtitle:
                        'Your documents are stored in an encrypted vault with role-based access control.',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Recent Document Activity',
          subtitle: 'Latest updates in your document history',
          child: recentDocs.isEmpty
              ? _emptyState(
                  icon: Icons.history_outlined,
                  title: 'No recent activity',
                  subtitle:
                      'New uploads and document changes will show up here.',
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: recentDocs
                      .map((doc) => _activityCard(context, data, doc))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAccountantView(
    BuildContext context,
    DocumentData data,
    List<EmployeeDocument> filteredDocs,
    List<EmployeeDocument> recentDocs,
  ) {
    final financeDocs = filteredDocs
        .where((doc) => _isFinanceDocument(doc.type))
        .toList();

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: _panelWidth(context, 760),
          child: _panel(
            title: 'Finance Document Ledger',
            subtitle: 'Payroll-facing and finance-relevant records only',
            child: financeDocs.isEmpty
                ? _emptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No finance documents available',
                    subtitle:
                        'Finance-visible files will show here when they are uploaded.',
                  )
                : Column(
                    children: financeDocs
                        .map((doc) => _documentRow(context, data, doc))
                        .toList(),
                  ),
          ),
        ),
        SizedBox(
          width: _panelWidth(context, 360),
          child: Column(
            children: [
              _panel(
                title: 'Expiring Finance Files',
                subtitle: 'Documents that may affect payroll operations',
                child: data.expiringDocuments.isEmpty
                    ? _emptyState(
                        icon: Icons.event_available_outlined,
                        title: 'No urgent finance expiries',
                        subtitle:
                            'The accessible finance archive is currently stable.',
                      )
                    : Column(
                        children: data.expiringDocuments
                            .take(5)
                            .map((doc) => _compactExpiryTile(doc))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _panel(
                title: 'Recent Activity',
                subtitle: 'Latest visible document events',
                child: recentDocs.isEmpty
                    ? _emptyState(
                        icon: Icons.timeline_outlined,
                        title: 'No recent document activity',
                        subtitle: 'Recent changes will appear here.',
                      )
                    : Column(
                        children: recentDocs
                            .take(4)
                            .map(
                              (doc) => _compactActivityTile(context, data, doc),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHrView(
    BuildContext context,
    DocumentData data,
    List<EmployeeDocument> filteredDocs,
    List<EmployeeDocument> recentDocs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _panel(
                title: 'Employee Documents',
                subtitle: 'Live employee records across the company',
                child: filteredDocs.isEmpty
                    ? _emptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'No documents found',
                        subtitle:
                            'Try adjusting the search or filter to surface employee records.',
                      )
                    : Column(
                        children: filteredDocs
                            .map((doc) => _documentRow(context, data, doc))
                            .toList(),
                      ),
              ),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: Column(
                children: [
                  _panel(
                    title: 'Expiring Within 30 Days',
                    subtitle: 'People documents needing attention',
                    child: data.expiringDocuments.isEmpty
                        ? _emptyState(
                            icon: Icons.event_available_outlined,
                            title: 'No upcoming expiries',
                            subtitle:
                                'Employee records are currently up to date.',
                          )
                        : Column(
                            children: data.expiringDocuments
                                .take(5)
                                .map((doc) => _compactExpiryTile(doc))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _securityPanel(
                    title: 'People Data Protection',
                    subtitle:
                        'HR uploads and employee records stay protected by role-based visibility and encrypted storage.',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Recent Document Activity',
          subtitle: 'Latest employee document updates and uploads',
          child: recentDocs.isEmpty
              ? _emptyState(
                  icon: Icons.history_outlined,
                  title: 'No recent activity',
                  subtitle:
                      'Uploads and changes will appear here once the vault is active.',
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: recentDocs
                      .map((doc) => _activityCard(context, data, doc))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAdminView(
    BuildContext context,
    DocumentData data,
    List<EmployeeDocument> filteredDocs,
    List<EmployeeDocument> recentDocs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _panel(
                title: 'Organization Vault',
                subtitle: 'All visible company documents in one command view',
                child: filteredDocs.isEmpty
                    ? _emptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No documents found',
                        subtitle:
                            'Adjust the filters or start uploading documents to build the vault.',
                      )
                    : Column(
                        children: filteredDocs
                            .map((doc) => _documentRow(context, data, doc))
                            .toList(),
                      ),
              ),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: Column(
                children: [
                  _panel(
                    title: 'Expiring Within 30 Days',
                    subtitle: 'Risk queue for document validity',
                    child: data.expiringDocuments.isEmpty
                        ? _emptyState(
                            icon: Icons.event_available_outlined,
                            title: 'No upcoming expiries',
                            subtitle:
                                'The organization vault is currently stable.',
                          )
                        : Column(
                            children: data.expiringDocuments
                                .take(5)
                                .map((doc) => _compactExpiryTile(doc))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _securityPanel(
                    title: 'Military-Grade Encryption',
                    subtitle:
                        'All document flows are stored in an encrypted vault with controlled administrative access.',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Recent Document Activity',
          subtitle: 'Latest uploads and system-visible document changes',
          child: recentDocs.isEmpty
              ? _emptyState(
                  icon: Icons.history_outlined,
                  title: 'No recent activity',
                  subtitle: 'New uploads and updates will show here.',
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: recentDocs
                      .map((doc) => _activityCard(context, data, doc))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _documentRow(
    BuildContext context,
    DocumentData data,
    EmployeeDocument doc,
  ) {
    final expiry = doc.expiryDate == null
        ? 'No expiry'
        : DateFormat('dd MMM yyyy').format(doc.expiryDate!);
    final upload = DateFormat('dd MMM yyyy').format(doc.uploadedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatType(doc.type)}${data.scope == DocumentRoleScope.employee ? '' : ' • ${doc.employeeName}'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(doc),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill('Uploaded', upload),
              _metaPill('Expiry', expiry, tone: _expiryColor(doc)),
              _metaPill('Visibility', _formatVisibility(doc.visibility)),
              if (doc.isSystemGenerated)
                _metaPill('Source', 'System', tone: AppColors.info),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _download(context, doc),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
              if (data.canManage)
                OutlinedButton.icon(
                  onPressed: () => _deleteDocument(context, doc),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactExpiryTile(EmployeeDocument doc) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: _expiryColor(doc)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.employeeName} • ${doc.expiryDate == null ? 'No expiry' : DateFormat('dd MMM yyyy').format(doc.expiryDate!)}',
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
    );
  }

  Widget _activityCard(
    BuildContext context,
    DocumentData data,
    EmployeeDocument doc,
  ) {
    return Container(
      width: _panelWidth(context, 260),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            doc.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            data.scope == DocumentRoleScope.employee
                ? _formatType(doc.type)
                : doc.employeeName,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('dd MMM yyyy').format(doc.uploadedAt),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactActivityTile(
    BuildContext context,
    DocumentData data,
    EmployeeDocument doc,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_toggle_off_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.scope == DocumentRoleScope.employee ? _formatType(doc.type) : doc.employeeName} • ${DateFormat('dd MMM yyyy').format(doc.uploadedAt)}',
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
    );
  }

  Widget _securityPanel({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E4B71), Color(0xFF425E84)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 220,
      child: ModernEmptyState(icon: icon, title: title, subtitle: subtitle),
    );
  }

  Widget _statusPill(EmployeeDocument doc) {
    final color = _expiryColor(doc);
    final text = doc.isExpired
        ? 'Expired'
        : doc.expiryDate == null
        ? 'No Expiry'
        : doc.expiryDate!.difference(DateTime.now()).inDays <= 30
        ? 'Attention'
        : 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaPill(String label, String value, {Color? tone}) {
    final color = tone ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<EmployeeDocument> _visibleDocuments(DocumentData data) {
    return data.canViewOrganization
        ? data.organizationDocuments
        : data.myDocuments;
  }

  List<EmployeeDocument> _filterDocuments(List<EmployeeDocument> docs) {
    final query = _searchController.text.trim().toLowerCase();
    return docs.where((doc) {
      final matchesType = _selectedType == null || doc.type == _selectedType;
      if (!matchesType) return false;
      if (query.isEmpty) return true;
      final haystack =
          '${doc.title} ${doc.employeeName} ${doc.fileName ?? ''} ${doc.type.name}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _headlineFor(DocumentRoleScope scope) {
    return switch (scope) {
      DocumentRoleScope.employee => 'Personal Vault',
      DocumentRoleScope.accountant => 'Finance Archive',
      DocumentRoleScope.hr => 'People Records',
      DocumentRoleScope.admin => 'Organization Control',
    };
  }

  String _titleFor(DocumentRoleScope scope) {
    return switch (scope) {
      DocumentRoleScope.employee => 'My Documents',
      DocumentRoleScope.accountant => 'Finance Documents',
      DocumentRoleScope.hr => 'Document Management',
      DocumentRoleScope.admin => 'Document Command',
    };
  }

  bool _isFinanceDocument(EmployeeDocumentType type) {
    return switch (type) {
      EmployeeDocumentType.bankDetails ||
      EmployeeDocumentType.taxForm ||
      EmployeeDocumentType.pensionForm ||
      EmployeeDocumentType.payslip ||
      EmployeeDocumentType.payrollReport ||
      EmployeeDocumentType.bonusLetter ||
      EmployeeDocumentType.salaryAdjustmentLetter => true,
      _ => false,
    };
  }

  String _formatType(EmployeeDocumentType type) {
    return type.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split('_')
        .join(' ')
        .trim()
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _formatVisibility(DocumentVisibility visibility) {
    return switch (visibility) {
      DocumentVisibility.public => 'Public',
      DocumentVisibility.employeeOnly => 'Employee',
      DocumentVisibility.hrOnly => 'HR',
      DocumentVisibility.accountantOnly => 'Accountant',
      DocumentVisibility.adminOnly => 'Admin',
    };
  }

  Color _expiryColor(EmployeeDocument doc) {
    if (doc.isExpired) return AppColors.error;
    if (doc.expiryDate == null) return AppColors.textSecondary;
    if (doc.expiryDate!.difference(DateTime.now()).inDays <= 30) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  double _panelWidth(BuildContext context, double maxWidth) {
    final available = MediaQuery.of(context).size.width - 56;
    if (available < maxWidth) return available;
    return maxWidth;
  }

  Future<void> _showUploadDialog(BuildContext context) async {
    final data = ref.read(documentDataProvider).value;
    final user = data?.user;
    if (data == null || user == null || !data.canUpload) {
      NotificationHelper.showError(
        context,
        'You do not have permission to upload documents.',
      );
      return;
    }

    final targets = data.uploadTargets;
    if (targets.isEmpty) {
      NotificationHelper.showError(
        context,
        'No employee records were found for document upload.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final fileUrlController = TextEditingController();
    final fileNameController = TextEditingController();
    final visibilityOptions = switch (data.scope) {
      DocumentRoleScope.admin => DocumentVisibility.values,
      DocumentRoleScope.hr => const [
        DocumentVisibility.public,
        DocumentVisibility.employeeOnly,
        DocumentVisibility.hrOnly,
      ],
      _ => const [DocumentVisibility.public],
    };
    var selectedEmployee = targets.firstWhere(
      (employee) => employee.id == (user.employeeId ?? ''),
      orElse: () => targets.first,
    );
    var type = EmployeeDocumentType.other;
    var visibility = visibilityOptions.first;
    DateTime? issuedDate;
    DateTime? expiryDate;

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Upload Document'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<Employee>(
                          initialValue: selectedEmployee,
                          decoration: const InputDecoration(
                            labelText: 'Employee',
                          ),
                          items: targets
                              .map(
                                (employee) => DropdownMenuItem<Employee>(
                                  value: employee,
                                  child: Text(employee.fullName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedEmployee = value);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Document Title',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<EmployeeDocumentType>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Document Type',
                          ),
                          items: EmployeeDocumentType.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_formatType(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => type = value ?? EmployeeDocumentType.other,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<DocumentVisibility>(
                          initialValue: visibility,
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                          ),
                          items: visibilityOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_formatVisibility(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => visibility =
                                  value ?? DocumentVisibility.public,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: fileNameController,
                          decoration: const InputDecoration(
                            labelText: 'File Name (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: fileUrlController,
                          decoration: const InputDecoration(
                            labelText: 'File URL / Reference (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Issued Date (optional)'),
                          subtitle: Text(
                            issuedDate == null
                                ? 'Not set'
                                : DateFormat('dd MMM yyyy').format(issuedDate!),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: issuedDate ?? DateTime.now(),
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => issuedDate = picked);
                              }
                            },
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Expiry Date (optional)'),
                          subtitle: Text(
                            expiryDate == null
                                ? 'Not set'
                                : DateFormat('dd MMM yyyy').format(expiryDate!),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.event),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: expiryDate ?? DateTime.now(),
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null) {
                                setState(() => expiryDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submit != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Uploading document...');
    try {
      await ref
          .read(documentActionsProvider)
          .upload(
            employeeId: selectedEmployee.id,
            employeeName: selectedEmployee.fullName,
            title: titleController.text.trim(),
            type: type,
            uploadedBy: user.id,
            uploadedByName: user.name,
            fileUrl: fileUrlController.text.trim(),
            fileName: fileNameController.text.trim(),
            issuedDate: issuedDate,
            expiryDate: expiryDate,
            visibility: visibility,
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Document uploaded');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Upload failed: $e');
    }
  }

  Future<void> _runReminders(BuildContext context) async {
    NotificationHelper.showLoading(context, message: 'Sending reminders...');
    try {
      final count = await ref
          .read(documentActionsProvider)
          .sendReminders(withinDays: 30);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Sent reminders for $count document(s).',
      );
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Reminder run failed: $e');
    }
  }

  Future<void> _download(BuildContext context, EmployeeDocument doc) async {
    if (doc.fileUrl == null || doc.fileUrl!.isEmpty) {
      NotificationHelper.showError(context, 'No file to download');
      return;
    }
    final uri = Uri.tryParse(doc.fileUrl!);
    if (uri == null) {
      NotificationHelper.showError(context, 'Invalid file URL');
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      NotificationHelper.showError(context, 'Could not open document link.');
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    EmployeeDocument doc,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}" for ${doc.employeeName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Deleting...');
    try {
      await ref.read(documentActionsProvider).deleteDocument(doc.id);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Document deleted');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Delete failed: $e');
    }
  }
}

class _MetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricData(
    this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.color,
  );
}
