import 'package:flutter/material.dart';

/// Ant Design Color Palette and Theme for Admin Screens
/// Based on Ant Design 5.0 specifications
class AntColors {
  // Primary Colors
  static const Color primary = Color(0xFF1890FF);
  static const Color primaryHover = Color(0xFF40A9FF);
  static const Color primaryActive = Color(0xFF096DD9);
  static const Color primaryOutline = Color(0xFFD6E4FF);

  // Success Colors
  static const Color success = Color(0xFF52C41A);
  static const Color successHover = Color(0xFF73D13D);
  static const Color successActive = Color(0xFF389E0D);
  static const Color successOutline = Color(0xFFD9F7BE);

  // Warning Colors
  static const Color warning = Color(0xFFFAAD14);
  static const Color warningHover = Color(0xFFFFC069);
  static const Color warningActive = Color(0xFFD48806);
  static const Color warningOutline = Color(0xFFFFF7E6);

  // Error Colors
  static const Color error = Color(0xFFFF4D4F);
  static const Color errorHover = Color(0xFFFF7875);
  static const Color errorActive = Color(0xFFD4380D);
  static const Color errorOutline = Color(0xFFFFD8D8);

  // Info Colors
  static const Color info = Color(0xFF1890FF);
  static const Color infoHover = Color(0xFF40A9FF);
  static const Color infoActive = Color(0xFF096DD9);
  static const Color infoOutline = Color(0xFFD6E4FF);

  // Neutral Colors
  static const Color text = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textQuaternary = Color(0xFFCCCCCC);

  static const Color border = Color(0xFFD9D9D9);
  static const Color borderSecondary = Color(0xFFE8E8E8);
  static const Color divider = Color(0xFFE8E8E8);

  static const Color fill = Color(0xFFF5F5F5);
  static const Color fillSecondary = Color(0xFFFAFAFA);
  static const Color fillTertiary = Color(0xFFF0F0F0);
  static const Color fillQuaternary = Color(0xFFE8E8E8);

  // Background Colors
  static const Color bgContainer = Color(0xFFFFFFFF);
  static const Color bgLayout = Color(0xFFFAFAFA);
  static const Color bgComponent = Color(0xFFFFFFFF);
  static const Color bgComponentSecondary = Color(0xFFFAFAFA);

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowSecondary = Color(0x0D000000);
}

/// Ant Design Theme Data
class AntTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AntColors.primary,
      scaffoldBackgroundColor: AntColors.bgLayout,
      cardColor: AntColors.bgComponent,
      dividerColor: AntColors.divider,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AntColors.bgComponent,
        foregroundColor: AntColors.text,
        elevation: 0,
        shadowColor: AntColors.shadow,
        surfaceTintColor: Colors.transparent,
      ),

      // Card Theme - Using default
      // cardTheme: const CardTheme(
      //   color: AntColors.bgComponent,
      //   shadowColor: AntColors.shadow,
      //   elevation: 2,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.all(Radius.circular(AntBorderRadius.md)),
      //   ),
      // ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AntColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AntColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AntColors.primary,
          side: const BorderSide(color: AntColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AntColors.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AntColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AntColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AntColors.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AntColors.text,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AntColors.text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AntColors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AntColors.text,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AntColors.text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AntColors.text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AntColors.text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AntColors.textSecondary,
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AntColors.fill,
        selectedColor: AntColors.primaryOutline,
        checkmarkColor: AntColors.primary,
        deleteIconColor: AntColors.textSecondary,
        labelStyle: const TextStyle(color: AntColors.text),
        secondaryLabelStyle: const TextStyle(color: AntColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Dialog Theme - Using default
      // dialogTheme: const DialogTheme(
      //   backgroundColor: AntColors.bgComponent,
      //   elevation: 8,
      //   shadowColor: AntColors.shadow,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.all(Radius.circular(AntBorderRadius.md)),
      //   ),
      // ),

      // SnackBar Theme
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AntColors.bgComponent,
        contentTextStyle: TextStyle(color: AntColors.text),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    );
  }
}

/// Ant Design Spacing System
class AntSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Ant Design Border Radius
class AntBorderRadius {
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
}

/// Ant Design Shadows
class AntShadows {
  static const BoxShadow sm = BoxShadow(
    color: AntColors.shadow,
    offset: Offset(0, 1),
    blurRadius: 2,
  );

  static const BoxShadow md = BoxShadow(
    color: AntColors.shadow,
    offset: Offset(0, 2),
    blurRadius: 8,
  );

  static const BoxShadow lg = BoxShadow(
    color: AntColors.shadow,
    offset: Offset(0, 4),
    blurRadius: 16,
  );
}
