import "package:fl_chart/fl_chart.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/money.dart";
import "package:flow/data/transaction_filter.dart";
import "package:flow/data/transactions_filter/time_range.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/prefs/transitive.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/routes/transactions_page.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flow/widgets/general/ledger_choice_bar.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flutter/material.dart";

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
    with AutomaticKeepAliveClientMixin {
  LedgerInterval interval = LedgerInterval.month;
  DateTime anchor = DateTime.now();
  bool expense = true;
  bool showTrend = false;
  int? selectedCategory;
  late Stream<List<Transaction>> entries = watchEntries();

  Stream<List<Transaction>> watchEntries() => TransactionFilter(
    range: TransactionFilterTimeRange.fromTimeRange(interval.range(anchor)),
    isPending: false,
  ).queryBuilder().watch(triggerImmediately: true).map((query) => query.find());

  void updatePeriod(LedgerInterval unit, DateTime date) => setState(() {
    interval = unit;
    anchor = date;
    selectedCategory = null;
    entries = watchEntries();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final now = DateTime.now();
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "图表",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: showTrend ? "切换到分类占比" : "切换到收支趋势",
                      child: TextButton.icon(
                        onPressed: () => setState(() => showTrend = !showTrend),
                        icon: Icon(
                          showTrend ? Icons.show_chart : Icons.donut_large,
                          size: 18,
                        ),
                        label: Text(showTrend ? "收支趋势" : "分类占比"),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: LedgerChoiceBar<bool>(
                        label: "收支类型",
                        options: const {true: "支出", false: "收入"},
                        selected: expense,
                        onSelect: (value) => setState(() {
                          expense = value;
                          selectedCategory = null;
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 1,
                        height: 18,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: LedgerChoiceBar<LedgerInterval>(
                        label: "统计周期",
                        options: {
                          for (final item in LedgerInterval.values)
                            item: item.label,
                        },
                        selected: interval,
                        onSelect: (value) => updatePeriod(value, anchor),
                      ),
                    ),
                  ],
                ),
                buildPeriods(now),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<List<Transaction>>(
                    key: ValueKey(entries),
                    stream: entries,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton(
                            onPressed: () => updatePeriod(interval, anchor),
                            child: const Text("读取失败，点击重试"),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = LedgerStats.calculate(
                        rows: snapshot.requireData,
                        interval: interval,
                        anchor: anchor,
                        now: now,
                        expense: expense,
                      );
                      return buildReport(stats, now);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPeriods(DateTime now) {
    final current = interval.start(now);
    final selected = interval.start(anchor);
    final last = interval.offset(selected, 2);
    final end = last.isAfter(current) ? current : last;
    return Row(
      children: [
        IconButton(
          tooltip: "更早",
          onPressed: () =>
              updatePeriod(interval, interval.offset(selected, -1)),
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        for (int i = -3; i <= 0; i++)
          Expanded(
            child: LedgerChoice(
              label: periodLabel(interval.offset(end, i), current),
              selected: interval.offset(end, i) == selected,
              onTap: () => updatePeriod(interval, interval.offset(end, i)),
            ),
          ),
        IconButton(
          tooltip: selected == current ? "当前期间" : "回到当前期间",
          onPressed: selected == current
              ? null
              : () => updatePeriod(interval, now),
          icon: const Icon(Icons.today_outlined, size: 18),
        ),
      ],
    );
  }

  String periodLabel(DateTime date, DateTime current) => switch (interval) {
    LedgerInterval.year => "${date.year}",
    LedgerInterval.month =>
      date == current
          ? "本月"
          : date.year == current.year
          ? "${date.month}月"
          : "${date.year}/${date.month}",
    LedgerInterval.week =>
      date == current ? "本周" : "${date.month}/${date.day}起",
  };

  Widget buildReport(LedgerStats stats, DateTime now) {
    final kind = expense ? "支出" : "收入";
    final categories = CategoriesProvider.of(context);
    return ValueListenableBuilder<bool?>(
      valueListenable:
          TransitiveLocalPreferences().sessionPrivacyMode.valueNotifier,
      builder: (context, hidden, _) => ListView(
        key: const PageStorageKey("ledger-statistics"),
        padding: const EdgeInsets.only(top: 12, bottom: 112),
        children: [
          if (stats.containsForeignEntries)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text("本期另有外币流水，可在明细查看。"),
            ),
          if (hidden == true)
            const Center(
              child: Padding(padding: EdgeInsets.all(24), child: Text("金额已隐藏")),
            )
          else if (stats.totalCents == 0)
            _EmptyLedgerPeriod(
              label: interval.fullLabel(anchor),
              kind: kind,
              alternative: findLedgerAlternativePeriod(
                interval: interval,
                anchor: anchor,
                now: now,
                expense: expense,
              ),
              interval: interval,
              onSelect: (date) => updatePeriod(interval, date),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                interval.fullLabel(anchor),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (showTrend)
              _LedgerTrend(stats: stats, interval: interval, kind: kind)
            else ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _LedgerRing(
                    stats: stats,
                    kind: kind,
                    selectedCategory: selectedCategory,
                    onSelect: (value) =>
                        setState(() => selectedCategory = value),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "$kind分类",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final category in stats.categories)
                _CategoryRank(
                  category: category,
                  icon: LedgerCategoryIcon(
                    category: categories.get(category.id),
                    diameter: 33,
                    tint: categoryColor(category.id),
                  ),
                  total: stats.totalCents,
                  selected: selectedCategory == category.id,
                  onTap: () => openCategory(category, kind),
                ),
            ],
          ],
        ],
      ),
    );
  }

  void openCategory(LedgerCategoryTotal category, String kind) {
    final range = interval.range(anchor);
    final txType = expense ? TransactionType.expense : TransactionType.income;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransactionsPage(
          title: "${category.name} · $kind",
          initialRange: range,
          queryFn: (requestedRange) => TransactionFilter(
            range: TransactionFilterTimeRange.fromTimeRange(requestedRange),
            currencies: const [ledgerCurrency],
            isPending: false,
          ).queryBuilder(),
          matches: (row) =>
              isSettledLedgerEntry(row, DateTime.now()) &&
              row.type == txType &&
              (row.amount.abs() * 100).round() > 0 &&
              row.category.targetId == category.id,
          fixedRange: true,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _EmptyLedgerPeriod extends StatelessWidget {
  const _EmptyLedgerPeriod({
    required this.label,
    required this.kind,
    required this.alternative,
    required this.interval,
    required this.onSelect,
  });

  final String label;
  final String kind;
  final DateTime? alternative;
  final LedgerInterval interval;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: colors.primary,
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              "$label暂无$kind",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (alternative case final date?)
              TextButton(
                onPressed: () => onSelect(date),
                child: Text("查看${interval.fullLabel(date)}"),
              ),
          ],
        ),
      ),
    );
  }
}

Widget ledgerAmount(int cents, {TextStyle? style}) =>
    MoneyText(Money(cents / 100, ledgerCurrency), style: style);

String percentage(int cents, int total) =>
    "${(cents * 100 / total).toStringAsFixed(1)}%";

const _categoryColors = [
  Color(0xFFFFBD49),
  Color(0xFF51A1EC),
  Color(0xFF1AB89E),
  Color(0xFFF88877),
  Color(0xFF9879ED),
  Color(0xFFEA76AB),
  Color(0xFF83BB5A),
];

Color categoryColor(int id) => _categoryColors[id % _categoryColors.length];

const _otherColor = Color(0xFFA9A3BE);

class _CategoryRank extends StatelessWidget {
  const _CategoryRank({
    required this.category,
    required this.icon,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final LedgerCategoryTotal category;
  final Widget icon;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.surfaceContainerLow : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 51),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              spacing: 8,
              children: [
                icon,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        minHeight: 3,
                        value: category.cents / total,
                        color: categoryColor(category.id),
                        backgroundColor: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                Text(
                  percentage(category.cents, total),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 62,
                    maxWidth: 126,
                  ),
                  child: ledgerAmount(
                    category.cents,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerRing extends StatelessWidget {
  const _LedgerRing({
    required this.stats,
    required this.kind,
    required this.selectedCategory,
    required this.onSelect,
  });

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
            color: categoryColor(entry.id),
            fraction: percentage(entry.cents, stats.totalCents),
            selected: entry.id == selectedCategory,
          ),
        if (other > 0)
          _LegendRow(
            label: "其他",
            color: _otherColor,
            fraction: percentage(other, stats.totalCents),
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
                    color: categoryColor(item.id),
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
  });

  final String label;
  final Color color;
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
          Text(
            fraction,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LedgerTrend extends StatelessWidget {
  const _LedgerTrend({
    required this.stats,
    required this.interval,
    required this.kind,
  });

  final LedgerStats stats;
  final LedgerInterval interval;
  final String kind;

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
