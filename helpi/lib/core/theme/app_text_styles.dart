import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Helpi Design System — Typography Tokens
class AppTextStyles {
  AppTextStyles._();

  // ─── Display ──────────────────────────────────────────────────────────────
  static TextStyle get displayXL => GoogleFonts.inter(
    fontSize: 48, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -2.0, height: 1.1,
  );

  static TextStyle get displayL => GoogleFonts.inter(
    fontSize: 36, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -1.2, height: 1.15,
  );

  static TextStyle get displayM => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.8, height: 1.2,
  );

  // ─── Headings ─────────────────────────────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.4, height: 1.25,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.3,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.35,
  );

  static TextStyle get h4 => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.4,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static TextStyle get bodyL => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.6,
  );

  static TextStyle get bodyM => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.6,
  );

  static TextStyle get bodyS => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textTertiary, height: 1.5,
  );

  // ─── Labels ───────────────────────────────────────────────────────────────
  static TextStyle get labelL => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: 0.3,
  );

  static TextStyle get labelM => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, letterSpacing: 0.5,
  );

  static TextStyle get labelS => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textTertiary, letterSpacing: 0.8,
  );

  static TextStyle get labelXS => GoogleFonts.inter(
    fontSize: 10, fontWeight: FontWeight.w600,
    color: AppColors.textTertiary, letterSpacing: 1.2,
  );

  // ─── Special ──────────────────────────────────────────────────────────────
  static TextStyle get brand => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w900,
    color: AppColors.textPrimary, letterSpacing: 2.0,
  );

  static TextStyle get monospace => const TextStyle(
    fontFamily: 'monospace',
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get etaValue => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );

  static TextStyle get priceDisplay => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
}
