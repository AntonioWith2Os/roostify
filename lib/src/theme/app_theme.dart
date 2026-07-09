part of '../../main.dart';

ThemeData buildAppTheme(Brightness brightness) {
  const seed = _appAccent;
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
  final textTheme = baseTextTheme.textTheme.apply(
    bodyColor: colors.text,
    displayColor: colors.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: colors.text,
      titleTextStyle: TextStyle(
        color: colors.text,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      hintStyle: TextStyle(color: colors.subtleText),
      labelStyle: TextStyle(color: colors.mutedText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: seed, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navigationBackground,
      indicatorColor: colors.navigationIndicator,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.text
              : colors.mutedText,
          fontWeight: FontWeight.w800,
        );
      }),
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
              ? Colors.white
              : colors.mutedText;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const BorderSide(color: seed)
              : BorderSide(color: colors.border);
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? seed
              : colors.surface;
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: WidgetStateProperty.all(const StadiumBorder()),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border, width: 1.4),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seed,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
        navigationIndicator: const Color(0xFF3E241C),
        accentSurface: const Color(0xFF3E241C),
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
        background: const Color(0xFFF6F5F2),
        surface: const Color(0xFFFFFFFF),
        surfaceRaised: const Color(0xFFF3F1ED),
        inputFill: const Color(0xFFF3F1ED),
        text: const Color(0xFF17191E),
        mutedText: const Color(0xFF6B7076),
        subtleText: const Color(0xFF9AA0A6),
        border: const Color(0xFFE8E5E0),
        navigationBackground: const Color(0xFFFFFFFF),
        navigationIndicator: const Color(0xFFFFE3DB),
        accentSurface: const Color(0xFFFFE3DB),
        backgroundGradientStart: const Color(0xFFF9F8F5),
        backgroundGradientMiddle: const Color(0xFFF6F5F2),
        backgroundGradientEnd: const Color(0xFFF2F0EC),
        heroGradientStart: const Color(0xFFFFFFFF),
        heroGradientEnd: const Color(0xFFFFF0EB),
        mediaGradientStart: const Color(0xFFECE9E4),
        mediaGradientEnd: const Color(0xFFFFFFFF),
        overlayMiniCard: const Color(0x0F17191E),
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
