import 'package:flutter/material.dart';

class AppTheme extends Theme {
  const AppTheme({required super.data, required super.child, super.key});
  static const _bg = Color(0xFF121212);
  static const _surface = Color(0xFF1E1E1E);
  static const _surfaceHigh = Color(0xFF242424);
  static const _border = Color(0xFF2D2D2D);
  static const _text = Colors.white;
  static const _textMuted = Colors.white70;
  static const _brand = Color(0xFF1E88E5);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.dark,
        surface: _surface,
        onSurface: _text,
        onPrimary: _text,
        onSecondary: _text,
        onTertiary: _text,
      ),
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsBuilder(),
        },
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        titleTextStyle: TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        contentTextStyle: TextStyle(color: _text, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surfaceHigh,
        contentTextStyle: TextStyle(color: _text),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _surfaceHigh,
        hintStyle: TextStyle(color: _textMuted),
        labelStyle: TextStyle(color: _text),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _border, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _text, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6AABDB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      dividerTheme: const DividerThemeData(color: _border, thickness: 1.2),
      cardColor: _surface,
    );
  }
}

/// Centralized palette/tokens used across the app. Prefer these over
/// sprinkling raw color codes.
class AppColors {
  static const background = AppTheme._bg;
  static const surface = AppTheme._surface;
  static const surfaceHigh = AppTheme._surfaceHigh;
  static const border = AppTheme._border;
  static const text = AppTheme._text;
  static const textMuted = AppTheme._textMuted;
  static const brand = AppTheme._brand;
  static const accent = Colors.blueAccent;
  static const controlBlue = Color(0xFF6AABDB);

  /// Tinted surface for in-progress generation cards.
  static const inProgressSurface = Color(0xFF1A2A3D);
  static const inProgressBorder = Color(0xFF2A4A6F);
  static const inProgressTrack = Color(0xFF1A2E44);

  /// Tinted surface for completed generation cards.
  static const completedSurface = Color(0xFF1A2838);
  static const completedBorder = Color(0xFF2A4060);

  static Color overlay(double alpha) =>
      Colors.black.withValues(alpha: alpha.clamp(0, 1));
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // No animation
  }
}
