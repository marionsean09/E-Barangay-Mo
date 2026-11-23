import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.onPrimary,
    required this.success,
    required this.danger,
    required this.hero,
    required this.heroDeep,
    required this.heroBright,
    required this.heroSoft,
    required this.onHero,
    required this.onHeroMuted,
    required this.cardShadow,
  });

  final Color surface;

  final Color surfaceRaised;

  final Color ink;

  final Color inkMuted;

  final Color border;

  final Color primary;

  final Color primaryStrong;

  final Color primarySoft;

  final Color onPrimary;

  final Color success;

  final Color danger;

  final Color hero;
  final Color heroDeep;

  final Color heroBright;
  final Color heroSoft;

  final Color onHero;
  final Color onHeroMuted;

  final List<BoxShadow> cardShadow;

  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hero, heroDeep],
      );

  static const light = AppColors(
    surface: Color(0xFFFCEEF0),
    surfaceRaised: Color(0xFFFFF8F9),
    ink: Color(0xFF2A0A10),
    inkMuted: Color(0xFF7C3F4A),
    border: Color(0xFFF2CDD4),
    primary: Color(0xFFC8102E),
    primaryStrong: Color(0xFF8F0A20),
    primarySoft: Color(0xFFFBE3E7),
    onPrimary: Color(0xFFFFF5F6),
    success: Color(0xFF18704A),
    danger: Color(0xFFB45309),
    hero: Color(0xFFA30D26),
    heroDeep: Color(0xFF5C0716),
    heroBright: Color(0xFFE23A55),
    heroSoft: Color(0xFFF6C3CB),
    onHero: Color(0xFFFFF5F6),
    onHeroMuted: Color(0xFFF6C3CB),
    cardShadow: [
      BoxShadow(
          color: Color(0x145C0716), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(
          color: Color(0x0F5C0716), offset: Offset(0, 4), blurRadius: 16),
    ],
  );

  static const dark = AppColors(
    surface: Color(0xFF17070A),
    surfaceRaised: Color(0xFF240B10),
    ink: Color(0xFFFDEEF0),
    inkMuted: Color(0xFFD29BA5),
    border: Color(0xFF401820),
    primary: Color(0xFFFF5C72),
    primaryStrong: Color(0xFFFF8A9A),
    primarySoft: Color(0xFF4A1520),
    onPrimary: Color(0xFF1A0609),
    success: Color(0xFF5FCB95),
    danger: Color(0xFFF5A524),
    hero: Color(0xFF7A0A1C),
    heroDeep: Color(0xFF2E050C),
    heroBright: Color(0xFFC8102E),
    heroSoft: Color(0xFF4A1520),
    onHero: Color(0xFFFFF1F3),
    onHeroMuted: Color(0xFFF2B3BD),
    cardShadow: [
      BoxShadow(
          color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? border,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? onPrimary,
    Color? success,
    Color? danger,
    Color? hero,
    Color? heroDeep,
    Color? heroBright,
    Color? heroSoft,
    Color? onHero,
    Color? onHeroMuted,
    List<BoxShadow>? cardShadow,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      hero: hero ?? this.hero,
      heroDeep: heroDeep ?? this.heroDeep,
      heroBright: heroBright ?? this.heroBright,
      heroSoft: heroSoft ?? this.heroSoft,
      onHero: onHero ?? this.onHero,
      onHeroMuted: onHeroMuted ?? this.onHeroMuted,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      border: l(border, other.border),
      primary: l(primary, other.primary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      hero: l(hero, other.hero),
      heroDeep: l(heroDeep, other.heroDeep),
      heroBright: l(heroBright, other.heroBright),
      heroSoft: l(heroSoft, other.heroSoft),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
