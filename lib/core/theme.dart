import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design token YP79 Terpadu — mengikuti showcase TaskFlow
/// (TaskFlow Product Dashboard Showcase.png).
///
/// Prinsip dari showcase:
///  - latar aplikasi biru sangat muda (#EFF6FF), kartu putih, tanpa gradient;
///  - kartu TANPA garis tepi, elevation 0 (nyaris tanpa bayangan);
///  - badge pill pakai pastel SOLID (bg + teks satu hue), bukan warna pekat;
///  - ikon kategori di kotak pastel bersudut 14 (squircle);
///  - tipografi Inter; sudut kartu 20 / tombol 14 / input 12 / pill 999.
class AppColors {
  // --- Inti (TaskFlow) ---
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryBg = Color(0xFFEFF6FF);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color canvas = Color(0xFFDCE9FB);
  static const Color background = Color(0xFFEFF6FF);
  static const Color surface = Colors.white;

  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);

  // --- Status: warna utama + pastel solid ---
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF97316);
  static const Color warningBg = Color(0xFFFFEDD5);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBg = Color(0xFFEDE9FE);
  static const Color infoBg = Color(0xFFDBEAFE);

  // --- Alias lama supaya seluruh layar tetap kompilasi tanpa diubah ---
  static const Color textPrimary = ink;
  static const Color textSecondary = muted;
  static const Color border = line;
  static const Color textOnPrimary = Colors.white;
}

/// Radius token (showcase: kartu 20, tombol 14, input 12, pill 999, tile 14).
class AppRadius {
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double card = 20;
  static const double btn = 14;
  static const double tile = 14;
  static const double pill = 999;
}

/// Jarak token (showcase: padding konten 20-24, gap kartu 12-14, seksi 22).
class AppSpacing {
  static const double padH = 18;
  static const double padV = 14;
  static const double gap = 12;
  static const double sectionGap = 22;
}

/// Bayangan sangat halus: 0 2 8 rgba(17,24,39,0.05).
const List<BoxShadow> appSoftShadow = [
  BoxShadow(color: Color(0x0D111827), blurRadius: 8, offset: Offset(0, 2)),
];

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    final scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryBg,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.purple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.purpleBg,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerHighest: AppColors.primaryBg,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerBg,
      outlineVariant: AppColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium
            ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
        titleLarge:
            textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium:
            textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 14.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 13.5, height: 1.35),
        bodySmall:
            textTheme.bodySmall?.copyWith(fontSize: 12, color: AppColors.muted),
        labelSmall: textTheme.labelSmall?.copyWith(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
      ),
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: const Color(0x0D111827),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.primaryBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        floatingLabelStyle:
            const TextStyle(color: AppColors.primary, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryBg,
        selectedColor: AppColors.primary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.muted,
        titleTextStyle: TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        subtitleTextStyle: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.infoBg,
        linearMinHeight: 5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.btn),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.btn),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.primaryBg,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFF9CA3AF),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
