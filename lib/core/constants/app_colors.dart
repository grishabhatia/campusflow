import 'package:flutter/material.dart';

class AppColors {
  static const primary     = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF1E88E5);
  static const primaryDark  = Color(0xFF0D47A1);
  static const secondary   = Color(0xFF00897B);
  static const background  = Color(0xFFF5F7FA);
  static const surface     = Colors.white;
  static const pending     = Color(0xFFFFA726);
  static const approved    = Color(0xFF66BB6A);
  static const rejected    = Color(0xFFEF5350);
  static const textPrimary   = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const border      = Color(0xFFE0E0E0);
  static const cardShadow  = Color(0x0A000000);

  static Color statusColor(String status) {
    switch (status) {
      case 'approved': return approved;
      case 'rejected': return rejected;
      default:         return pending;
    }
  }
}