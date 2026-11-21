import "dart:io";

import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/file_attachment.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/routes/home/stats_tab.dart";
import "package:flow/routes/quick_entry_page.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/theme.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

const _photoChannel = MethodChannel("plugins.flutter.io/image_picker");

void main() {
  late Directory directory;
  late ObjectBox db;
  late Account account;
  late Category meals;
  late Category salary;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp("ledger-quick-");
    db = await ObjectBox.initialize(
      customDirectory: directory.path,
      subdirectory: "ledger",
    );
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await LocalPreferences.initialize();
    account = Account(name: "微信", currency: "CNY", iconCode: "");
    meals = Category(name: "餐饮", iconCode: "");
    salary = Category(name: "工资", iconCode: "");
    db.box<Account>().put(account);
    db.box<Category>().putMany([meals, salary]);
  });

  tearDownAll(() async {
    db.store.close();
    await directory.delete(recursive: true);
  });

  Widget app(Widget child, {double textScale = 1, bool haveAccount = true}) =>
      MaterialApp(
        theme: ThemeFactory(ledgerLight).materialTheme,
        builder: (context, content) => AccountsProvider(
          haveAccount ? [account] : const [],
          child: CategoriesProvider(
            [meals, salary],
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: content!,
            ),
          ),
        ),
        home: child,
      );

  void setPhoneSize(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets("quick expense saves name, note, category and photo", (
    tester,
  ) async {
    setPhoneSize(tester);
    final receipt = File("assets/images/pin.png").absolute;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_photoChannel, (call) async {
      expect(call.method, "pickMultiImage");
      return [receipt.path];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_photoChannel, null));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QuickEntryPage()),
              ),
              child: const Text("打开记账"),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("打开记账"));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text("餐饮"));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.widget<TextField>(fields.first).focusNode!.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    await tester.pumpAndSettle();
    await tester.enterText(fields.first, "24.50");
    await tester.enterText(fields.last, "早餐鸡蛋");
    await tester.pump();
    expect(find.text("🥚", findRichText: true), findsOneWidget);
    await tester.enterText(fields.last, "晚餐麦当劳");
    await tester.pump();
    expect(find.text("🍔", findRichText: true), findsOneWidget);
    expect(find.text("🥚", findRichText: true), findsNothing);
    await tester.tap(find.byTooltip("添加备注"));
    await tester.pumpAndSettle();
    await tester.enterText(fields.last, "同事聚餐");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("添加照片"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("从相册选择"));
    await tester.pumpAndSettle();
    expect(find.byTooltip("移除第 1 张照片"), findsOneWidget);
    expect(db.box<FileAttachment>().count(), 0);
    await tester.runAsync(() async {
      await tester.tap(find.text("保存"));
      for (
        var attempt = 0;
        attempt < 30 && db.box<Transaction>().isEmpty();
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text("打开记账"), findsOneWidget);
    final transaction = db.box<Transaction>().getAll().single;
    expect(transaction.amount, -24.5);
    expect(transaction.category.target?.uuid, meals.uuid);
    expect(transaction.account.target?.uuid, account.uuid);
    expect(transaction.title, "晚餐麦当劳");
    expect(transaction.description, "同事聚餐");
    expect(
      transaction.attachments.single.file.readAsBytesSync(),
      receipt.readAsBytesSync(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets("entry fields and four years fit a phone with large text", (
    tester,
  ) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app(const QuickEntryPage(), textScale: 1.75));
    await tester.tap(find.text("收入"));
    await tester.pump();
    await tester.tap(find.text("工资"));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpWidget(
      app(const Scaffold(body: StatsTab()), textScale: 1.75),
    );
    await tester.tap(find.text("年"));
    await tester.pump();
    final year = DateTime.now().year;
    for (var offset = 0; offset <= 3; offset++) {
      expect(find.text("${year - offset}").hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text("${year - 1}"));
    await tester.pump();
    expect(find.byTooltip("回到当前期间"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("entry can start with a category before an account exists", (
    tester,
  ) async {
    setPhoneSize(tester);
    await tester.pumpWidget(app(const QuickEntryPage(), haveAccount: false));
    await tester.tap(find.text("餐饮"));
    await tester.pumpAndSettle();
    expect(find.text("新建账户"), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "保存"),
    );
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
