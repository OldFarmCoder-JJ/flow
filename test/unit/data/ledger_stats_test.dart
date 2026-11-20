import "package:flow/data/ledger_stats.dart";
import "package:flow/entity/transaction.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("annual and monthly totals reconcile and exclude unsettled rows", () {
    final now = DateTime(2025, 3, 15, 12);
    Transaction entry(
      double amount,
      DateTime date, {
      String currency = "CNY",
      bool? pending,
    }) => Transaction(
      uuid: "${date.toIso8601String()}:$amount:$currency",
      amount: amount,
      currency: currency,
      transactionDate: date,
      isPending: pending,
    );

    final rows = [
      entry(-26.80, DateTime(2024, 12, 31, 23, 59)),
      entry(-10.22, DateTime(2025, 1, 1)),
      entry(-20.08, DateTime(2025, 3, 15)),
      entry(100, DateTime(2025, 3, 15)),
      entry(-5, DateTime(2025, 3, 15), currency: "USD"),
      entry(-2, DateTime(2025, 3, 13), pending: true),
      entry(-3, DateTime(2025, 3, 12))..isDeleted = true,
      entry(-90, DateTime(2025, 3, 16)),
    ];
    LedgerStats report(LedgerInterval interval) => LedgerStats.calculate(
      rows: rows,
      interval: interval,
      anchor: now,
      now: now,
      expense: true,
    );

    final annual = report(LedgerInterval.year);
    expect(annual.totalCents, 3030);
    expect(annual.buckets.values, [1022, 0, 2008]);
    expect(annual.categories.single.cents, annual.totalCents);
    expect(annual.containsForeignEntries, true);
    final monthly = report(LedgerInterval.month);
    expect(monthly.totalCents, annual.buckets[DateTime(2025, 3)]);
    expect(monthly.buckets.length, 15);

    final income = LedgerStats.calculate(
      rows: rows,
      interval: LedgerInterval.month,
      anchor: now,
      now: now,
      expense: false,
    );
    expect(income.totalCents, 10000);
    expect(
      LedgerInterval.week.range(DateTime(2025, 1, 1)).from,
      DateTime(2024, 12, 30),
    );
  });
}
