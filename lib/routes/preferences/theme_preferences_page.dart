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
                for (final option in LedgerAppearance.values)
                  RadioListTile<LedgerAppearance>(
                    value: option,
                    title: Text(option.label),
                    subtitle: option == LedgerAppearance.automatic
                        ? const Text("20:00 切换深色，次日 07:00 恢复浅色")
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
