import "package:fl_chart/fl_chart.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/money.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flutter/material.dart";

Widget ledgerAmount(int cents, {TextStyle? style}) =>
    MoneyText(Money(cents / 100, ledgerCurrency), style: style);

String percentage(int cents, int total) =>
    "${(cents * 100 / total).toStringAsFixed(1)}%";

Color ledgerChartCategoryColor(BuildContext context, int id) =>
    ledgerCategoryAccent(CategoriesProvider.of(context).get(id));

const _otherColor = Color(0xFFA6B3BF);

class LedgerRing extends StatelessWidget {
  const LedgerRing({
    super.key,
    required this.stats,
    this.showAmounts = false,
    required this.kind,
    required this.selectedCategory,
    required this.onSelect,
  });

  final bool showAmounts;
  final LedgerStats stats;
  final String kind;
  final int? selectedCategory;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = stats.categories.take(5).toList();
    final other = stats.categories
        .skip(5)
        .fold(0, (sum, item) => sum + item.cents);
    final chosen = stats.categories
        .where((item) => item.id == selectedCategory)
        .firstOrNull;
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in categories)
          _LegendRow(
            label: entry.name,
            color: ledgerChartCategoryColor(context, entry.id),
            fraction: percentage(entry.cents, stats.totalCents),
            amount: showAmounts ? entry.cents : null,
            selected: entry.id == selectedCategory,
          ),
        if (other > 0)
          _LegendRow(
            label: "其余分类",
            color: _otherColor,
            fraction: percentage(other, stats.totalCents),
            amount: showAmounts ? other : null,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, size) {
        final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
        final sideBySide = size.maxWidth >= 278 && scale <= 1.25;
        final diameter = sideBySide
            ? (size.maxWidth * .48).clamp(132.0, 172.0)
            : 178.0.clamp(0, size.maxWidth).toDouble();
        final ring = _LedgerRingGraphic(
          diameter: diameter,
          categories: categories,
          other: other,
          label: chosen?.name ?? "总$kind",
          cents: chosen?.cents ?? stats.totalCents,
          selectedCategory: selectedCategory,
          onSelect: onSelect,
        );
        if (!sideBySide) {
          return Column(children: [ring, const SizedBox(height: 8), legend]);
        }
        return Row(
          children: [
            ring,
            const SizedBox(width: 14),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LedgerRingGraphic extends StatelessWidget {
  const _LedgerRingGraphic({
    required this.diameter,
    required this.categories,
    required this.other,
    required this.label,
    required this.cents,
    required this.selectedCategory,
    required this.onSelect,
  });

  final double diameter;
  final List<LedgerCategoryTotal> categories;
  final int other;
  final String label;
  final int cents;
  final int? selectedCategory;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final radius = diameter * .34;
    final ringWidth = diameter * .12;
    final labelWidth = radius * 1.7;
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: radius,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final index =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                  final id = index >= 0 && index < categories.length
                      ? categories[index].id
                      : null;
                  onSelect(id == selectedCategory ? null : id);
                },
              ),
              sections: [
                for (final item in categories)
                  PieChartSectionData(
                    value: item.cents.toDouble(),
                    color: ledgerChartCategoryColor(context, item.id),
                    radius: selectedCategory == item.id
                        ? ringWidth + 4
                        : ringWidth,
                    showTitle: false,
                  ),
                if (other > 0)
                  PieChartSectionData(
                    value: other.toDouble(),
                    color: _otherColor,
                    radius: ringWidth,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: labelWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ledgerAmount(
                      cents,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.color,
    required this.fraction,
    this.selected = false,
    this.amount,
  });

  final String label;
  final Color color;
  final int? amount;
  final String fraction;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: 6,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fraction,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              if (amount != null)
                ledgerAmount(amount!, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class LedgerTrend extends StatelessWidget {
  const LedgerTrend({
    super.key,
    required this.stats,
    required this.interval,
    required this.kind,
    this.showDailyList = true,
  });

  final LedgerStats stats;
  final LedgerInterval interval;
  final String kind;

  final bool showDailyList;

  String label(DateTime date) => interval == LedgerInterval.year
      ? "${date.month}月"
      : "${date.month}/${date.day}";

  @override
  Widget build(BuildContext context) {
    final buckets = stats.buckets.entries.toList();
    if (buckets.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final step = (buckets.length / 5).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("总$kind"),
        ledgerAmount(
          stats.totalCents,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              minX: 0,
              maxX: buckets.length == 1 ? 1 : (buckets.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= buckets.length ||
                          (index % step != 0 && index != buckets.length - 1)) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        label(buckets[index].key),
                        style: theme.textTheme.labelSmall,
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  color: color,
                  spots: [
                    for (final (index, bucket) in buckets.indexed)
                      FlSpot(index.toDouble(), bucket.value / 100),
                  ],
                  barWidth: 2,
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: .10),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (showDailyList)
          for (final bucket in buckets.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label(bucket.key)),
              trailing: ledgerAmount(bucket.value),
            ),
      ],
    );
  }
}
