part of '../../main.dart';

ThemeData buildAppTheme(Brightness brightness) {
  const seed = Color(0xFFFF5B6E);
  final isDark = brightness == Brightness.dark;
  final colors = isDark
      ? const AppThemeColors.dark()
      : const AppThemeColors.light();

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    surface: colors.surface,
  );
  final baseTextTheme = isDark ? ThemeData.dark() : ThemeData.light();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: baseTextTheme.textTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: colors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      hintStyle: TextStyle(color: colors.subtleText),
      labelStyle: TextStyle(color: colors.mutedText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: seed, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navigationBackground,
      indicatorColor: colors.navigationIndicator,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? seed
              : colors.mutedText,
        );
      }),
      elevation: isDark ? 0 : 1,
      shadowColor: colors.border.withValues(alpha: 0.4),
      surfaceTintColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? seed
              : colors.mutedText;
        }),
        side: WidgetStateProperty.all(BorderSide(color: colors.border)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.accentSurface
              : colors.surface;
        }),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.zero,
    ),
  );
}

enum AppThemePreference {
  dark('Dark', Icons.dark_mode_outlined, ThemeMode.dark),
  light('Light', Icons.light_mode_outlined, ThemeMode.light);

  const AppThemePreference(this.label, this.icon, this.themeMode);

  final String label;
  final IconData icon;
  final ThemeMode themeMode;
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inputFill,
    required this.text,
    required this.mutedText,
    required this.subtleText,
    required this.border,
    required this.navigationBackground,
    required this.navigationIndicator,
    required this.accentSurface,
    required this.backgroundGradientStart,
    required this.backgroundGradientMiddle,
    required this.backgroundGradientEnd,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.mediaGradientStart,
    required this.mediaGradientEnd,
    required this.overlayMiniCard,
  });

  const AppThemeColors.dark()
    : this(
        background: const Color(0xFF0D1020),
        surface: const Color(0xFF161B31),
        surfaceRaised: const Color(0xFF1D2340),
        inputFill: const Color(0xFF1D2340),
        text: const Color(0xFFEAF0FF),
        mutedText: const Color(0xFFA0A8C3),
        subtleText: const Color(0xFF7F89A8),
        border: const Color(0xFF2B3356),
        navigationBackground: const Color(0xFF11162A),
        navigationIndicator: const Color(0xFF3B2741),
        accentSurface: const Color(0xFF3B2741),
        backgroundGradientStart: const Color(0xFF0E1020),
        backgroundGradientMiddle: const Color(0xFF12152A),
        backgroundGradientEnd: const Color(0xFF1A1F38),
        heroGradientStart: const Color(0xFF1A1F38),
        heroGradientEnd: const Color(0xFF141A31),
        mediaGradientStart: const Color(0xFF2B365F),
        mediaGradientEnd: const Color(0xFF151B31),
        overlayMiniCard: const Color(0x14FFFFFF),
      );

  const AppThemeColors.light()
    : this(
        background: const Color(0xFFF7FAFE),
        surface: const Color(0xFFFFFFFF),
        surfaceRaised: const Color(0xFFF0F5FB),
        inputFill: const Color(0xFFFFFFFF),
        text: const Color(0xFF172033),
        mutedText: const Color(0xFF5F6F89),
        subtleText: const Color(0xFF7D8A9E),
        border: const Color(0xFFD9E2EE),
        navigationBackground: const Color(0xFFFFFFFF),
        navigationIndicator: const Color(0xFFFFE2E7),
        accentSurface: const Color(0xFFFFEAF0),
        backgroundGradientStart: const Color(0xFFFFF7F8),
        backgroundGradientMiddle: const Color(0xFFF1FAFF),
        backgroundGradientEnd: const Color(0xFFF7FAFE),
        heroGradientStart: const Color(0xFFFFFFFF),
        heroGradientEnd: const Color(0xFFEFF7FF),
        mediaGradientStart: const Color(0xFFE4EEF9),
        mediaGradientEnd: const Color(0xFFFFFFFF),
        overlayMiniCard: const Color(0x0F172033),
      );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color inputFill;
  final Color text;
  final Color mutedText;
  final Color subtleText;
  final Color border;
  final Color navigationBackground;
  final Color navigationIndicator;
  final Color accentSurface;
  final Color backgroundGradientStart;
  final Color backgroundGradientMiddle;
  final Color backgroundGradientEnd;
  final Color heroGradientStart;
  final Color heroGradientEnd;
  final Color mediaGradientStart;
  final Color mediaGradientEnd;
  final Color overlayMiniCard;

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? inputFill,
    Color? text,
    Color? mutedText,
    Color? subtleText,
    Color? border,
    Color? navigationBackground,
    Color? navigationIndicator,
    Color? accentSurface,
    Color? backgroundGradientStart,
    Color? backgroundGradientMiddle,
    Color? backgroundGradientEnd,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? mediaGradientStart,
    Color? mediaGradientEnd,
    Color? overlayMiniCard,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inputFill: inputFill ?? this.inputFill,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      border: border ?? this.border,
      navigationBackground: navigationBackground ?? this.navigationBackground,
      navigationIndicator: navigationIndicator ?? this.navigationIndicator,
      accentSurface: accentSurface ?? this.accentSurface,
      backgroundGradientStart:
          backgroundGradientStart ?? this.backgroundGradientStart,
      backgroundGradientMiddle:
          backgroundGradientMiddle ?? this.backgroundGradientMiddle,
      backgroundGradientEnd:
          backgroundGradientEnd ?? this.backgroundGradientEnd,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      mediaGradientStart: mediaGradientStart ?? this.mediaGradientStart,
      mediaGradientEnd: mediaGradientEnd ?? this.mediaGradientEnd,
      overlayMiniCard: overlayMiniCard ?? this.overlayMiniCard,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      border: Color.lerp(border, other.border, t)!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      navigationIndicator: Color.lerp(
        navigationIndicator,
        other.navigationIndicator,
        t,
      )!,
      accentSurface: Color.lerp(accentSurface, other.accentSurface, t)!,
      backgroundGradientStart: Color.lerp(
        backgroundGradientStart,
        other.backgroundGradientStart,
        t,
      )!,
      backgroundGradientMiddle: Color.lerp(
        backgroundGradientMiddle,
        other.backgroundGradientMiddle,
        t,
      )!,
      backgroundGradientEnd: Color.lerp(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
        t,
      )!,
      heroGradientStart: Color.lerp(
        heroGradientStart,
        other.heroGradientStart,
        t,
      )!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      mediaGradientStart: Color.lerp(
        mediaGradientStart,
        other.mediaGradientStart,
        t,
      )!,
      mediaGradientEnd: Color.lerp(
        mediaGradientEnd,
        other.mediaGradientEnd,
        t,
      )!,
      overlayMiniCard: Color.lerp(overlayMiniCard, other.overlayMiniCard, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appColors {
    return Theme.of(this).extension<AppThemeColors>()!;
  }
}
