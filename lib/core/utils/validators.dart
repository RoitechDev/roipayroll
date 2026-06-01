import 'package:email_validator/email_validator.dart';

/// Validation functions for form inputs
/// Returns null if valid, returns error message if invalid
class Validators {
  // Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    if (!EmailValidator.validate(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null; // Valid
  }
  
  // Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null; // Valid
  }
  
  // Confirm Password Validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null; // Valid
  }
  
  // Name Validation (First Name, Last Name, Full Name)
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    // Only letters and spaces allowed
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return '$fieldName can only contain letters';
    }
    
    return null; // Valid
  }
  
  // Phone Number Validation (Nigerian format)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove all non-digit characters
    String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    // Check if it's 11 digits (Nigerian format: 080XXXXXXXX)
    if (digitsOnly.length == 11) {
      // Must start with 0
      if (!digitsOnly.startsWith('0')) {
        return 'Phone number must start with 0';
      }
      return null; // Valid
    }
    
    // Check if it's 13 digits with country code (234080XXXXXXXX)
    if (digitsOnly.length == 13) {
      if (!digitsOnly.startsWith('234')) {
        return 'Country code must be 234 for Nigeria';
      }
      return null; // Valid
    }
    
    // Check if it's 10 digits without leading 0 (80XXXXXXXX)
    if (digitsOnly.length == 10) {
      return null; // Valid (we can add 0 programmatically)
    }
    
    return 'Please enter a valid Nigerian phone number';
  }
  
  // Required Field Validation (Generic)
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null; // Valid
  }
  
  // Salary/Amount Validation
  static String? validateAmount(String? value, {String fieldName = 'Amount'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    // Remove commas if present
    String cleanValue = value.replaceAll(',', '');
    
    // Check if it's a valid number
    final amount = double.tryParse(cleanValue);
    
    if (amount == null) {
      return 'Please enter a valid $fieldName';
    }
    
    if (amount <= 0) {
      return '$fieldName must be greater than zero';
    }
    
    return null; // Valid
  }
  
  // Employee ID Validation
  static String? validateEmployeeId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Employee ID is required';
    }
    
    if (value.trim().length < 3) {
      return 'Employee ID must be at least 3 characters';
    }
    
    return null; // Valid
  }
  
  // Department Validation
  static String? validateDepartment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select a department';
    }
    return null; // Valid
  }
  
  // Date Validation
  static String? validateDate(DateTime? value, {String fieldName = 'Date'}) {
    if (value == null) {
      return 'Please select a $fieldName';
    }
    return null; // Valid
  }
  
  // Date Range Validation (e.g., hire date can't be in the future)
  static String? validatePastDate(DateTime? value, {String fieldName = 'Date'}) {
    if (value == null) {
      return 'Please select a $fieldName';
    }
    
    if (value.isAfter(DateTime.now())) {
      return '$fieldName cannot be in the future';
    }
    
    return null; // Valid
  }
  
  // Percentage Validation (0-100)
  static String? validatePercentage(String? value, {String fieldName = 'Percentage'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final percentage = double.tryParse(value);
    
    if (percentage == null) {
      return 'Please enter a valid $fieldName';
    }
    
    if (percentage < 0 || percentage > 100) {
      return '$fieldName must be between 0 and 100';
    }
    
    return null; // Valid
  }
  
  // Account Number Validation (Nigerian - 10 digits)
  static String? validateAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account number is required';
    }
    
    String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 10) {
      return 'Account number must be 10 digits';
    }
    
    return null; // Valid
  }
  
  // Bank Name Validation
  static String? validateBankName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select a bank';
    }
    return null; // Valid
  }
  
  // Tax ID Validation (TIN - Tax Identification Number)
  static String? validateTaxId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tax ID is required';
    }
    
    // Basic validation - can be enhanced based on actual TIN format
    if (value.trim().length < 8) {
      return 'Invalid Tax ID format';
    }
    
    return null; // Valid
  }
  
  // Pension ID Validation (RSA PIN)
  static String? validatePensionId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pension ID (RSA PIN) is required';
    }
    
    // RSA PIN format validation - usually alphanumeric
    if (value.trim().length < 10) {
      return 'Invalid Pension ID format';
    }
    
    return null; // Valid
  }
}
