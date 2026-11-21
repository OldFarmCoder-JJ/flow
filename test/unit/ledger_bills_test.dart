import "package:flow/data/ledger_bills.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("statement totals and activity use settled local RMB postings", () {
    final now = DateTime(2026, 1, 2, 19);
    Transaction row(
      int day,
      double amount, {
      String currency = "CNY",
      bool pending = false,
    }) => Transaction(
      uuid: "$day-$amount",
      currency: currency,
      amount: amount,
      transactionDate: DateTime(2026, 1, day),
      isPending: pending,
    );
    final bills = LedgerBills([
      row(0, 25),
      row(1, -8.55),
      row(1, -8.55),
      row(2, 100),
      row(2, -1, currency: "USD"),
      row(2, -2, pending: true),
      row(2, -3)..isDeleted = true,
      row(3, -4),
    ], now);
    expect(bills.total.income, 12500);
    expect(bills.total.expense, 1710);
    expect(bills.years[2026]!.balance, 8290);
    expect(bills.month(DateTime(2025, 12)).income, 2500);
    expect(bills.month(DateTime(2025, 11)).balance, 0);
    expect(bills.activity(DateTime(2026, 1)), (days: 3, count: 4, streak: 3));
    expect(bills.activity(DateTime(2025, 12)), (days: 1, count: 1, streak: 1));
  });

  test("frequent categories retain distinct accents regardless of rank", () {
    final names = ["购物", "餐饮", "娱乐", "游戏账号", "医疗", "交通", "维修"];
    final colors = names
        .map((name) => ledgerCategoryAccent(Category(name: name, iconCode: "")))
        .toSet();
    expect(colors.length, names.length);
  });
}
