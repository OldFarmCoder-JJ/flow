import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/flow_color_scheme.dart";
import "package:flutter/material.dart";

/// Accent families with coordinated daylight and evening surfaces.
enum LedgerPalette {
  mint("薄荷青", Color(0xff006d5b)),
  ocean("海盐蓝", Color(0xff376aa0)),
  lilac("鸢尾紫", Color(0xff795799)),
  amber("琥珀茶", Color(0xff95652d)),
  rose("山茶红", Color(0xffa34f66));

  const LedgerPalette(this.label, this.seed);
  final String label;
  final Color seed;

  static LedgerPalette fromName(String? name) =>
      values.firstWhere((p) => p.name == name, orElse: () => mint);

  FlowColorScheme scheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final original = dark ? ledgerDark : ledgerLight;
    if (this == mint) return original;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return FlowColorScheme(
      name: "${name}_${brightness.name}",
      isDark: dark,
      surface: base.surface,
      onSurface: base.onSurface,
      primary: base.primary,
      onPrimary: base.onPrimary,
      secondary: base.surfaceContainer,
      onSecondary: base.onSurface,
      base: base,
      customColors: original.customColors,
    );
  }
}

/// Display choices for the personal ledger, using the device's local time.
enum LedgerAppearance {
  automatic("夜间自动"),
  light("浅色"),
  dark("深色");

  const LedgerAppearance(this.label);
  final String label;

  /// Restored or unrecognized values use the day/night schedule.
  static LedgerAppearance fromName(String? name) =>
      values.firstWhere((value) => value.name == name, orElse: () => automatic);

  /// Applies dark colors from 20:00 up to, but excluding, 07:00.
  ThemeMode modeAt(DateTime now) => switch (this) {
    light => ThemeMode.light,
    dark => ThemeMode.dark,
    automatic =>
      now.hour < 7 || now.hour >= 20 ? ThemeMode.dark : ThemeMode.light,
  };

  /// Next local calendar boundary, including when a clock change occurs overnight.
  DateTime nextBoundary(DateTime now) {
    if (now.hour < 7) return DateTime(now.year, now.month, now.day, 7);
    if (now.hour < 20) return DateTime(now.year, now.month, now.day, 20);
    return DateTime(now.year, now.month, now.day + 1, 7);
  }
}
