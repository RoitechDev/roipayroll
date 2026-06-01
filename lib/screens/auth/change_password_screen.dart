import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/services/employee_invitation_service.dart';
import 'package:roipayroll/services/user_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;

  const ChangePasswordScreen({super.key, this.isFirstLogin = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _userService = UserService();
  final _invitationService = EmployeeInvitationService();

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFirstLogin ? 'Set Your Password' : 'Change Password',
        ),
        automaticallyImplyLeading: !widget.isFirstLogin,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isFirstLogin) ...[
                    const Icon(Icons.security, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome. Please set a secure password before proceeding.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: widget.isFirstLogin
                          ? 'Temporary Password'
                          : 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock),
                      helperText: 'At least 8 characters',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 8) {
                        return 'Must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handlePasswordChange,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isFirstLogin
                                  ? 'Set Password'
                                  : 'Change Password',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePasswordChange() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw 'Not authenticated';
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      final userProfile = await _userService.getCurrentUserProfile();
      if (userProfile != null) {
        await _userService.upsertUserProfileData(
          uid: userProfile.id,
          companyId: userProfile.companyId,
          data: {
            'requirePasswordChange': false,
            'mustChangePassword': false,
            'passwordChangedAt': Timestamp.now(),
          },
        );

        if (userProfile.employeeId != null &&
            userProfile.employeeId!.isNotEmpty) {
          await _invitationService.markPasswordChanged(
            companyId: userProfile.companyId,
            employeeId: userProfile.employeeId!,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } on FirebaseAuthException catch (e) {
      String message = 'Password change failed';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
