import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primarySoft,
      onSecondaryContainer: c.primary,
      tertiary: c.success,
      onTertiary: c.onPrimary,
      error: c.danger,
      onError: c.onPrimary,
      surface: c.surfaceRaised,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surfaceRaised,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.inkMuted,
      outlineVariant: c.border,
      inverseSurface: c.ink,
      onInverseSurface: c.surface,
      inversePrimary: c.primarySoft,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
    );

    final textTheme = _textTheme(c);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonSize = Size(64, 48);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      textTheme: textTheme,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surfaceRaised,
      dividerColor: c.border,
      iconTheme: IconThemeData(color: c.ink, size: 24),

      appBarTheme: AppBarTheme(
        backgroundColor: c.hero,
        foregroundColor: c.onHero,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: c.onHero),
        iconTheme: IconThemeData(color: c.onHero),
        actionsIconTheme: IconThemeData(color: c.onHero),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(buttonShape),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpace.s6)),
          textStyle: WidgetStatePropertyAll(textTheme.titleMedium),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return c.primary.withValues(alpha: 0.45);
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return c.primaryStrong;
            }
            return c.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.disabled)
                  ? c.onPrimary.withValues(alpha: 0.8)
                  : c.onPrimary),
          iconColor: WidgetStatePropertyAll(c.onPrimary),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary),
          textStyle: textTheme.titleMedium,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          shape: buttonShape,
          textStyle: textTheme.titleMedium,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4, vertical: 14),
        border: inputBorder(c.inkMuted),
        enabledBorder: inputBorder(c.inkMuted),
        focusedBorder: inputBorder(c.primary, 2),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger, 2),
        labelStyle: textTheme.bodyLarge?.copyWith(color: c.inkMuted),
        floatingLabelStyle: textTheme.bodyLarge?.copyWith(color: c.primary),
        hintStyle: textTheme.bodyLarge?.copyWith(color: c.inkMuted),
        prefixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.focused) ? c.primary : c.inkMuted),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: c.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink,
        textColor: c.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.primarySoft,
        disabledColor: c.surfaceRaised,
        labelStyle: textTheme.bodyMedium?.copyWith(color: c.ink),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(color: c.primary),
        side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? c.primarySoft
                : c.border)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.primary,
        headerForegroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }

  static TextTheme _textTheme(AppColors c) {
    TextStyle style(double size, double lineHeight, FontWeight weight,
            [double letterSpacingEm = 0]) =>
        TextStyle(
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          letterSpacing: letterSpacingEm * size,
          color: c.ink,
        );

    final display = style(30, 36, FontWeight.w600, -0.02);
    final title = style(20, 28, FontWeight.w600, -0.01);
    final subtitle = style(16, 24, FontWeight.w500);
    final body = style(15, 22, FontWeight.w400);
    final caption =
        style(13, 18, FontWeight.w400).copyWith(color: c.inkMuted);
    final label = style(12, 16, FontWeight.w500);

    return GoogleFonts.geistTextTheme(
      TextTheme(
        displayLarge: display,
        displayMedium: display,
        displaySmall: display,
        headlineLarge: display,
        headlineMedium: display,
        headlineSmall: title,
        titleLarge: title,
        titleMedium: subtitle,
        titleSmall: subtitle,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: subtitle,
        labelMedium: label,
        labelSmall: label,
      ),
    );
  }
}
