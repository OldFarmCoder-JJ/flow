import "dart:convert";
import "dart:io";

import "package:flow/data/single_currency_flow.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/routes/ledger_analysis_page.dart";
import "package:flow/services/transactions.dart";
import "package:flow/sync/export/export_v2.dart";
import "package:flow/sync/import/import_v2.dart";
import "package:flow/sync/model/model_v2.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  test(
    "CNY entries, correction and transfer survive a full ledger restore",
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final directory = await Directory.systemTemp.createTemp("ledger-test-");
      final db = await ObjectBox.initialize(
        customDirectory: directory.path,
        subdirectory: "accounts",
      );
      addTearDown(() async {
        db.store.close();
        await directory.delete(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await LocalPreferences.initialize();

      final bank = Account(name: "银行卡", currency: "CNY", iconCode: "");
      final wallet = Account(name: "微信余额", currency: "CNY", iconCode: "");
      db.box<Account>().putMany([bank, wallet]);
      final meals = Category(name: "餐饮", iconCode: "");
      db.box<Category>().put(meals);
      bank.createAndSaveTransaction(amount: 100);
      final lunchId = bank.createAndSaveTransaction(
        amount: -18,
        category: meals,
      );
      bank.createAndSaveTransaction(amount: -3);
      bank.transferTo(targetAccount: wallet, amount: 20);

      void checkTotals(double expense, double net) {
        final totals = SingleCurrencyFlow(currency: "CNY");
        totals.addAll(
          db
              .box<Transaction>()
              .getAll()
              .where((row) => !row.isTransfer)
              .map((row) => row.money),
          null,
        );
        expect(totals.incomeSum, 100);
        expect(totals.expenseSum, -expense);
        expect(totals.flow, net);
      }

      checkTotals(21, 79);
      final lunch = db.box<Transaction>().get(lunchId)!..amount = -16;
      TransactionsService().updateOneSync(lunch);
      checkTotals(19, 81);

      final backup = SyncModelV2.fromJson(
        jsonDecode(await generateBackupJSONContentV2()),
      );
      await db.eraseMainData();
      expect(db.box<Transaction>().count(), 0);
      await ImportV2(backup).execute(ignoreSafetyBackupFail: true);
      checkTotals(19, 81);
      final balances = {
        for (final a in db.box<Account>().getAll()) a.name: a.balance.amount,
      };
      expect(balances, {"银行卡": 61.0, "微信余额": 20.0});
      final restored = db.box<Transaction>().getAll();
      expect(restored.length, 5);
      final now = DateTime.now();
      final report = monthlyAnalysisText(now, restored, now)!;
      expect(report, contains("3 笔"));
      expect(report, contains("收入 100.00，支出 19.00，结余 81.00"));
      expect(report, contains("餐饮：16.00"));
      expect(report, isNot(contains("微信余额")));
      expect(
        monthlyAnalysisText(DateTime(now.year, now.month - 1), restored, now),
        isNull,
      );
      expect(
        restored
            .singleWhere((row) => row.uuid == lunch.uuid)
            .category
            .target
            ?.name,
        "餐饮",
      );
    },
  );
}
