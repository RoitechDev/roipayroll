import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/validators.dart';
import 'package:roipayroll/screens/auth/widgets/auth_page_shell.dart';
import 'package:roipayroll/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.registerCompanyAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        companyName: _companyNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A verification email has been sent to your inbox. Please verify your email address.',
            ),
            duration: Duration(seconds: 6),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      maxCardWidth: 640,
      header: const AuthBrandHeader(title: 'Roipayroll', compact: true),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Company Account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF08152B),
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Join thousands of enterprises securing their payroll with Roipayroll.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 34),
            const AuthFieldLabel(label: 'COMPANY NAME'),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _companyNameController,
              hintText: 'Acme Corporation',
              prefixIcon: Icons.business_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter company name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const AuthFieldLabel(label: 'EMAIL ADDRESS'),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _emailController,
              hintText: 'admin@company.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 520;
                final passwordField = _RegisterPasswordField(
                  label: 'PASSWORD',
                  controller: _passwordController,
                  hintText: 'Create password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onSuffixPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: Validators.validatePassword,
                );
                final confirmPasswordField = _RegisterPasswordField(
                  label: 'CONFIRM PASSWORD',
                  controller: _confirmPasswordController,
                  hintText: 'Confirm password',
                  prefixIcon: Icons.verified_user_outlined,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onSuffixPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      passwordField,
                      const SizedBox(height: 20),
                      confirmPasswordField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: passwordField),
                    const SizedBox(width: 18),
                    Expanded(child: confirmPasswordField),
                  ],
                );
              },
            ),
            const SizedBox(height: 34),
            AuthPrimaryButton(
              label: 'Create Company',
              isLoading: _isLoading,
              onPressed: _handleRegister,
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(
                  child: Text(
                    'Already have an account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0C1525),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
            const SizedBox(height: 34),
            const Divider(color: Color(0xFFD8E0EA), height: 1),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: const [
                AuthSecurityPill(
                  icon: Icons.shield_outlined,
                  label: 'AES-256 ENCRYPTED',
                ),
                AuthSecurityPill(
                  icon: Icons.verified_user_outlined,
                  label: 'GDPR COMPLIANT',
                ),
              ],
            ),
          ],
        ),
      ),
      footer: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          final copyright = const Text(
            '© 2024 Roipayroll Inc. All rights reserved. Securely encrypted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF55657C)),
          );

          final links = Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 10,
            children: const [
              Text(
                'Help',
                style: TextStyle(fontSize: 13, color: Color(0xFF55657C)),
              ),
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 13, color: Color(0xFF55657C)),
              ),
              Text(
                'Security Shield',
                style: TextStyle(fontSize: 13, color: Color(0xFF55657C)),
              ),
            ],
          );

          return Column(
            children: [
              const Divider(color: Color(0xFFD5DDE8), height: 1),
              const SizedBox(height: 22),
              if (stacked) ...[
                copyright,
                const SizedBox(height: 16),
                links,
              ] else
                Row(
                  children: [
                    Expanded(child: copyright),
                    const SizedBox(width: 24),
                    Flexible(child: links),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RegisterPasswordField extends StatelessWidget {
  const _RegisterPasswordField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.obscureText,
    required this.suffixIcon,
    required this.onSuffixPressed,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData suffixIcon;
  final VoidCallback onSuffixPressed;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFieldLabel(label: label),
        const SizedBox(height: 12),
        AuthTextField(
          controller: controller,
          hintText: hintText,
          prefixIcon: prefixIcon,
          obscureText: obscureText,
          suffixIcon: suffixIcon,
          onSuffixPressed: onSuffixPressed,
          validator: validator,
        ),
      ],
    );
  }
}
