import 'package:flutter/material.dart';

class AppTheme extends Theme {
  const AppTheme({required super.data, required super.child, super.key});
  static const _bg = Color(0xFF121212);
  static const _surface = Color(0xFF1E1E1E);
  static const _surfaceHigh = Color(0xFF242424);
  static const _border = Color(0xFF2D2D2D);
  static const _text = Colors.white;
  static const _textMuted = Colors.white70;
  static const _brand = Color(0xFF5C9CE6);

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
        fillColor: _bg,
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
          backgroundColor: const Color(0xFF5C9CE6),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white10,
      dividerTheme: const DividerThemeData(color: _border, thickness: 1.2),
      cardColor: _surface,
    );
  }
}

class AppColors {
  static const background = AppTheme._bg;
  static const surface = AppTheme._surface;
  static const surfaceHigh = AppTheme._surfaceHigh;
  static const border = AppTheme._border;
  static const text = AppTheme._text;
  static const textMuted = AppTheme._textMuted;
  static const brand = AppTheme._brand;
  static const accent = Color(0xFF5C9CE6);
  static const accentPink = Color(0xFFE05CB5);
  static const hotPink = Color(0xFFFF69B4);
  static const controlPink = Color(0xFF5C9CE6);
  static const settingsHeading = Color(0xFF81D4FA);

  static Color overlay(double alpha) =>
      Colors.black.withValues(alpha: alpha.clamp(0, 1));
}

enum ScreenSize { compact, medium, wide }

class Responsive {
  static const double compactBreakpoint = 700;
  static const double wideBreakpoint = 1100;

  static ScreenSize of(double width) {
    if (width < compactBreakpoint) return ScreenSize.compact;
    if (width < wideBreakpoint) return ScreenSize.medium;
    return ScreenSize.wide;
  }

  static double sidebarWidth(ScreenSize size) =>
      size == ScreenSize.compact ? 48 : 72;

  static double pagePadding(ScreenSize size) =>
      size == ScreenSize.compact ? 16 : 32;

  static double formPanelWidth(ScreenSize size) => switch (size) {
        ScreenSize.compact => double.infinity,
        ScreenSize.medium => 250,
        ScreenSize.wide => 300,
      };

  static double detailPanelWidth(ScreenSize size) => switch (size) {
        ScreenSize.compact => double.infinity,
        ScreenSize.medium => 250,
        ScreenSize.wide => 300,
      };
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
    return child;
  }
}
