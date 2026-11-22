import "package:flow/data/monthly_reserve.dart";
import "package:flow/routes/home/spending_room_tab.dart";
import "package:flow/data/dining_expense_emoji.dart";
import "package:flow/routes/preferences/theme_preferences_page.dart";
import "package:flow/theme/ledger_appearance.dart";
import "package:flow/widgets/transactions_date_header.dart";
import "package:moment_dart/moment_dart.dart";
import "package:flow/routes/home/home_tab.dart";
import "package:flow/routes/quick_entry_page.dart";
import "package:flow/widgets/home/ledger_flow_summary.dart";
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

  test("automatic appearance switches at local calendar boundaries", () {
    const auto = LedgerAppearance.automatic;
    final evening = DateTime(2026, 12, 31, 20);
    final morning = DateTime(2027, 1, 1, 7);
    expect(
      auto.modeAt(evening.subtract(const Duration(seconds: 1))),
      ThemeMode.light,
    );
    expect(auto.modeAt(evening), ThemeMode.dark);
    expect(auto.nextBoundary(evening), morning);
    expect(
      auto.modeAt(morning.subtract(const Duration(seconds: 1))),
      ThemeMode.dark,
    );
    expect(auto.modeAt(morning), ThemeMode.light);
    expect(auto.nextBoundary(morning), DateTime(2027, 1, 1, 20));
    expect(LedgerAppearance.dark.modeAt(morning), ThemeMode.dark);
    expect(LedgerAppearance.light.modeAt(evening), ThemeMode.light);
    expect(LedgerAppearance.fromName(null), auto);
    expect(ThemeFactory(ledgerDark).materialTheme.brightness, Brightness.dark);
  });

  testWidgets("appearance picker persists and restores the chosen mode", (
    tester,
  ) async {
    final pref = LocalPreferences().ledgerAppearance;
    await tester.pumpWidget(const MaterialApp(home: ThemePreferencesPage()));
    await tester.tap(find.text("深色"));
    await tester.pumpAndSettle();
    expect(pref.value, "dark");
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: ThemePreferencesPage()));
    expect(
      tester
          .widget<RadioGroup<LedgerAppearance>>(
            find.byType(RadioGroup<LedgerAppearance>),
          )
          .groupValue,
      LedgerAppearance.dark,
    );
    await tester.tap(find.text("夜间自动"));
    await tester.pumpAndSettle();
    expect(pref.value, "automatic");
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

  testWidgets(
    "spendable balance deducts each yuan only once and persists by month",
    (tester) async {
      final now = DateTime.now();
      final ids = [
        legacy.createAndSaveTransaction(amount: 1000),
        legacy.createAndSaveTransaction(amount: -150, category: shopping),
        wallet.createAndSaveTransaction(amount: -80, category: clothes),
      ];
      final pref = LocalPreferences().monthlyReservePlan(now);
      await pref.set(
        MonthlyReserve(savings: 10000, limits: {shopping.uuid: 20000}).encode(),
      );
      addTearDown(() async {
        db.box<Transaction>().removeMany(ids);
        await pref.remove();
      });
      await tester.pumpWidget(
        MaterialApp(home: providers(const Scaffold(body: SpendingRoomTab()))),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text("¥ 620.00"), findsOneWidget);
      expect(find.text("待付 50.00"), findsOneWidget);
      await tester.tap(find.text("储蓄目标"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), "250");
      await tester.tap(find.text("保存"));
      await tester.pumpAndSettle();
      expect(find.text("¥ 470.00"), findsOneWidget);
      expect(
        MonthlyReserve.decode(
          LocalPreferences().monthlyReservePlan(now).value,
        ).savings,
        25000,
      );
      await tester.tap(find.byTooltip("上个月"));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text("¥ 0.00"), findsOneWidget);
    },
  );

  testWidgets(
    "today groups settled expenses by category and respects privacy",
    (tester) async {
      final now = DateTime.now();
      final meal = Category(name: "餐饮", iconCode: "");
      db.box<Category>().put(meal);
      addTearDown(() => db.box<Category>().remove(meal.id));
      var sequence = 0;
      Transaction entry(
        double amount,
        Category category, {
        bool pending = false,
      }) => Transaction(
        uuid: "day-group-${sequence++}",
        amount: amount,
        currency: "CNY",
        transactionDate: now,
        isPending: pending,
      )..category.target = category;
      final rows = [
        for (final amount in [-16.8, -12.0, -15.0, -15.0]) entry(amount, meal),
        entry(-5, shopping),
        entry(100, meal),
        entry(-100, meal, pending: true),
      ];
      final box = db.box<Transaction>();
      final ids = box.putMany(rows);
      final stored = ids.map((id) => box.get(id)!).toList();
      addTearDown(() => box.removeMany(ids));
      final privacy = TransitiveLocalPreferences().sessionPrivacyMode;
      await privacy.set(false);
      Future<void> render(DateTime date) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeFactory(ledgerLight).materialTheme,
          localizationsDelegates: const [_LoadedLocale()],
          home: Scaffold(
            body: TransactionListDateHeader(
              range: DayTimeRange.fromDateTime(date),
              transactions: stored,
              showTodaySpending: true,
              titleOverride: const Text("日期"),
            ),
          ),
        ),
      );
      await render(now);
      final dining = find.text("● 餐饮 58.80", findRichText: true);
      expect(dining, findsOneWidget);
      expect(find.text("● 购物 5.00", findRichText: true), findsOneWidget);
      await privacy.set(true);
      await tester.pump();
      expect(dining, findsNothing);
      await privacy.set(false);
      await render(DateTime(now.year, now.month, now.day - 1));
      expect(dining, findsNothing);
    },
  );
  test("dining glyphs distinguish dishes, shops, and vague meal labels", () {
    for (final entry in {
      "早餐麦当劳": "🍔",
      "早餐鸡蛋": "🥚",
      "德克士": "🍔",
      "冒烤鸭": "🦆",
      "早餐阳春面": "🍜",
      "麦当劳薯条": "🍟",
      "汉堡王鸡蛋": "🥚",
      "晚餐🥚": "🥚",
    }.entries) {
      expect(
        diningExpenseEmoji("餐饮", entry.key),
        entry.value,
        reason: entry.key,
      );
    }
    expect(diningExpenseEmoji("购物", "鸡蛋"), isNull);
    expect(diningExpenseEmoji("餐饮", "午餐"), isNull);
    expect(diningExpenseEmoji("餐饮", null), isNull);
  });

  testWidgets("saved dining rows change their glyph when renamed", (
    tester,
  ) async {
    final dining = Category(name: "餐饮", iconCode: "");
    final categories = db.box<Category>();
    categories.put(dining);
    final id = legacy.createAndSaveTransaction(
      title: "麦当劳早餐",
      amount: -15,
      category: dining,
    );
    final rows = db.box<Transaction>();
    addTearDown(() {
      rows.remove(id);
      categories.remove(dining.id);
    });
    Future<void> render() => tester.pumpWidget(
      MaterialApp(
        theme: ThemeFactory(ledgerDark).materialTheme,
        localizationsDelegates: const [_LoadedLocale()],
        home: providers(
          Scaffold(
            body: TransactionListTile(
              transaction: rows.get(id)!,
              recoverFromTrashFn: null,
              moveToTrashFn: null,
              combineTransfers: false,
              theme: const TransactionListTileThemeData(showCategory: true),
            ),
          ),
        ),
      ),
    );
    await render();
    expect(find.text("🍔", findRichText: true), findsOneWidget);
    rows.put(rows.get(id)!..title = "早餐鸡蛋");
    await render();
    expect(find.text("🥚", findRichText: true), findsOneWidget);
    expect(find.text("🍔", findRichText: true), findsNothing);
    expect(rows.get(id)!.category.targetId, dining.id);
    expect(rows.get(id)!.amount, -15);
  });

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

  testWidgets(
    "a CNY expense updates the summary and uses its entry color in history",
    (tester) async {
      final id = wallet.createAndSaveTransaction(
        title: "示例采购",
        amount: -63.25,
        category: shopping,
      );
      final expectedExpense = db
          .box<Transaction>()
          .getAll()
          .where(
            (row) =>
                row.amount < 0 &&
                row.transactionDate.year == DateTime.now().year &&
                row.transactionDate.month == DateTime.now().month,
          )
          .fold<double>(0, (sum, row) => sum + row.amount);
      final theme = ThemeFactory(ledgerLight).materialTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: const [_LoadedLocale()],
          builder: (_, child) => providers(child!),
          home: const Scaffold(body: HomeTab()),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.byType(LedgerFlowSummary).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 25));
      }
      final summary = tester.widget<LedgerFlowSummary>(
        find.byType(LedgerFlowSummary),
      );
      expect(summary.flow.currency, "CNY");
      expect(summary.flow.expenseSum, closeTo(expectedExpense, 0.001));
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is TransactionListTile && widget.transaction.id == id,
      );
      final historyIcon = tester.widget<Icon>(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.shopping_bag_outlined),
        ),
      );
      await tester.tap(find.byTooltip("搜索与筛选"));
      await tester.pump();
      expect(find.byTooltip("收起筛选"), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (_, child) => providers(child!),
          home: const QuickEntryPage(),
        ),
      );
      await tester.pump();
      final entryIcon = tester.widget<Icon>(
        find.byIcon(Icons.shopping_bag_outlined),
      );
      expect(entryIcon.color, historyIcon.color);
      expect(
        entryIcon.color,
        isNot(tester.widget<Icon>(find.byIcon(Icons.checkroom_outlined)).color),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
