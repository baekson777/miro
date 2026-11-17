import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const fontFamily = 'Pretendard';

  /// Comfortable mobile sizes (slightly smaller than Material 3 defaults).
  static TextTheme get _textTheme {
    const family = fontFamily;
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: family,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontFamily: family,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: family,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontFamily: family,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: family,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontFamily: family,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontFamily: family,
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontFamily: family,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontFamily: family,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
    );
  }

  static ThemeData get dark {
    const bg = Color(0xFF050508);
    const accent = Color(0xFFE8C547);
    final textTheme = _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: bg,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: Colors.white54,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 13),
        hintStyle: TextStyle(fontFamily: fontFamily, fontSize: 13),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 52,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.white24,
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(size: 20, color: Colors.white),
        ),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: 10.5,
            height: 1.1,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
