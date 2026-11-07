import 'package:flutter/material.dart';

const String kMonoFont = 'RobotoMono';

@immutable
class PnColors extends ThemeExtension<PnColors> {
  const PnColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  @override
  PnColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
  }) => PnColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
  );

  @override
  PnColors lerp(ThemeExtension<PnColors>? other, double t) {
    if (other is! PnColors) return this;
    return PnColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7343C9),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEBDDFF),
    onPrimaryContainer: Color(0xFF26005B),
    secondary: Color(0xFF645A71),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFEADEF8),
    onSecondaryContainer: Color(0xFF1F182B),
    tertiary: Color(0xFF00696E),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFA2F0F4),
    onTertiaryContainer: Color(0xFF002022),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFDF7FF),
    surfaceDim: Color(0xFFDED8E1),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F1FA),
    surfaceContainer: Color(0xFFF2ECF4),
    surfaceContainerHigh: Color(0xFFECE6EE),
    surfaceContainerHighest: Color(0xFFE6E0E9),
    onSurface: Color(0xFF1D1B20),
    onSurfaceVariant: Color(0xFF4A4551),
    outline: Color(0xFF7B7582),
    outlineVariant: Color(0xFFCCC4D2),
    inverseSurface: Color(0xFF322F35),
    onInverseSurface: Color(0xFFF5EFF7),
    inversePrimary: Color(0xFFD4BBFF),
    scrim: Color(0x52000000),
    shadow: Color(0x2E000000),
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD4BBFF),
    onPrimary: Color(0xFF3F0F90),
    primaryContainer: Color(0xFF5729AF),
    onPrimaryContainer: Color(0xFFEBDDFF),
    secondary: Color(0xFFCEC2DC),
    onSecondary: Color(0xFF352D41),
    secondaryContainer: Color(0xFF4C4358),
    onSecondaryContainer: Color(0xFFEADEF8),
    tertiary: Color(0xFF4FD8DE),
    onTertiary: Color(0xFF00373A),
    tertiaryContainer: Color(0xFF004F53),
    onTertiaryContainer: Color(0xFFA2F0F4),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF141218),
    surfaceDim: Color(0xFF141218),
    surfaceContainerLowest: Color(0xFF0F0D13),
    surfaceContainerLow: Color(0xFF1D1B21),
    surfaceContainer: Color(0xFF211F26),
    surfaceContainerHigh: Color(0xFF2B2930),
    surfaceContainerHighest: Color(0xFF36343B),
    onSurface: Color(0xFFE7E0E9),
    onSurfaceVariant: Color(0xFFCCC4D2),
    outline: Color(0xFF958E9C),
    outlineVariant: Color(0xFF4A4551),
    inverseSurface: Color(0xFFE7E0E9),
    onInverseSurface: Color(0xFF322F35),
    inversePrimary: Color(0xFF7343C9),
    scrim: Color(0x80000000),
    shadow: Color(0x80000000),
  );

  static const _lightSuccess = PnColors(
    success: Color(0xFF336A2B),
    successContainer: Color(0xFFB5F2A3),
    onSuccessContainer: Color(0xFF032100),
  );

  static const _darkSuccess = PnColors(
    success: Color(0xFF9AD688),
    successContainer: Color(0xFF1B5115),
    onSuccessContainer: Color(0xFFB5F2A3),
  );

  static ThemeData light() => _build(_light, _lightSuccess);
  static ThemeData dark() => _build(_dark, _darkSuccess);

  static ThemeData _build(ColorScheme scheme, PnColors success) {
    const pill = StadiumBorder();
    return ThemeData(
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: 'RobotoFlex',
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      extensions: [success],
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w400,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: 0.25,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
    );
  }
}
