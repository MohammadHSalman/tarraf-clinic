import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData clinicTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Tk.ink,
    onPrimary: Colors.white,
    primaryContainer: Tk.goldSoft,
    onPrimaryContainer: Tk.ink,
    secondary: Tk.gold,
    onSecondary: Colors.white,
    secondaryContainer: Tk.goldSoft,
    onSecondaryContainer: Tk.goldDeep,
    tertiary: Tk.sage,
    onTertiary: Colors.white,
    error: Tk.rose,
    onError: Colors.white,
    surface: Tk.surface,
    onSurface: Tk.ink,
    onSurfaceVariant: Tk.inkSoft,
    outline: Tk.line,
    outlineVariant: Tk.line,
    surfaceContainerHighest: Tk.surfaceAlt,
    inverseSurface: Tk.ink,
    onInverseSurface: Colors.white,
    inversePrimary: Tk.goldSoft,
  );
  RoundedRectangleBorder shape(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Tajawal',
    colorScheme: scheme,
    scaffoldBackgroundColor: Tk.ivory,
    canvasColor: Tk.ivory,
    dividerColor: Tk.line,
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      headlineMedium: tjw(28, FontWeight.w800, height: 1.2),
      headlineSmall: tjw(24, FontWeight.w800, height: 1.25),
      titleLarge: tjw(20, FontWeight.w800, height: 1.3),
      titleMedium: tjw(16, FontWeight.w700, height: 1.35),
      titleSmall: tjw(14, FontWeight.w700, height: 1.35),
      bodyLarge: tjw(16, FontWeight.w400, height: 1.5),
      bodyMedium: tjw(14.5, FontWeight.w400, height: 1.5),
      bodySmall: tjw(12.5, FontWeight.w400, color: Tk.inkSoft, height: 1.45),
      labelLarge: tjw(14.5, FontWeight.w700),
      labelMedium: tjw(13, FontWeight.w600),
      labelSmall: tjw(12, FontWeight.w600, color: Tk.inkSoft),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Tk.ivory,
      foregroundColor: Tk.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: tjw(20, FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Tk.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: Tk.goldSoft,
      indicatorShape: shape(16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => tjw(
          12,
          s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Tk.ink : Tk.inkSoft,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? Tk.goldDeep : Tk.inkSoft,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tk.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Tk.line,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: shape(16),
        textStyle: tjw(15, FontWeight.w700, color: Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tk.ink,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: Tk.line, width: 1.3),
        shape: shape(16),
        textStyle: tjw(14.5, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tk.goldDeep,
        shape: shape(12),
        textStyle: tjw(14, FontWeight.w700, color: Tk.goldDeep),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Tk.ink),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Tk.ink,
      foregroundColor: Colors.white,
      elevation: 3,
      extendedTextStyle: tjw(15, FontWeight.w700, color: Colors.white),
      shape: shape(18),
    ),
    cardTheme: CardThemeData(
      color: Tk.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tk.r),
        side: const BorderSide(color: Tk.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tk.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Tk.line),
      enabledBorder: border(Tk.line),
      focusedBorder: border(Tk.ink, 1.6),
      errorBorder: border(Tk.rose),
      focusedErrorBorder: border(Tk.rose, 1.6),
      labelStyle: tjw(14, FontWeight.w500, color: Tk.inkSoft),
      floatingLabelStyle: tjw(13, FontWeight.w700, color: Tk.goldDeep),
      hintStyle: tjw(14, FontWeight.w400, color: Tk.inkFaint),
      helperStyle: tjw(12.5, FontWeight.w600, color: Tk.goldDeep),
      prefixIconColor: Tk.inkSoft,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Tk.surface,
      selectedColor: Tk.goldSoft,
      checkmarkColor: Tk.goldDeep,
      side: const BorderSide(color: Tk.line),
      shape: const StadiumBorder(),
      labelStyle: tjw(13, FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Tk.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape(24),
      titleTextStyle: tjw(20, FontWeight.w800),
      contentTextStyle: tjw(15, FontWeight.w400, color: Tk.inkSoft, height: 1.5),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Tk.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: const Color(0xffD5CEBF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Tk.rLg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Tk.ink,
      contentTextStyle: tjw(14, FontWeight.w500, color: Colors.white),
      shape: shape(14),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Tk.ink,
      titleTextStyle: tjw(16, FontWeight.w700),
      subtitleTextStyle: tjw(13, FontWeight.w400, color: Tk.inkSoft),
    ),
    dividerTheme: const DividerThemeData(color: Tk.line, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : Tk.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Tk.ink : Tk.line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Tk.ink,
      unselectedLabelColor: Tk.inkSoft,
      indicatorColor: Tk.gold,
      dividerColor: Tk.line,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: tjw(14, FontWeight.w800),
      unselectedLabelStyle: tjw(14, FontWeight.w500, color: Tk.inkSoft),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(shape(14)),
        side: const WidgetStatePropertyAll(BorderSide(color: Tk.line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Tk.ink : Tk.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Tk.ink,
        ),
        textStyle: WidgetStatePropertyAll(tjw(13.5, FontWeight.w700)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Tk.gold),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      tilePadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
