import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// House Colors
class HouseColors {
  static const Color ruby = Color(0xFFDC2626);
  static const Color rubyDark = Color(0xFFB91C1C);
  static const Color rubyLight = Color(0xFFFEE2E2);

  static const Color rubyGlow = Color(0xFFFF2A4B);
  static const Color rubyAccent = Color(0xFFFF7875);

  static const Color sapphire = Color(0xFF2563EB);
  static const Color sapphireDark = Color(0xFF1D4ED8);
  static const Color sapphireLight = Color(0xFFDBEAFE);
  static const Color sapphireGlow = Color(0xFF2979FF);
  static const Color sapphireAccent = Color(0xFF69C0FF);

  static const Color emerald = Color(0xFF059669);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldLight = Color(0xFFD1FAE5);
  static const Color emeraldGlow = Color(0xFF00E676);
  static const Color emeraldAccent = Color(0xFF95DE64);

  static const Color topaz = Color(0xFFD97706);
  static const Color topazDark = Color(0xFFB45309);
  static const Color topazLight = Color(0xFFFEF3C7);
  static const Color topazGlow = Color(0xFFFFC107);
  static const Color topazAccent = Color(0xFFFFD666);

  static Color getHouseColor(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return ruby;
      case 'sapphire':
        return sapphire;
      case 'emerald':
        return emerald;
      case 'topaz':
        return topaz;
      default:
        return ruby;
    }
  }

  static Color getHouseDarkColor(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return rubyDark;
      case 'sapphire':
        return sapphireDark;
      case 'emerald':
        return emeraldDark;
      case 'topaz':
        return topazDark;
      default:
        return rubyDark;
    }
  }

  static Color getHouseLightColor(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return rubyLight;
      case 'sapphire':
        return sapphireLight;
      case 'emerald':
        return emeraldLight;
      case 'topaz':
        return topazLight;
      default:
        return rubyLight;
    }
  }

  static Color getHouseGlowColor(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return rubyGlow;
      case 'sapphire':
        return sapphireGlow;
      case 'emerald':
        return emeraldGlow;
      case 'topaz':
        return topazGlow;
      default:
        return rubyGlow;
    }
  }

  static Color getHouseAccentColor(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return rubyAccent;
      case 'sapphire':
        return sapphireAccent;
      case 'emerald':
        return emeraldAccent;
      case 'topaz':
        return topazAccent;
      default:
        return rubyAccent;
    }
  }

  static String getHouseEmoji(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return '🐉';
      case 'sapphire':
        return '🦅';
      case 'emerald':
        return '🐺';
      case 'topaz':
        return '🦁';
      default:
        return '🏆';
    }
  }

  static String getHouseMascotName(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return 'Ignis the Crimson Dragon';
      case 'sapphire':
        return 'Zephyr the Tempest Gryphon';
      case 'emerald':
        return 'Sylva the Titan Wolf';
      case 'topaz':
        return 'Solis the Golden Chimera';
      default:
        return 'House Mascot';
    }
  }

  static LinearGradient getHouseGradient(String house) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getHouseColor(house), getHouseDarkColor(house)],
    );
  }
}

/// Unified Luxury Glassmorphism & Surface Tokens
class AppGlass {
  static BoxDecoration cardDecoration({
    required BuildContext context,
    Color? accentColor,
    double radius = 24,
    double borderWidth = 1.2,
    double borderAlpha = 0.12,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0F1523) : Colors.white;
    final borderColor = accentColor != null
        ? accentColor.withValues(alpha: borderAlpha * 2.2)
        : (isDark ? Colors.white.withValues(alpha: borderAlpha) : const Color(0xFFE2E8F0));

    return BoxDecoration(
      color: isDark ? baseColor.withValues(alpha: 0.90) : baseColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: (accentColor ?? (isDark ? Colors.black : Colors.blueGrey))
              .withValues(alpha: isDark ? 0.25 : 0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

/// Haptic Feedback Standard Tokens for Tactile App Interactions
class AppHaptics {
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void success() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.lightImpact());
  }
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
  }
}

class AppTheme {
  static const String fontFamily = 'Inter';

  // --- Light Theme ---
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    colorScheme: const ColorScheme.light(
      primary: HouseColors.ruby,
      onPrimary: Colors.white,
      secondary: Color(0xFF475569),
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      error: Color(0xFFEF4444),
      outline: Color(0xFFE2E8F0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HouseColors.ruby, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      labelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF94A3B8),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HouseColors.ruby,
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFFEF4444),
      ),
      prefixIconColor: const Color(0xFF94A3B8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HouseColors.ruby,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HouseColors.ruby,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );

  // --- Dark Theme ---
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B1120),
    colorScheme: const ColorScheme.dark(
      primary: HouseColors.ruby,
      onPrimary: Colors.white,
      secondary: Color(0xFF94A3B8),
      surface: Color(0xFF151D2E),
      onSurface: Color(0xFFF1F5F9),
      error: Color(0xFFEF4444),
      outline: Color(0xFF2A3A52),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF151D2E),
      foregroundColor: Color(0xFFF1F5F9),
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2338),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A52), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3A52), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HouseColors.ruby, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      labelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HouseColors.ruby,
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFFEF4444),
      ),
      prefixIconColor: const Color(0xFF64748B),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HouseColors.ruby,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Color(0xFFF87171),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
