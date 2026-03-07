import 'package:flutter/material.dart';

enum AppThemeStyle { indigo, forest, sunset, ocean }

class _CrossSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _CrossSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Push: incoming route enters from left, previous route exits to right.
    // Pop: reverse direction automatically.
    final inFromLeft = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(primary);
    final outToRight = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(secondary);

    return SlideTransition(
      position: outToRight,
      child: SlideTransition(position: inFromLeft, child: child),
    );
  }
}

class _ThemePalette {
  final Color lightSeed;
  final Color darkSeed;
  final Color lightScaffold;
  final Color darkScaffold;
  final Gradient lightBackdrop;
  final Gradient darkBackdrop;
  final Gradient imageOverlayLight;
  final Gradient imageOverlayDark;

  const _ThemePalette({
    required this.lightSeed,
    required this.darkSeed,
    required this.lightScaffold,
    required this.darkScaffold,
    required this.lightBackdrop,
    required this.darkBackdrop,
    required this.imageOverlayLight,
    required this.imageOverlayDark,
  });
}

const Map<AppThemeStyle, _ThemePalette> _themePalettes = {
  AppThemeStyle.indigo: _ThemePalette(
    lightSeed: Color(0xFF4F46E5),
    darkSeed: Color(0xFF7A74FF),
    lightScaffold: Color(0xFFF6F7FB),
    darkScaffold: Color(0xFF111318),
    lightBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF9FAFF), Color(0xFFEDEFFE), Color(0xFFF4F7FF)],
      stops: [0.0, 0.45, 1.0],
    ),
    darkBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10131E), Color(0xFF1A1D2D), Color(0xFF0E111A)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayLight: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xA6FFFFFF), Color(0x88EEF0FF), Color(0xA8FFFFFF)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayDark: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xBF05070D), Color(0x930A0D16), Color(0xC20A0C12)],
      stops: [0.0, 0.48, 1.0],
    ),
  ),
  AppThemeStyle.forest: _ThemePalette(
    lightSeed: Color(0xFF1F8A5B),
    darkSeed: Color(0xFF48C08D),
    lightScaffold: Color(0xFFF3FAF6),
    darkScaffold: Color(0xFF0E1713),
    lightBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF4FFF9), Color(0xFFE5F6EB), Color(0xFFF3FBF5)],
      stops: [0.0, 0.45, 1.0],
    ),
    darkBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D1713), Color(0xFF16251E), Color(0xFF0B120F)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayLight: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xB3FFFFFF), Color(0x8DEAF8F0), Color(0xADFFFFFF)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayDark: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xBF040A07), Color(0x96091410), Color(0xC2070E0B)],
      stops: [0.0, 0.48, 1.0],
    ),
  ),
  AppThemeStyle.sunset: _ThemePalette(
    lightSeed: Color(0xFFE76F51),
    darkSeed: Color(0xFFFF9B7C),
    lightScaffold: Color(0xFFFFF8F3),
    darkScaffold: Color(0xFF1A1210),
    lightBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFCF8), Color(0xFFFFEFE3), Color(0xFFFFF6ED)],
      stops: [0.0, 0.45, 1.0],
    ),
    darkBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1210), Color(0xFF2A1B16), Color(0xFF140E0C)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayLight: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xB3FFFFFF), Color(0x91FFEBDD), Color(0xADFFFFFF)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayDark: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xBF0C0605), Color(0x9B1A0E0A), Color(0xC2120A08)],
      stops: [0.0, 0.48, 1.0],
    ),
  ),
  AppThemeStyle.ocean: _ThemePalette(
    lightSeed: Color(0xFF0088B3),
    darkSeed: Color(0xFF57B7E0),
    lightScaffold: Color(0xFFF3FAFF),
    darkScaffold: Color(0xFF0D141B),
    lightBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6FCFF), Color(0xFFE4F3FB), Color(0xFFF2FAFF)],
      stops: [0.0, 0.45, 1.0],
    ),
    darkBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D141B), Color(0xFF16222E), Color(0xFF0A1016)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayLight: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xB0FFFFFF), Color(0x90E8F5FF), Color(0xAAFFFFFF)],
      stops: [0.0, 0.5, 1.0],
    ),
    imageOverlayDark: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xBF03070A), Color(0x97040F16), Color(0xC2050B11)],
      stops: [0.0, 0.48, 1.0],
    ),
  ),
};

