import "package:flow/data/ledger_stats.dart";
import "package:flow/entity/transaction.dart";

/// Income and spending in integer fen, with spending shown as a positive amount.
class BillTotals {
  int income = 0;
  int expense = 0;
  int get balance => income - expense;

  void add(int cents) {
    if (cents >= 0) {
      income += cents;
    } else {
      expense -= cents;
    }
  }
}

/// Calendar statements built from settled RMB transactions on the device.
class LedgerBills {
  LedgerBills(Iterable<Transaction> transactions, this.now) {
    for (final row in transactions) {
      if (!isSettledLedgerEntry(row, now) || row.currency != ledgerCurrency) {
        continue;
      }
      final date = row.transactionDate.toLocal();
      final month = DateTime(date.year, date.month);
      final cents = (row.amount * 100).round();
      (entries[month] ??= []).add(row);
      (months[month] ??= BillTotals()).add(cents);
      (years[date.year] ??= BillTotals()).add(cents);
      total.add(cents);
    }
  }

  final DateTime now;
  final total = BillTotals();
  final years = <int, BillTotals>{};
  final months = <DateTime, BillTotals>{};
  final entries = <DateTime, List<Transaction>>{};

  BillTotals month(DateTime date) => months[date] ?? BillTotals();

  LedgerStats breakdown(DateTime date, {required bool expense}) =>
      LedgerStats.calculate(
        rows: entries[date] ?? const [],
        interval: LedgerInterval.month,
        anchor: date,
        now: now,
        expense: expense,
      );

  /// Counts posting days and the streak ending on the last elapsed day of the month.
  ({int days, int count, int streak}) activity(DateTime month) {
    final next = DateTime(month.year, month.month + 1);
    final days = <DateTime>{};
    int count = 0;
    for (final group in entries.entries) {
      if (!group.key.isBefore(next)) continue;
      for (final row in group.value) {
        final d = row.transactionDate.toLocal();
        days.add(DateTime.utc(d.year, d.month, d.day));
        count++;
      }
    }
    final end = next.isAfter(now) ? now : DateTime(next.year, next.month, 0);
    var cursor = DateTime.utc(end.year, end.month, end.day);
    int streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (days: days.length, count: count, streak: streak);
  }
}
