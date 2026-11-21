import "dart:io";

import "package:flutter/material.dart";

import "package:flow/logging.dart";
import "package:flow/theme/color_themes/catppuccin/frappe.dart";
import "package:flow/theme/color_themes/catppuccin/macchiato.dart";
import "package:flow/theme/color_themes/catppuccin/mocha.dart";
import "package:flow/theme/color_themes/flow/flow_darks.dart";
import "package:flow/theme/color_themes/flow/flow_lights.dart";
import "package:flow/theme/color_themes/flow/flow_oleds.dart";
import "package:flow/theme/color_themes/monochrome.dart";
import "package:flow/theme/color_themes/palenight.dart";
import "package:flow/theme/flow_color_scheme.dart";
import "package:flow/theme/flow_theme_group.dart";
import "package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart";

export "catppuccin/frappe.dart";
export "catppuccin/macchiato.dart";
export "catppuccin/mocha.dart";
export "flow/flow_darks.dart";
export "flow/flow_lights.dart";
export "flow/flow_oleds.dart";
export "palenight.dart";
export "monochrome.dart";

final ledgerLight = FlowColorScheme(
  name: "ledgerLight",
  isDark: false,
  surface: const Color(0xFFFFFEFC),
  onSurface: const Color(0xFF252522),
  primary: const Color(0xFF875100),
  onPrimary: Colors.white,
  secondary: const Color(0xFFFFF5E3),
  onSecondary: const Color(0xFF5F3D09),
  base: ColorScheme.fromSeed(seedColor: const Color(0xFFF6B742)).copyWith(
    primaryContainer: const Color(0xFFFFD675),
    onPrimaryContainer: const Color(0xFF472D00),
    secondaryContainer: const Color(0xFFFFEBC2),
    onSecondaryContainer: const Color(0xFF5F3D09),
    surfaceContainerLow: const Color(0xFFFAF8F3),
    surfaceContainer: const Color(0xFFF6F3ED),
    surfaceContainerHigh: const Color(0xFFF1EEE8),
    onSurfaceVariant: const Color(0xFF625B50),
    outlineVariant: const Color(0xFFE6DED0),
  ),
  customColors: const FlowCustomColors(
    income: Color(0xFF256349),
    expense: Color(0xFF963C32),
    semi: Color(0xFF625B50),
  ),
);

final Map<String, FlowColorScheme> standaloneThemes = {
  "ledgerLight": ledgerLight,
  "palenight": palenight,
  "monochrome": monochrome,
};

final Map<String, List<FlowThemeGroup>> groups = {
  "Flow": [flowLights, flowDarks, flowOleds],
  "Catppuccin": [catppuccinFrappe, catppuccinMacchiato, catppuccinMocha],
};

final Map<String, FlowColorScheme> allThemes = {
  ...groups.values.fold(<String, FlowColorScheme>{}, (
    Map<String, FlowColorScheme> acc,
    List<FlowThemeGroup> groups,
  ) {
    for (final FlowThemeGroup group in groups) {
      acc.addAll(group.schemesMap);
    }

    return acc;
  }),
  ...standaloneThemes,
};

bool validateThemeName(String? themeName) {
  if (themeName == null) return false;

  return allThemes.containsKey(themeName);
}

FlowThemeGroup getGroupByTheme(String themeName) {
  try {
    return groups.values
        .expand((x) => x)
        .firstWhere(
          (group) => group.schemes.any((scheme) => scheme.name == themeName),
        );
  } catch (e) {
    return flowLights;
  }
}

FlowColorScheme? getThemeStrict(String? themeName) {
  return allThemes[themeName ?? ""];
}

FlowColorScheme getTheme(String? themeName, {bool preferDark = false}) {
  final FlowColorScheme? scheme = themeName == null
      ? null
      : allThemes[themeName];

  if (scheme == null) {
    themeLogger.warning("Unknown theme: $themeName", StackTrace.current);
    return preferDark ? flowDarks.schemes.first : ledgerLight;
  }

  return scheme;
}

/// Exclusive to iOS
void trySetAppIcon(String? iconName) async {
  if (!Platform.isIOS) return;

  iconName ??= "shadeOfViolet";

  final String? currentIcon = await FlutterDynamicIconPlus.alternateIconName;

  if (currentIcon != null && currentIcon == iconName) {
    themeLogger.fine(
      "Cancelling changing app icon into $iconName since it's the current one already",
    );
    return;
  }

  try {
    await FlutterDynamicIconPlus.setAlternateIconName(iconName: iconName);
  } catch (e) {
    themeLogger.warning("Failed to set app icon: $e");
  }
}
