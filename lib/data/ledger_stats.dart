import "package:flow/data/transaction_filter.dart";
import "package:flow/data/transactions_filter/time_range.dart";
import "package:flow/entity/transaction.dart";
import "package:moment_dart/moment_dart.dart";

enum LedgerInterval {
  week("周"),
  month("月"),
  year("年");

  const LedgerInterval(this.label);
  final String label;

  DateTime start(DateTime date) => switch (this) {
    week => DateTime(date.year, date.month, date.day - date.weekday + 1),
    month => DateTime(date.year, date.month),
    year => DateTime(date.year),
  };

  DateTime offset(DateTime start, int count) => switch (this) {
    week => DateTime(start.year, start.month, start.day + count * 7),
    month => DateTime(start.year, start.month + count),
    year => DateTime(start.year + count),
  };

  TimeRange range(DateTime date) {
    final first = start(date);
    return CustomTimeRange(
      first,
      offset(first, 1).subtract(const Duration(milliseconds: 1)),
    );
  }

  /// Fully qualified label for the selected period.
  String fullLabel(DateTime date) {
    final first = start(date);
    return switch (this) {
      week => "${first.year}年${first.month}月${first.day}日当周",
      month => "${first.year}年${first.month}月",
      year => "${first.year}年",
    };
  }
}

bool isSettledLedgerEntry(Transaction row, DateTime now) =>
    !row.isTransfer &&
    row.isDeleted != true &&
    row.isPending != true &&
    !row.transactionDate.isAfter(now);

const ledgerCurrency = "CNY";

/// Chooses a populated period for a chart whose current selection is empty.
DateTime? findLedgerAlternativePeriod({
  required LedgerInterval interval,
  required DateTime anchor,
  required DateTime now,
  required bool expense,
}) {
  DateTime? latestIn(TimeRange range) {
    final query = TransactionFilter(
      range: TransactionFilterTimeRange.fromTimeRange(range),
      currencies: const [ledgerCurrency],
      isPending: false,
      minAmount: expense ? null : .005,
      maxAmount: expense ? -.005 : null,
    ).queryBuilder().build();
    try {
      return query
          .find()
          .where((row) => isSettledLedgerEntry(row, now))
          .firstOrNull
          ?.transactionDate
          .toLocal();
    } finally {
      query.close();
    }
  }

  final previousEnd = interval
      .start(anchor)
      .subtract(const Duration(milliseconds: 1));
  final historyStart = DateTime(1900);
  return (interval == LedgerInterval.month
          ? latestIn(interval.range(DateTime(anchor.year - 1, anchor.month)))
          : null) ??
      (previousEnd.isAfter(historyStart)
          ? latestIn(CustomTimeRange(historyStart, previousEnd))
          : null) ??
      latestIn(CustomTimeRange(historyStart, now));
}

class LedgerCategoryTotal {
  LedgerCategoryTotal(this.id, this.name);

  final int id;
  final String name;
  int cents = 0;
}

class LedgerStats {
  LedgerStats({
    required this.buckets,
    required this.categories,
    required this.totalCents,
    required this.containsForeignEntries,
  });

  final Map<DateTime, int> buckets;
  final List<LedgerCategoryTotal> categories;
  final int totalCents;
  final bool containsForeignEntries;

  factory LedgerStats.calculate({
    required Iterable<Transaction> rows,
    required LedgerInterval interval,
    required DateTime anchor,
    required DateTime now,
    required bool expense,
  }) {
    final range = interval.range(anchor);
    final buckets = <DateTime, int>{};
    for (
      DateTime date = range.from;
      !date.isAfter(range.to) && !date.isAfter(now);
      date = interval == LedgerInterval.year
          ? DateTime(date.year, date.month + 1)
          : DateTime(date.year, date.month, date.day + 1)
    ) {
      buckets[date] = 0;
    }

    final categories = <int, LedgerCategoryTotal>{};
    int total = 0;
    bool containsForeign = false;
    for (final row in rows) {
      if (!isSettledLedgerEntry(row, now) ||
          !range.contains(row.transactionDate) ||
          (expense ? row.amount >= 0 : row.amount <= 0)) {
        continue;
      }
      if (row.currency != ledgerCurrency) {
        containsForeign = true;
        continue;
      }

      final date = row.transactionDate.toLocal();
      final bucket = DateTime(
        date.year,
        date.month,
        interval == LedgerInterval.year ? 1 : date.day,
      );
      final cents = (row.amount.abs() * 100).round();
      if (cents == 0) continue;
      final category = row.category.target;
      final id = category?.id ?? 0;
      final categoryTotal = categories.putIfAbsent(
        id,
        () => LedgerCategoryTotal(id, category?.name ?? "未分类"),
      );
      categoryTotal.cents += cents;
      buckets.update(bucket, (value) => value + cents);
      total += cents;
    }
    return LedgerStats(
      buckets: buckets,
      categories: categories.values.toList()
        ..sort((a, b) {
          final byAmount = b.cents.compareTo(a.cents);
          return byAmount == 0 ? a.name.compareTo(b.name) : byAmount;
        }),
      totalCents: total,
      containsForeignEntries: containsForeign,
    );
  }
}
