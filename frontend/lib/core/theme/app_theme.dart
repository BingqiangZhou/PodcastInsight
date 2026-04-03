import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/font_combination.dart';
import 'package:personal_ai_assistant/core/theme/responsive_helpers.dart';

/// ============================================================
/// Refined Minimal Design System - 简约现代设计系统
///
/// Typography System:
/// - Headings: Space Grotesk (几何感、科技感、未来感)
/// - Body: Inter (行业标准、极致清晰、屏幕优化)
/// - Monospace: IBM Plex Mono (人文主义等宽、专业感)
/// ============================================================

class AppTheme {
  AppTheme._();

  // ============================================================
  // CACHED FONT METADATA / 缓存字体元数据
  // These are resolved once and reused across all theme builds.
  // ============================================================

  /// CJK fallback chain shared across all font combinations.
  static const List<String> _cjkFallback = [
    'Noto Sans SC',
    'PingFang SC',
    'Microsoft YaHei',
  ];

  /// Per-combo cached heading bases.
  static final Map<String, TextStyle> _headingBases = {};

  /// Per-combo cached body bases.
  static final Map<String, TextStyle> _bodyBases = {};

  /// Cached monospace base (IBM Plex Mono — fixed, not user-selectable).
  static final TextStyle _monoBase = GoogleFonts.ibmPlexMono();

  /// Currently active font combination, set by the app when fonts change.
  static FontCombination _currentFonts = FontCombination.defaultCombination;

  /// Update the active font combination and invalidate theme cache.
  static void updateFontCombination(FontCombination fonts) {
    _currentFonts = fonts;
    _themeCache.clear();
  }

  /// Get cached heading base for the given combination.
  /// Falls back to a plain TextStyle when Google Fonts is unavailable (e.g. tests).
  static TextStyle _headingBaseFor(FontCombination fonts) =>
      _headingBases.putIfAbsent(
        fonts.id,
        () {
          try {
            return GoogleFonts.getFont(fonts.headingFontFamily);
          } catch (_) {
            return TextStyle(fontFamily: fonts.headingFontFamily);
          }
        },
      );

  /// Get cached body base for the given combination.
  /// Falls back to a plain TextStyle when Google Fonts is unavailable (e.g. tests).
  static TextStyle _bodyBaseFor(FontCombination fonts) => _bodyBases.putIfAbsent(
        fonts.id,
        () {
          try {
            return GoogleFonts.getFont(
              fonts.bodyFontFamily,
              textStyle: const TextStyle(fontFamilyFallback: _cjkFallback),
            );
          } catch (_) {
            return TextStyle(
              fontFamily: fonts.bodyFontFamily,
              fontFamilyFallback: _cjkFallback,
            );
          }
        },
      );

  /// Cached body font family name for the default combination.
  static final String _bodyFontFamily =
      GoogleFonts.getFont(FontCombination.defaultCombination.bodyFontFamily)
          .fontFamily!;

