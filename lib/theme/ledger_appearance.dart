import "package:flutter/material.dart";

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
