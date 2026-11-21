import "package:flow/data/ledger_stats.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flutter/material.dart";

/// Color-coded spending subtotals for the visible transactions in today's group.
class TodaySpending extends StatelessWidget {
  const TodaySpending({super.key, required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totals = <int, int>{};
    final categories = <int, Category?>{};
    for (final row in transactions) {
      if (row.amount >= 0 ||
          row.currency != ledgerCurrency ||
          !isSettledLedgerEntry(row, now)) {
        continue;
      }
      final cents = (-row.amount * 100).round();
      if (cents == 0) continue;
      final id = row.category.targetId;
      categories.putIfAbsent(id, () => row.category.target);
      totals.update(id, (value) => value + cents, ifAbsent: () => cents);
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final ranked = totals.entries.toList()
      ..sort((a, b) {
        final order = b.value.compareTo(a.value);
        return order != 0 ? order : a.key.compareTo(b.key);
      });
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 5,
        runSpacing: 4,
        children: [
          for (final entry in ranked)
            DecoratedBox(
              decoration: BoxDecoration(
                color: ledgerCategoryAccent(
                  categories[entry.key],
                ).withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "● ",
                        style: TextStyle(
                          color: ledgerCategoryAccent(categories[entry.key]),
                        ),
                      ),
                      TextSpan(
                        text: "${categories[entry.key]?.name ?? '未分类'} ",
                      ),
                      TextSpan(
                        text: (entry.value / 100).toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
