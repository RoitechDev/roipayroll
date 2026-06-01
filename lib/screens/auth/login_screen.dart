import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/validators.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/screens/auth/widgets/auth_page_shell.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/employee_invitation_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  final _employeeService = EmployeeService();
  final _invitationService = EmployeeInvitationService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result?.user == null) {
        throw 'Login failed';
      }

      final userProfile = await _userService.getCurrentUserProfile();
      if (userProfile == null) {
        throw 'User profile not found. Please contact admin.';
      }

      if (!userProfile.isActive) {
        await _authService.logout();
        throw 'Your account has been deactivated. Please contact admin.';
      }

      await _updateLoginTracking(userProfile);

      if (userProfile.requirePasswordChange) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.changePassword,
          arguments: const {'isFirstLogin': true},
        );
        return;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateLoginTracking(AppUser userProfile) async {
    await _userService.upsertUserProfileData(
      uid: userProfile.id,
      companyId: userProfile.companyId,
      data: {'lastLoginAt': Timestamp.now()},
    );

    final employeeId = userProfile.employeeId?.toString();
    if (employeeId == null || employeeId.isEmpty) return;

    final employee = await _employeeService.getEmployeeById(employeeId);
    final currentStatus = employee?.invitationStatus ?? InvitationStatus.active;

    await _invitationService.markEmployeeActiveOnLogin(
      companyId: userProfile.companyId,
      employeeId: employeeId,
      currentStatus: currentStatus,
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email address and we will send you a link to reset your password.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(dialogContext);
                      setState(() => isSending = true);
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: emailController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password reset email sent. Check your inbox.',
                            ),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSending = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              e.code == 'user-not-found'
                                  ? 'No account found with this email.'
                                  : 'Failed to send reset email. Please try again.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSending = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Reset Email'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      header: const AuthBrandHeader(
        title: 'Roipayroll',
        subtitle: 'The Secure Monolith for Modern Finance',
      ),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF08152B),
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please enter your credentials to access your payroll portal.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const AuthFieldLabel(label: 'EMAIL ADDRESS'),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _emailController,
              hintText: 'name@company.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 24),
            AuthFieldLabel(
              label: 'PASSWORD',
              trailing: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF111C2E),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordController,
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              suffixIcon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              onSuffixPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              validator: Validators.validatePassword,
            ),
            const SizedBox(height: 32),
            const AuthNoticeBanner(
              icon: Icons.shield_outlined,
              text: 'This connection is encrypted with 256-bit SSL security.',
            ),
            const SizedBox(height: 30),
            AuthPrimaryButton(
              label: 'Login',
              isLoading: _isLoading,
              onPressed: _handleLogin,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: Text(
                    'New to Roipayroll?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.register);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0C1525),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: Column(
        children: const [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Text(
                'PRIVACY POLICY',
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 1.8,
                  color: Color(0xFF7D8795),
                ),
              ),
              Text(
                '•',
                style: TextStyle(fontSize: 13, color: Color(0xFFB1B8C2)),
              ),
              Text(
                'SECURITY SHIELD',
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 1.8,
                  color: Color(0xFF7D8795),
                ),
              ),
              Text(
                '•',
                style: TextStyle(fontSize: 13, color: Color(0xFFB1B8C2)),
              ),
              Text(
                'TERMS OF SERVICE',
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 1.8,
                  color: Color(0xFF7D8795),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            '© 2024 Roipayroll Inc. Securely encrypted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF98A1AF)),
          ),
        ],
      ),
    );
  }
}
