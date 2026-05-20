import 'package:flutter/material.dart';

/// Single source of truth for all theme colors used across the Ciro app.
class CiroTheme {
  CiroTheme._();

  // ── Primary brand color ─────────────────────────────────────────────
  /// The user's chosen base brand color.
  static const Color primaryBase = Color(0xFF79CFFF);

  /// Darkened variant for high-contrast text / active icons on white.
  static const Color primary = Color(0xFF1A8FD4);

  /// Even darker for maximum contrast on pure white backgrounds.
  static const Color primaryDark = Color(0xFF0D6EAF);

  // ── Neutral surface palette ─────────────────────────────────────────
  static const Color scaffoldBackground = Color(0xFFF4F6F9);
  static const Color cardBackground = Colors.white;
  static const Color navBarBackground = Colors.white;

  // ── Text colors ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF6B7280);

  // ── Accent / semantic ───────────────────────────────────────────────
  static const Color crisisRed = Color(0xFFEF4444);
  static const Color crisisBg = Color(0xFFFEF2F2);
}
