import 'package:flutter/material.dart';

/// Helpi Profissional — Design System Color Tokens
class AppColors {
  AppColors._();

  // ─── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // ─── Online / Active ──────────────────────────────────────────────────────
  static const Color online = Color(0xFF10B981);
  static const Color onlineGlow = Color(0x4010B981);
  static const Color onlineLight = Color(0xFF34D399);

  // ─── Offline ──────────────────────────────────────────────────────────────
  static const Color offline = Color(0xFF566880);

  // ─── Feedback ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successGlow = Color(0x3010B981);
  static const Color error = Color(0xFFEF4444);
  static const Color errorGlow = Color(0x30EF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // ─── Dark Surfaces ────────────────────────────────────────────────────────
  static const Color bg0 = Color(0xFF060C15);
  static const Color bg1 = Color(0xFF0B1120);
  static const Color bg2 = Color(0xFF111827);
  static const Color bg3 = Color(0xFF1A2337);
  static const Color bg4 = Color(0xFF243047);
  static const Color bg5 = Color(0xFF2E3E5A);

  // ─── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3B3CC);
  static const Color textTertiary = Color(0xFF566880);
  static const Color textDisabled = Color(0xFF3A4F66);
  static const Color white = Color(0xFFFFFFFF);

  // ─── Borders ─────────────────────────────────────────────────────────────
  static const Color border = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  // ─── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
  );

  static const LinearGradient onlineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF060C15), Color(0xFF0B1120)],
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get primaryGlowShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.4),
      blurRadius: 24,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get onlineGlowShadow => [
    BoxShadow(
      color: online.withValues(alpha: 0.5),
      blurRadius: 32,
      spreadRadius: 4,
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}
