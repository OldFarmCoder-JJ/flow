import "package:flow/prefs/local_preferences.dart";
import "package:flow/theme/ledger_appearance.dart";
import "package:flutter/material.dart";

/// Changes the ledger appearance immediately and remembers it on this device.
class ThemePreferencesPage extends StatelessWidget {
  const ThemePreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final preference = LocalPreferences().ledgerAppearance;
    return Scaffold(
      appBar: AppBar(title: const Text("外观")),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: preference.valueNotifier,
          builder: (context, _) => RadioGroup<LedgerAppearance>(
            groupValue: LedgerAppearance.fromName(preference.value),
            onChanged: (value) {
              if (value != null) preference.set(value.name);
            },
            child: ListView(
              children: [
                const ListTile(title: Text("显示模式")),
                for (final option in LedgerAppearance.values)
                  RadioListTile<LedgerAppearance>(
                    value: option,
                    title: Text(option.label),
                    subtitle: option == LedgerAppearance.automatic
                        ? const Text("20:00 切换深色，次日 07:00 恢复浅色")
                        : null,
                  ),
                const Divider(),
                const ListTile(title: Text("主题配色")),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListenableBuilder(
                    listenable: LocalPreferences().ledgerPalette.valueNotifier,
                    builder: (context, _) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final palette in LedgerPalette.values)
                          ChoiceChip(
                            label: Text(palette.label),
                            avatar: CircleAvatar(backgroundColor: palette.seed),
                            selected:
                                LedgerPalette.fromName(
                                  LocalPreferences().ledgerPalette.value,
                                ) ==
                                palette,
                            onSelected: (_) => LocalPreferences().ledgerPalette
                                .set(palette.name),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
