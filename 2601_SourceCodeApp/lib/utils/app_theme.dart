import 'package:flutter/material.dart';

class AppTheme {
  // --- Core Palette (Velora Inspired) ---
  static const Color primary = Color(0xFF00E676); // Neon Green / Spring Green
  static const Color secondary = Color(0xFF69F0AE); // Lighter Green Accent
  static const Color background = Color(0xFF050505); // Deep Black
  static const Color surface = Color(0xFF111111); // Dark Card Background
  static const Color surfaceHighlight = Color(
    0xFF1A1A1A,
  ); // Slightly lighter for inputs

  // --- Text ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0); // Light Grey
  static const Color textWhite = Colors.white;

  // --- Status Colors (High Contrast for Dark Mode) ---
  static const Color success = Color(0xFF00E676); // Matching Primary
  static const Color warning = Color(0xFFFFD740); // Amber Accent
  static const Color error = Color(0xFFFF5252); // Red Accent
  static const Color info = Color(0xFF40C4FF); // Light Blue Accent

  // --- UI Elements ---
  static Color border = const Color(0xFF333333); // Dark Grey Border
  static Color divider = const Color(0xFF222222); // Darker Divider
  static Color shadow = Colors.black.withValues(
    alpha: 0.5,
  ); // Stronger shadow for dark mode
  static const Color iconDefault = Color(0xFF909090);

  // --- Specifics (Adapted for Dark Mode) ---
  static const Color landingStart = Color(0xFF000000);
  static const Color landingEnd = Color(0xFF111111);

  // These "Light" variants are now dark backgrounds with colored tints
  static Color primaryLight = primary.withValues(alpha: 0.15);
  static Color successLight = success.withValues(alpha: 0.15);
  static Color errorLight = error.withValues(alpha: 0.15);
  static Color warningLight = warning.withValues(alpha: 0.15);

  // --- Theme Data ---
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        surfaceContainer: surfaceHighlight,
        error: error,
        onSurface: textPrimary,
        onPrimary: Colors.black, // Black text on green buttons for contrast
      ),
      scaffoldBackgroundColor: background,
      primaryColor: primary,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background, // Match scaffold
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            16,
          ), // Slightly rounder like Velora
          side: BorderSide(color: border),
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black, // Black text on neon green
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighlight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: primary),
    );
  }

  // --- Helpers ---

  /// Centralized logic for status colors across the app
  static Color getStatusColor(String? status) {
    if (status == null) return textSecondary;
    switch (status.toLowerCase()) {
      case 'available':
      case 'completed':
      case 'active':
        return success;
      case 'assigned':
      case 'in-progress':
      case 'van': // Vehicle modes
      case 'pickup':
        return info;
      case 'maintenance':
      case 'cancelled':
      case 'skipped':
      case 'dropoff':
        return error;
      case 'scheduled':
      case 'pending':
      case '2-wheeler':
      default:
        return warning;
    }
  }

  /// Helper for background versions of status colors (chips)
  static Color getStatusBackgroundColor(String? status) {
    return getStatusColor(status).withValues(alpha: 0.15);
  }
}
