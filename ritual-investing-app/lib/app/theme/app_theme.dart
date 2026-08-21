import 'package:flutter/material.dart';

@immutable
class RitualColors extends ThemeExtension<RitualColors> {
  const RitualColors({
    required this.page,
    required this.screen,
    required this.screenSoft,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.primarySoft,
    required this.gold,
    required this.goldSoft,
    required this.line,
    required this.positive,
    required this.coven,
  });

  static const light = RitualColors(
    page: Color(0xFFFDEEFD),
    screen: Color(0xFFFFF9FF),
    screenSoft: Color(0xFFF7E4F9),
    ink: Color(0xFF260F2E),
    muted: Color(0xFF6A5570),
    faint: Color(0xFF908094),
    primarySoft: Color(0xFFDFB4DE),
    gold: Color(0xFFC6944F),
    goldSoft: Color(0xFFEED3AC),
    line: Color(0xFFDDC4DF),
    positive: Color(0xFF2A6732),
    coven: Color(0xFF4C174F),
  );

  static const dark = RitualColors(
    page: Color(0xFF0B0310),
    screen: Color(0xFF15061A),
    screenSoft: Color(0xFF220C28),
    ink: Color(0xFFF6ECF7),
    muted: Color(0xFFBDA4C2),
    faint: Color(0xFF907B94),
    primarySoft: Color(0xFF451D4A),
    gold: Color(0xFFECB667),
    goldSoft: Color(0xFF3D2600),
    line: Color(0xFF3F2545),
    positive: Color(0xFF86BE8A),
    coven: Color(0xFF321036),
  );

  final Color page;
  final Color screen;
  final Color screenSoft;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color primarySoft;
  final Color gold;
  final Color goldSoft;
  final Color line;
  final Color positive;
  final Color coven;

  @override
  RitualColors copyWith({
    Color? page,
    Color? screen,
    Color? screenSoft,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? primarySoft,
    Color? gold,
    Color? goldSoft,
    Color? line,
    Color? positive,
    Color? coven,
  }) {
    return RitualColors(
      page: page ?? this.page,
      screen: screen ?? this.screen,
      screenSoft: screenSoft ?? this.screenSoft,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      primarySoft: primarySoft ?? this.primarySoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      line: line ?? this.line,
      positive: positive ?? this.positive,
      coven: coven ?? this.coven,
    );
  }

  @override
  RitualColors lerp(covariant RitualColors? other, double t) {
    if (other == null) return this;
    return RitualColors(
      page: Color.lerp(page, other.page, t)!,
      screen: Color.lerp(screen, other.screen, t)!,
      screenSoft: Color.lerp(screenSoft, other.screenSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      coven: Color.lerp(coven, other.coven, t)!,
    );
  }
}

extension RitualThemeContext on BuildContext {
  RitualColors get ritualColors => Theme.of(this).extension<RitualColors>()!;
}

abstract final class AppTheme {
  static ThemeData get light => _build(
    colors: RitualColors.light,
    brightness: Brightness.light,
    primary: const Color(0xFF641D6F),
    onPrimary: Colors.white,
  );

  static ThemeData get dark => _build(
    colors: RitualColors.dark,
    brightness: Brightness.dark,
    primary: const Color(0xFFDD94D4),
    onPrimary: const Color(0xFF25092A),
  );

  static ThemeData _build({
    required RitualColors colors,
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: colors.gold,
      onSecondary: const Color(0xFF271805),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: colors.screen,
      onSurface: colors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.page,
      extensions: [colors],
      dividerColor: colors.line,
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: colors.ink,
          fontFamily: 'LibreBaskerville',
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          color: colors.ink,
          fontFamily: 'LibreBaskerville',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.08,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: colors.ink,
          fontFamily: 'LibreBaskerville',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        titleMedium: TextStyle(
          color: colors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        bodyLarge: TextStyle(color: colors.ink, fontSize: 17, height: 1.45),
        bodyMedium: TextStyle(color: colors.muted, fontSize: 15, height: 1.45),
        labelLarge: TextStyle(
          color: colors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.screen,
        indicatorColor: colors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : colors.faint,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : colors.faint,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.screenSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.screen,
        modalBackgroundColor: colors.screen,
        showDragHandle: true,
      ),
    );
  }
}