AppThemeStyle appThemeStyleFromId(String? id) {
  for (final style in AppThemeStyle.values) {
    if (style.name == id) return style;
  }
  return AppThemeStyle.indigo;
}

String appThemeStyleId(AppThemeStyle style) => style.name;

BoxDecoration appBackdropDecoration({
  required AppThemeStyle style,
  required bool isDarkMode,
}) {
  final palette =
      _themePalettes[style] ?? _themePalettes[AppThemeStyle.indigo]!;
  return BoxDecoration(
    gradient: isDarkMode ? palette.darkBackdrop : palette.lightBackdrop,
  );
}

BoxDecoration appImageOverlayDecoration({
  required AppThemeStyle style,
  required bool isDarkMode,
}) {
  final palette =
      _themePalettes[style] ?? _themePalettes[AppThemeStyle.indigo]!;
  return BoxDecoration(
    gradient: isDarkMode ? palette.imageOverlayDark : palette.imageOverlayLight,
  );
}

ThemeData buildLightTheme({
  AppThemeStyle style = AppThemeStyle.indigo,
  bool hasCustomBackgroundImage = false,
  double backgroundMist = 0.35,
}) => _buildTheme(
  brightness: Brightness.light,
  style: style,
  hasCustomBackgroundImage: hasCustomBackgroundImage,
  backgroundMist: backgroundMist,
);

ThemeData buildDarkTheme({
  AppThemeStyle style = AppThemeStyle.indigo,
  bool hasCustomBackgroundImage = false,
  double backgroundMist = 0.35,
}) => _buildTheme(
  brightness: Brightness.dark,
  style: style,
  hasCustomBackgroundImage: hasCustomBackgroundImage,
  backgroundMist: backgroundMist,
);

ThemeData _buildTheme({
  required Brightness brightness,
  required AppThemeStyle style,
  required bool hasCustomBackgroundImage,
  required double backgroundMist,
}) {
  final palette =
      _themePalettes[style] ?? _themePalettes[AppThemeStyle.indigo]!;
  final isDark = brightness == Brightness.dark;
  final seed = isDark ? palette.darkSeed : palette.lightSeed;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

  final scaffoldColor = isDark ? palette.darkScaffold : palette.lightScaffold;
  final mist = backgroundMist.clamp(0.0, 1.0);
  double mix(double low, double high) => low + ((high - low) * mist);
  final shellColor = hasCustomBackgroundImage
      ? (isDark
            ? const Color(0xFF0E1218).withValues(alpha: mix(0.18, 0.82))
            : const Color(0xFFFFFFFF).withValues(alpha: mix(0.00, 0.84)))
      : scaffoldColor;
  final cardColor = hasCustomBackgroundImage
      ? (isDark
            ? const Color(0xFF141922).withValues(alpha: mix(0.24, 0.88))
            : const Color(0xFFFFFFFF).withValues(alpha: mix(0.04, 0.90)))
      : (isDark ? const Color(0xFF1A1D24) : Colors.white);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    canvasColor: hasCustomBackgroundImage
        ? const Color(0xFF000000)
        : scaffoldColor,
    scaffoldBackgroundColor: hasCustomBackgroundImage
        ? Colors.transparent
        : scaffoldColor,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: shellColor,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CrossSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: _CrossSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: _CrossSlidePageTransitionsBuilder(),
        TargetPlatform.windows: _CrossSlidePageTransitionsBuilder(),
        TargetPlatform.linux: _CrossSlidePageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      margin: const EdgeInsets.all(4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: hasCustomBackgroundImage
          ? cardColor.withValues(alpha: 0.95)
          : cardColor,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.08),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(cardColor),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
    ),
  );
}

ThemeData buildTheme() => buildLightTheme();
