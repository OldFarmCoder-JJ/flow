import "dart:io";

import "package:flow/data/flow_icon.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/legacy_shark_entry.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/graceful_migrations.dart";
import "package:flow/l10n/flow_localizations.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/providers/transaction_tags_provider.dart";
import "package:flow/routes/home/stats_tab.dart";
import "package:flow/routes/transaction_page.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/theme.dart";
import "package:flow/widgets/sheets/select_category_sheet.dart";
import "package:flow/widgets/transaction_list_tile.dart";
import "package:flow/widgets/transaction_list_tile_theme.dart";
import "package:flutter/foundation.dart" show SynchronousFuture;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ObjectBox db;
  late Account legacy;
  late Account wallet;
  late Category shopping;
  late Category clothes;
  late Category custom;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp("ledger-legacy-");
    db = await ObjectBox.initialize(customDirectory: directory.path);
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await LocalPreferences.initialize();
    await FlowLocalizations(const Locale("en")).load();
    legacy = Account(
      name: legacySharkAccountName,
      currency: "CNY",
      iconCode: "",
    );
    wallet = Account(name: "钱包", currency: "CNY", iconCode: "");
    final generic = const IconFlowIcon(Symbols.category_rounded).toString();
    shopping = Category(name: "购物", iconCode: generic);
    clothes = Category(name: "服饰", iconCode: generic);
    custom = Category(
      name: "通讯",
      iconCode: FlowIconData.emoji("📱").toString(),
    );
    db.box<Account>().putMany([legacy, wallet]);
    db.box<Category>().putMany([shopping, clothes, custom]);
  });

  tearDownAll(() async {
    db.store.close();
    await directory.delete(recursive: true);
  });

  Widget providers(Widget child) => AccountsProvider(
    [legacy, wallet],
    child: CategoriesProvider([
      shopping,
      clothes,
      custom,
    ], child: TransactionTagsProvider(const [], child: child)),
  );

  testWidgets("old entry name survives editing and reopening its category", (
    tester,
  ) async {
    final id = legacy.createAndSaveTransaction(
      amount: -350,
      title: shopping.name,
      description: "测试电源",
      category: shopping,
    );
    final actualMemo = wallet.createAndSaveTransaction(
      amount: -5,
      title: shopping.name,
      description: "配送说明",
      category: shopping,
    );
    final longerMemo = legacy.createAndSaveTransaction(
      amount: -5,
      title: shopping.name,
      description: "原备注\n保留第二行",
      category: shopping,
    );
    expect(repairLegacySharkEntryNames(), 1);
    expect(repairLegacySharkEntryNames(), 0);
    expect(db.box<Transaction>().get(actualMemo)?.description, "配送说明");
    expect(db.box<Transaction>().get(longerMemo)?.description, contains("\n"));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => Scaffold(
            body: TransactionListTile(
              transaction: db.box<Transaction>().get(id)!,
              recoverFromTrashFn: null,
              moveToTrashFn: null,
              combineTransfers: false,
              theme: const TransactionListTileThemeData(showCategory: true),
            ),
          ),
        ),
        GoRoute(
          path: "/transaction/:id",
          builder: (context, state) => TransactionPage.edit(transactionId: id),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeFactory(ledgerLight).materialTheme,
        supportedLocales: const [Locale("en")],
        localizationsDelegates: const [_LoadedLocale()],
        builder: (_, child) => providers(child!),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    final visibleName = find.text("测试电源", findRichText: true);
    expect(visibleName, findsOneWidget);
    expect(find.textContaining("购物", findRichText: true), findsOneWidget);
    await tester.tap(visibleName);
    await tester.pumpAndSettle();
    expect(find.text("测试电源"), findsOneWidget);
    await tester.tap(find.text("购物"));
    await tester.pumpAndSettle();
    final picker = find.byType(SelectCategorySheet);
    expect(picker, findsOneWidget);
    final clothingTile = find.widgetWithText(ListTile, "服饰");
    expect(
      find.descendant(
        of: clothingTile,
        matching: find.byIcon(Icons.checkroom_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text("📱", findRichText: true), findsOneWidget);
    await tester.tap(clothingTile);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, "服饰"),
        matching: find.byIcon(Icons.checkroom_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip("Save"));
    await tester.pumpAndSettle();
    final saved = db.box<Transaction>().get(id)!;
    expect(saved.category.target?.uuid, clothes.uuid);
    expect(saved.title, "测试电源");
    expect(saved.amount, -350);
    await tester.tap(visibleName);
    await tester.pumpAndSettle();
    expect(find.text("服饰"), findsOneWidget);
    expect(find.byIcon(Icons.checkroom_outlined), findsOneWidget);
  });

  testWidgets("empty month points to the populated month in the prior year", (
    tester,
  ) async {
    final now = DateTime.now();
    final selected = DateTime(now.year, now.month - 2);
    final priorYear = DateTime(selected.year - 1, selected.month);
    wallet.createAndSaveTransaction(
      amount: -27.85,
      category: shopping,
      transactionDate: priorYear.add(const Duration(days: 9)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeFactory(ledgerLight).materialTheme,
        builder: (_, child) => providers(child!),
        home: const Scaffold(body: StatsTab()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("更早"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("更早"));
    await tester.pumpAndSettle();
    String label(DateTime date) => LedgerInterval.month.fullLabel(date);
    expect(find.text("${label(selected)}暂无支出"), findsOneWidget);
    await tester.tap(find.text("查看${label(priorYear)}"));
    await tester.pumpAndSettle();
    expect(find.text(label(priorYear)), findsOneWidget);
    expect(find.text("总支出"), findsOneWidget);
    expect(find.text("27.85", findRichText: true), findsAtLeastNWidgets(1));
    await tester.tap(find.text("分类占比"));
    await tester.pumpAndSettle();
    expect(find.text("收支趋势"), findsOneWidget);
    expect(find.text("27.85", findRichText: true), findsAtLeastNWidgets(1));
  });
}

class _LoadedLocale extends LocalizationsDelegate<FlowLocalizations> {
  const _LoadedLocale();

  @override
  bool isSupported(Locale locale) => locale.languageCode == "en";

  @override
  Future<FlowLocalizations> load(Locale locale) =>
      SynchronousFuture(FlowLocalizations(locale));

  @override
  bool shouldReload(_LoadedLocale old) => false;
}
