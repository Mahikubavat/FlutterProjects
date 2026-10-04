import 'package:flutter/material.dart';

import '../models/comparison_result.dart';

/// Modern academic design tokens inspired by premium productivity & integrity dashboards.
/// Deep forest emerald palette with mint accents and crisp card layouts.
class AppColors {
  AppColors._();

  // Core Brand & Neutral Palette (Design 1 - Forest Emerald & Mint)
  static const ink = Color(0xFF0F261E); // Deep Forest Charcoal
  static const inkLight = Color(0xFF193D30); // Forest Medium
  static const brand = Color(0xFF0E382B); // Deep Forest Emerald (Primary)
  static const brandLight = Color(0xFF1E5643); // Emerald Mid
  static const mint = Color(0xFF2DD4BF); // Vibrant Mint Highlight
  static const mintLight = Color(0xFFD1FAE5); // Pastel Mint
  static const paper = Color(0xFFF7FAF8); // Crisp Sage White Canvas
  static const card = Color(0xFFFFFFFF); // Pure White Surface
  static const line = Color(0xFFE3EAE5); // Soft Natural Divider
  static const muted = Color(0xFF62736B); // Balanced Sage Slate
  static const text = Color(0xFF0F261E); // Deep Readable Text

  // Hero Card Dark Gradient
  static const heroGradientStart = Color(0xFF09281E);
  static const heroGradientEnd = Color(0xFF154434);

  // Semantic Risk Palette
  static const high = Color(0xFFE11D48); // Rose / Red 600
  static const review = Color(0xFFD97706); // Amber 600
  static const low = Color(0xFF10B981); // Emerald 500

  // Dual-Layer AI Palette
  static const aiEdited = Color(0xFF0284C7); // Sky Blue 600
  static const aiEditedBg = Color(0xFFE0F2FE); // Sky Blue 100
  static const aiGenerated = Color(0xFFE11D48); // Rose Red 600
  static const aiGeneratedBg = Color(0xFFFFE4E6); // Rose Red 100
  static const aiHybrid = Color(0xFFD97706); // Amber 600

  // Highlight for matched passages
  static const match = Color(0xFFFEF08A); // Yellow 200
  static const matchBorder = Color(0xFFFACC15); // Yellow 400
}

/// Severity classification of a similarity result with plain-English labeling.
class Risk {
  final Color color;
  final String label;

  const Risk(this.color, this.label);

  static Risk of(ComparisonResult r) {
    if (r.isHighRisk) return const Risk(AppColors.high, 'High similarity');
    if (r.isFlagged) return const Risk(AppColors.review, 'Needs review');
    return const Risk(AppColors.low, 'Low similarity');
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.mint,
      onSecondary: AppColors.ink,
      surface: AppColors.card,
      onSurface: AppColors.text,
      outline: AppColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      cardColor: AppColors.card,
      dividerColor: AppColors.line,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.ink),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Consistent look for text fields with rounded borders and clean focus states.
InputDecoration fieldDecoration(
  String label, {
  String? hintText,
  IconData? icon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.muted),
    suffixIcon: suffixIcon,
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.brand, 1.8),
    errorBorder: border(AppColors.high),
    focusedErrorBorder: border(AppColors.high, 1.8),
  );
}
