part of '../../main.dart';

ThemeData buildAppTheme(Brightness brightness) {
  const seed = _appAccent;
  final isDark = brightness == Brightness.dark;
  final colors = isDark
      ? const AppThemeColors.dark()
      : const AppThemeColors.light();

  final generatedScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    surface: colors.surface,
  );
  final scheme = isDark
      ? generatedScheme
      : generatedScheme.copyWith(
          primary: seed,
          onPrimary: Colors.white,
          primaryContainer: colors.accentSurface,
          onPrimaryContainer: colors.text,
          secondary: const Color(0xFF1473E6),
          onSecondary: Colors.white,
          surface: colors.surface,
          onSurface: colors.text,
          onSurfaceVariant: colors.mutedText,
          outline: colors.border,
          outlineVariant: colors.border,
          surfaceContainerLowest: colors.surface,
          surfaceContainerLow: colors.surface,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.surfaceRaised,
          surfaceContainerHighest: colors.surfaceRaised,
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
    canvasColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: colors.text,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      hintStyle: TextStyle(color: colors.subtleText),
      labelStyle: TextStyle(color: colors.mutedText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDark
            ? BorderSide.none
            : BorderSide(color: colors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: seed, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navigationBackground,
      indicatorColor: colors.navigationIndicator,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? seed : colors.mutedText,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? seed
              : colors.mutedText,
        );
      }),
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: isDark ? 0 : 5,
      shadowColor: isDark ? Colors.transparent : const Color(0x1A09152F),
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: IconThemeData(color: colors.text),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: colors.text,
      textColor: colors.text,
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
          return states.contains(WidgetState.selected) ? seed : colors.surface;
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
      surfaceTintColor: Colors.transparent,
      shadowColor: isDark ? Colors.transparent : const Color(0x1A09152F),
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide.none : BorderSide(color: colors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      elevation: isDark ? 3 : 6,
      shape: const CircleBorder(),
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
        subtleText: const Color(0xFF8A93B4),
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
        background: const Color(0xFFFAFBFD),
        surface: const Color(0xFFFFFFFF),
        surfaceRaised: const Color(0xFFFFF7F3),
        inputFill: const Color(0xFFFFFFFF),
        text: const Color(0xFF07152F),
        mutedText: const Color(0xFF596176),
        subtleText: const Color(0xFF747B8D),
        border: const Color(0xFFE4E6EB),
        navigationBackground: const Color(0xFFFFFFFF),
        navigationIndicator: const Color(0xFFFFEDE6),
        accentSurface: const Color(0xFFFFEEE8),
        backgroundGradientStart: const Color(0xFFFFFFFF),
        backgroundGradientMiddle: const Color(0xFFFCFCFD),
        backgroundGradientEnd: const Color(0xFFF7F8FB),
        heroGradientStart: const Color(0xFFFFFFFF),
        heroGradientEnd: const Color(0xFFFFF2ED),
        mediaGradientStart: const Color(0xFFF0F2F6),
        mediaGradientEnd: const Color(0xFFFFFFFF),
        overlayMiniCard: const Color(0x0F07152F),
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
