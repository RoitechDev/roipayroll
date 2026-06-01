import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/probation_record_model.dart';
import 'package:roipayroll/services/probation_service.dart';
import 'package:roipayroll/services/user_service.dart';

class ProbationReviewScreen extends StatefulWidget {
  final String? probationId;

  const ProbationReviewScreen({super.key, this.probationId});

  @override
  State<ProbationReviewScreen> createState() => _ProbationReviewScreenState();
}

class _ProbationReviewScreenState extends State<ProbationReviewScreen> {
  final _probationService = ProbationService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  final _reviewNotesController = TextEditingController();
  final _extensionReasonController = TextEditingController();
  final _remarksController = TextEditingController();

  List<ProbationRecord> _probations = [];
  ProbationRecord? _selectedProbation;
  double _performanceRating = 3.0;
  int _extensionMonths = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProbations();
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    _extensionReasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadProbations() async {
    setState(() => _isLoading = true);

    try {
      final probations = await _probationService.getAllProbationRecords(
        status: ProbationStatus.active,
      );

      setState(() {
        _probations = probations;
        if (widget.probationId != null) {
          _selectedProbation = probations.firstWhere(
            (p) => p.id == widget.probationId,
            orElse: () => probations.first,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate() || _selectedProbation == null) {
      return;
    }

    NotificationHelper.showLoading(context, message: 'Submitting review...');

    try {
      final user = await _userService.getCurrentUserProfile();

      await _probationService.submitReview(
        probationId: _selectedProbation!.id,
        reviewedBy: user!.name,
        reviewNotes: _reviewNotesController.text,
        performanceRating: _performanceRating,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(
          context,
          'Review submitted successfully',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  Future<void> _confirmProbation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Probation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirm ${_selectedProbation!.employeeName} as permanent employee?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                labelText: 'Remarks (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    NotificationHelper.showLoading(context, message: 'Confirming...');

    try {
      final user = await _userService.getCurrentUserProfile();

      await _probationService.confirmProbation(
        probationId: _selectedProbation!.id,
        confirmedBy: user!.name,
        confirmationNotes: _remarksController.text.isEmpty
            ? null
            : _remarksController.text,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(context, 'Probation confirmed!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  Future<void> _extendProbation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extend Probation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _extensionMonths,
              decoration: const InputDecoration(
                labelText: 'Extension Duration',
                border: OutlineInputBorder(),
              ),
              items: [1, 2, 3, 6].map((months) {
                return DropdownMenuItem(
                  value: months,
                  child: Text('$months month${months > 1 ? 's' : ''}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _extensionMonths = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _extensionReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Extend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    NotificationHelper.showLoading(context, message: 'Extending...');

    try {
      final user = await _userService.getCurrentUserProfile();

      await _probationService.extendProbation(
        probationId: _selectedProbation!.id,
        additionalMonths: _extensionMonths,
        extendedBy: user!.name,
        extensionReason: _extensionReasonController.text,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(context, 'Probation extended');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Probation')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _probations.isEmpty
          ? const Center(child: Text('No active probations'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildEmployeeSelector(),
                  const SizedBox(height: 24),
                  if (_selectedProbation != null) ...[
                    _buildProbationInfo(),
                    const SizedBox(height: 24),
                    _buildReviewForm(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmployeeSelector() {
    return DropdownButtonFormField<ProbationRecord>(
      initialValue: _selectedProbation,
      decoration: const InputDecoration(
        labelText: 'Select Employee',
        border: OutlineInputBorder(),
      ),
      items: _probations.map((probation) {
        return DropdownMenuItem(
          value: probation,
          child: Text(probation.employeeName),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedProbation = value),
    );
  }

  Widget _buildProbationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedProbation!.employeeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Start Date',
              _formatDate(_selectedProbation!.startDate),
            ),
            _buildInfoRow('End Date', _formatDate(_selectedProbation!.endDate)),
            _buildInfoRow(
              'Duration',
              '${_selectedProbation!.durationMonths} months',
            ),
            _buildInfoRow(
              'Days Remaining',
              '${_selectedProbation!.daysRemaining} days',
            ),
            _buildInfoRow(
              'Status',
              _selectedProbation!.status.name.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReviewForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Review',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Rating: ${_performanceRating.toStringAsFixed(1)}/5.0'),
            Slider(
              value: _performanceRating,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              label: _performanceRating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _performanceRating = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reviewNotesController,
              decoration: const InputDecoration(
                labelText: 'Review Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter review notes' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        const Text(
          'Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _extendProbation,
                icon: const Icon(Icons.schedule),
                label: const Text('Extend'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _confirmProbation,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
