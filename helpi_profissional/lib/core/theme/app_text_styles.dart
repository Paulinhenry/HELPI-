import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.4,
  );
  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static TextStyle get h4 => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
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
    color: AppColors.textTertiary,
  );
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
  static TextStyle get etaValue => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static TextStyle get priceDisplay => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
}
