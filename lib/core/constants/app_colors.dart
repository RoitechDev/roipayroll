import 'package:flutter/material.dart';

/// Modern Color System for Roipayroll
/// Based on professional payroll/finance applications
class AppColors {
  // ==================== PRIMARY COLORS ====================

  /// Main brand color
  static const Color primary = Color(0xFF25343F);
  static const Color primaryLight = Color(0xFF3A4D5A);
  static const Color primaryDark = Color(0xFF1A262E);

  /// Secondary brand color
  static const Color secondary = Color(0xFFBFC9D1);
  static const Color secondaryLight = Color(0xFFD4DCE2);
  static const Color secondaryDark = Color(0xFFA8B5BF);

  /// Accent color
  static const Color accent = Color(0xFFFF9B51);
  static const Color accentLight = Color(0xFFFFB980);
  static const Color accentDark = Color(0xFFE98238);

  // ==================== BACKGROUND COLORS ====================

  static const Color background = Color(0xFFEAEFEF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F8F8);

  // ==================== TEXT COLORS ====================

  static const Color textPrimary = Color(0xFF25343F);
  static const Color textSecondary = Color(0xFF5E6E7A);
  static const Color textTertiary = Color(0xFF83919C);
  static const Color textDisabled = Color(0xFFAAB6BF);

  // ==================== STATUS COLORS ====================

  /// Success states
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE3F3E4);
  static const Color successDark = Color(0xFF215A25);

  /// Error states - Red
  static const Color error = Color(0xFFB85C5C);
  static const Color errorLight = Color(0xFFF2D4D4);
  static const Color errorDark = Color(0xFF7D3B3B);

  /// Warning states - Amber
  static const Color warning = Color(0xFFFF9B51);
  static const Color warningLight = Color(0xFFFFE7D6);
  static const Color warningDark = Color(0xFFE98238);

  /// Info states - Blue
  static const Color info = Color(0xFF4F6473);
  static const Color infoLight = Color(0xFFE2E9EE);
  static const Color infoDark = Color(0xFF374753);

  // ==================== BORDER & DIVIDER ====================

  static const Color border = Color(0xFFD7E0E5);
  static const Color borderDark = Color(0xFFBECBD3);
  static const Color divider = Color(0xFFE3EAEE);

  // ==================== FUNCTIONAL COLORS ====================

  /// Salary & Money - Green gradient
  static const Color salary = Color(0xFF2E7D32);
  static const Color deduction = Color(0xFFEF4444);
  static const Color bonus = Color(0xFFF59E0B);

  /// Status badges
  static const Color active = Color(0xFF2E7D32);
  static const Color inactive = Color(0xFF6B7280);
  static const Color pending = Color(0xFFFF9B51);
  static const Color approved = Color(0xFF2E7D32);
  static const Color rejected = Color(0xFFEF4444);

  // ==================== SHADOW & OVERLAY ====================

  static const Color shadow = Color(0x1A000000);
  static const Color overlay = Color(0x40000000);
  static const Color scrim = Color(0x99000000);

  // ==================== GRADIENTS ====================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF25343F), Color(0xFF3A4D5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF215A25)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9B51), Color(0xFFE98238)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== HELPER METHODS ====================

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get status color based on string status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
        return success;
      case 'pending':
        return warning;
      case 'rejected':
      case 'cancelled':
        return error;
      case 'inactive':
        return inactive;
      default:
        return textSecondary;
    }
  }
}