  /// Returns a monospace TextStyle suitable for code, timestamps, and data.
  /// Uses IBM Plex Mono for a refined, readable monospace accent.
  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    Color? color,
  }) {
    return _monoBase.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
      color: color,
    );
  }

  // ============================================================
  // NAMED STYLE HELPERS / 命名样式助手
  // For sizes not covered by standard TextTheme slots.
  // ============================================================

  /// Transcript body text (fontSize: 15, height: 1.6).
  /// Used across podcast transcript and show notes displays.
  static TextStyle transcriptBody([Color? color]) => _bodyBaseFor(_currentFonts).copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
    color: color,
  );

  /// Caption text (fontSize: 13, height: 1.4).
  /// Fills the gap between bodySmall (12) and bodyMedium (14).
  static TextStyle caption([Color? color]) => _bodyBaseFor(_currentFonts).copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
    color: color,
  );

  /// Compact metadata text (fontSize: 11, height: 1.3).
  /// For scores, tags, micro-labels.
  static TextStyle metaSmall([Color? color]) => _bodyBaseFor(_currentFonts).copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    color: color,
  );

  /// Navigation rail label (fontSize: 10, height: 1.0).
  /// For extremely compact navigation labels.
  static TextStyle navLabel(Color? color, {FontWeight weight = FontWeight.w500}) =>
    _bodyBaseFor(_currentFonts).copyWith(
      fontSize: 10,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: 0.2,
      color: color,
    );

  // ============================================================
  // RESPONSIVE HELPERS (re-exported from ResponsiveHelpers)
  // 响应式助手（从 ResponsiveHelpers 重新导出）
  // ============================================================

  /// 响应式边距助手
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context) =>
      ResponsiveHelpers.getResponsivePadding(context);

  /// 响应式水平边距助手
  static EdgeInsetsGeometry getResponsiveHorizontalPadding(BuildContext context) =>
      ResponsiveHelpers.getResponsiveHorizontalPadding(context);

  /// 响应式垂直边距助手
  static EdgeInsetsGeometry getResponsiveVerticalPadding(BuildContext context) =>
      ResponsiveHelpers.getResponsiveVerticalPadding(context);

  /// 获取响应式最大宽度
  static double getResponsiveMaxWidth(BuildContext context) =>
      ResponsiveHelpers.getResponsiveMaxWidth(context);

  // ============================================================
  // THEME ACCESSORS / 主题访问器
  // Cached so they are only built once per brightness.
  // ============================================================

  /// Theme cache keyed by '${fontComboId}_${brightness}'.
  static final Map<String, ThemeData> _themeCache = {};

  /// Build (or return cached) theme for the given brightness and fonts.
  static ThemeData buildTheme(Brightness brightness, FontCombination fonts) {
    final cacheKey = '${fonts.id}_${brightness.name}';
    return _themeCache.putIfAbsent(cacheKey, () => _buildTheme(brightness, fonts));
  }

  /// Backward-compatible light theme (uses default fonts).
  static ThemeData get lightTheme =>
      buildTheme(Brightness.light, _currentFonts);

  /// Backward-compatible dark theme (uses default fonts).
  static ThemeData get darkTheme =>
      buildTheme(Brightness.dark, _currentFonts);

  static ThemeData _buildTheme(Brightness brightness, FontCombination fonts) {
    final isDark = brightness == Brightness.dark;
    final scheme = _buildColorScheme(brightness);
    final textTheme = _buildTextTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
    );
    final extension = isDark
        ? AppThemeExtension.dark
        : AppThemeExtension.light;

    final googleTextTheme = _buildGoogleTextTheme(textTheme, fonts);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      textTheme: googleTextTheme,
      fontFamily: _bodyBaseFor(fonts).fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        titleTextStyle: _withHeading(
          textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: extension.shadowMd.color,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(extension.cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(extension.panelRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: _withHeading(textTheme.headlineSmall),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : scheme.surface,
        hintStyle: _withBody(
          textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        labelStyle: _withBody(
          textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(extension, scheme.outlineVariant),
        enabledBorder: _inputBorder(extension, scheme.outlineVariant),
        focusedBorder: _inputBorder(
          extension,
          scheme.primary.withValues(alpha: 0.6),
          width: 1.4,
        ),
        errorBorder: _inputBorder(extension, scheme.error),
        focusedErrorBorder: _inputBorder(extension, scheme.error, width: 1.4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(extension.cardRadius)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        disabledColor: scheme.surfaceContainerHighest,
        secondarySelectedColor: scheme.primary.withValues(alpha: 0.16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: _withBody(
          textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        ),
        secondaryLabelStyle: _withBody(
          textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surface,
        contentTextStyle: _withBody(
          textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(extension.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(extension.buttonRadius)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _withBody(
            textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: _withBody(
          textTheme.labelMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        unselectedLabelTextStyle: _withBody(
          textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(
          scheme.primary,
          scheme.onPrimary,
          radius: extension.buttonRadius,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: _withBody(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          scheme.primary,
          scheme.onPrimary,
          radius: extension.buttonRadius,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: _withBody(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(extension.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: _withBody(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(extension.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: _withBody(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12);
            }
            return scheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(extension.buttonRadius)),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[extension],
    );
  }

  static ColorScheme _buildColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return base.copyWith(
      primary: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
      onPrimary: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      primaryContainer: isDark
          ? AppColors.primaryContainerDark
          : AppColors.primaryContainer,
      onPrimaryContainer: isDark
          ? AppColors.darkTextPrimary
          : const Color(0xFF1E3A8A),
      secondary: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      onSecondary: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      onSecondaryContainer: isDark
          ? AppColors.darkTextPrimary
          : const Color(0xFF334155),
      tertiary: isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A),
      onTertiary: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      tertiaryContainer: isDark
          ? const Color(0xFF14532D)
          : const Color(0xFFDCFCE7),
      onTertiaryContainer: isDark
          ? const Color(0xFFECFDF5)
          : const Color(0xFF166534),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: isDark
          ? const Color(0xFF451A1B)
          : const Color(0xFFFEE2E2),
      onErrorContainer: isDark
          ? const Color(0xFFFECACA)
          : const Color(0xFF7F1D1D),
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
      onSurfaceVariant: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
      outlineVariant: isDark
          ? AppColors.darkOutlineVariant
          : AppColors.lightOutlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static OutlineInputBorder _inputBorder(
    AppThemeExtension extension,
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(extension.inputRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ButtonStyle _buttonStyle(
    Color backgroundColor,
    Color foregroundColor, {
    required double radius,
    required double elevation,
    required EdgeInsetsGeometry padding,
    required TextStyle? textStyle,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      textStyle: textStyle,
    );
  }

  /// Build the base text theme with proper hierarchy
  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color tertiary,
  ) {
    const base = TextTheme();
    return base.copyWith(
      displaySmall: TextStyle(
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.65,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.6,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: tertiary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: tertiary,
      ),
    );
  }

  /// Apply heading font to a [TextStyle] using the cached base.
  static TextStyle _withHeading(TextStyle? base) {
    return _headingBaseFor(_currentFonts).merge(base);
  }

  /// Apply body font to a [TextStyle] using the cached base.
  static TextStyle _withBody(TextStyle? base) {
    return _bodyBaseFor(_currentFonts).merge(base);
  }

  /// Build typography with the given font combination.
  /// Uses cached font family references instead of repeated GoogleFonts calls.
  static TextTheme _buildGoogleTextTheme(TextTheme baseTheme, FontCombination fonts) {
    final headingBase = _headingBaseFor(fonts);
    final bodyBase = _bodyBaseFor(fonts);
    return baseTheme.copyWith(
      displaySmall: headingBase.merge(baseTheme.displaySmall),
      headlineLarge: headingBase.merge(baseTheme.headlineLarge),
      headlineMedium: headingBase.merge(baseTheme.headlineMedium),
      headlineSmall: headingBase.merge(baseTheme.headlineSmall),
      titleLarge: headingBase.merge(baseTheme.titleLarge),
      titleMedium: bodyBase.merge(baseTheme.titleMedium),
      titleSmall: bodyBase.merge(baseTheme.titleSmall),
      bodyLarge: bodyBase.merge(baseTheme.bodyLarge),
      bodyMedium: bodyBase.merge(baseTheme.bodyMedium),
      bodySmall: bodyBase.merge(baseTheme.bodySmall),
      labelLarge: bodyBase.merge(baseTheme.labelLarge),
      labelMedium: bodyBase.merge(baseTheme.labelMedium),
      labelSmall: bodyBase.merge(baseTheme.labelSmall),
    );
  }
}
