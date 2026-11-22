import "dart:io";

import "package:flow/l10n/extensions.dart";

import "package:flow/routes/ledger_analysis_page.dart";
import "package:flow/routes/preferences/app_update_page.dart";
import "package:flow/routes/preferences/sections/lock_app.dart";
import "package:flow/services/local_auth.dart";
import "package:flow/services/notifications.dart";
import "package:flow/widgets/general/directional_chevron.dart";
import "package:flutter/material.dart" hide Flow;
import "package:go_router/go_router.dart";
import "package:logging/logging.dart";

final Logger _log = Logger("PreferencesPage");

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => PreferencesPageState();

  static PreferencesPageState of(BuildContext context) {
    return context.findAncestorStateOfType<PreferencesPageState>()!;
  }
}

class PreferencesPageState extends State<PreferencesPage> {
  bool _showLockApp = false;

  @override
  void initState() {
    super.initState();

    LocalAuthService.initialize()
        .then((_) {
          _showLockApp = LocalAuthService.available;

          if (mounted) {
            setState(() {});
          }
        })
        .catchError((_) {
          _log.warning("Failed to initialize local auth service");
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("preferences".t(context))),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text("sync.export.asCSV".t(context)),
              onTap: () => context.push("/export/csv"),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text("tabs.profile.backup".t(context)),
              onTap: () => context.push("/exportOptions"),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text("AI 账本分析"),
              subtitle: const Text("按月汇总，复制或分享给 ChatGPT"),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LedgerAnalysisPage(),
                ),
              ),
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text("应用更新"),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppUpdatePage(),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text("外观"),
              trailing: const LeChevron(),
              onTap: () => context.push("/preferences/theme"),
            ),
            if (NotificationsService.schedulingSupported)
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: Text("preferences.reminders".t(context)),
                onTap: () => context.push("/preferences/reminders"),
              ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text("管理账户"),
              onTap: () => context.push("/accounts"),
            ),
            if (_showLockApp) const LockApp(),
          ],
        ),
      ),
    );
  }

  void reload() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }
}
