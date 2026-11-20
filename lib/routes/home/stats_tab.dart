import "package:fl_chart/fl_chart.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/money.dart";
import "package:flow/data/transaction_filter.dart";
import "package:flow/data/transactions_filter/time_range.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/prefs/transitive.dart";
import "package:flow/routes/transactions_page.dart";
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
                const SizedBox(height: 12),
                Text("图表", style: Theme.of(context).textTheme.headlineMedium),
                _StatsSwitch<bool>(
                  values: const {true: "支出", false: "收入"},
                  selected: expense,
                  onSelect: (value) => setState(() {
                    expense = value;
                    selectedCategory = null;
                  }),
                ),
                _StatsSwitch<LedgerInterval>(
                  values: {
                    for (final item in LedgerInterval.values) item: item.label,
                  },
                  selected: interval,
                  onSelect: (value) => updatePeriod(value, anchor),
                ),
                buildPeriods(now),
                _StatsSwitch<bool>(
                  values: const {false: "分类占比", true: "收支趋势"},
                  selected: showTrend,
                  onSelect: (value) => setState(() => showTrend = value),
                ),
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
                      return buildReport(stats);
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
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (int i = -3; i <= 0; i++)
                  FilterChip(
                    showCheckmark: false,
                    label: Text(periodLabel(interval.offset(end, i), current)),
                    selected: interval.offset(end, i) == selected,
                    onSelected: (_) =>
                        updatePeriod(interval, interval.offset(end, i)),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: selected == current ? "当前期间" : "回到当前期间",
          onPressed: selected == current
              ? null
              : () => updatePeriod(interval, now),
          icon: const Icon(Icons.today_outlined),
        ),
      ],
    );
  }

  String periodLabel(DateTime date, DateTime current) => switch (interval) {
    LedgerInterval.year => date == current ? "今年" : "${date.year}",
    LedgerInterval.month =>
      date == current
          ? "本月"
          : date.year == current.year
          ? "${date.month}月"
          : "${date.year}/${date.month}",
    LedgerInterval.week =>
      date == current ? "本周" : "${date.month}/${date.day}起",
  };

  Widget buildReport(LedgerStats stats) {
    final kind = expense ? "支出" : "收入";
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text("本期暂无$kind")),
            )
          else if (showTrend)
            _LedgerTrend(stats: stats, interval: interval, kind: kind)
          else ...[
            _LedgerRing(
              stats: stats,
              kind: kind,
              selectedCategory: selectedCategory,
              onSelect: (value) => setState(() => selectedCategory = value),
            ),
            const SizedBox(height: 20),
            Text(
              expense ? "支出分类" : "收入分类",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            for (final category in stats.categories)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: selectedCategory == category.id,
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: categoryColor(category.id),
                ),
                title: Text(category.name),
                subtitle: Text(percentage(category.cents, stats.totalCents)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ledgerAmount(category.cents),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
                onTap: () => openCategory(category, kind),
              ),
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

class _StatsSwitch<T> extends StatelessWidget {
  const _StatsSwitch({
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  final Map<T, String> values;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [
      for (final entry in values.entries)
        ButtonSegment(value: entry.key, label: Text(entry.value)),
    ],
    selected: {selected},
    onSelectionChanged: (selected) => onSelect(selected.single),
  );
}

Widget ledgerAmount(int cents, {TextStyle? style}) =>
    MoneyText(Money(cents / 100, ledgerCurrency), style: style);

String percentage(int cents, int total) =>
    "${(cents * 100 / total).toStringAsFixed(1)}%";

const _categoryColors = [
  Color(0xFFA76B10),
  Color(0xFF537D65),
  Color(0xFF666FA8),
  Color(0xFF9D594E),
  Color(0xFF397A80),
  Color(0xFF8B6093),
  Color(0xFF657653),
];

Color categoryColor(int id) => _categoryColors[id % _categoryColors.length];

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
    return SizedBox(
      height: 228,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 72,
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
                    radius: selectedCategory == item.id ? 34 : 28,
                    showTitle: false,
                  ),
                if (other > 0)
                  PieChartSectionData(
                    value: other.toDouble(),
                    color: const Color(0xFF776D60),
                    radius: 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: 133,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chosen?.name ?? "总$kind",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ledgerAmount(
                    chosen?.cents ?? stats.totalCents,
                    style: Theme.of(context).textTheme.titleLarge,
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
        ledgerAmount(stats.totalCents, style: theme.textTheme.headlineMedium),
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
