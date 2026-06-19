import 'package:flutter/material.dart';

/// Centralized palette extracted from Figma POC-Dev file.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF092C1B); // deep forest green (CTAs)
  static const Color accent = Color(0xFF6739FF); // purple highlight
  static const Color accentSoft = Color(0xFF9374FD);

  // Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF4F6F9);
  static const Color inputFill = Color(0xFFF3F3F4);
  static const Color divider = Color(0xFFE9E7E7);
  static const Color border = Color(0xFFCBD5E1);

  // Text
  static const Color textPrimary = Color(0xFF111214);
  static const Color textHeading = Color(0xFF221E1E);
  static const Color textTitle = Color(0xFF282828);
  static const Color textBody = Color(0xFF393C43);
  static const Color textMuted = Color(0xFF676C75);
  static const Color textSubtle = Color(0xFF797979);
  static const Color textHint = Color(0xFFABABAB);
  static const Color textNeutral = Color(0xFF4B5563);

  // Status
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF34A853);
  static const Color info = Color(0xFF1E88E5);
}
