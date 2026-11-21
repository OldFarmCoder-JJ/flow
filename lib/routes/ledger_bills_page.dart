import "package:share_plus/share_plus.dart";
import "dart:math" as math;
import "package:flow/data/ledger_bills.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/transaction_filter.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/prefs/transitive.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flow/widgets/general/ledger_category_icon.dart";
import "package:flow/widgets/general/ledger_charts.dart";
import "package:flow/widgets/general/ledger_choice_bar.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

final _currency = NumberFormat("#,##0.00", "zh_CN");
String _amount(int cents) => _currency.format(cents / 100);
const _spending = Color(0xFFE28A56);
const _earning = Color(0xFF31967D);

/// Opens the calendar statements at the year currently being browsed.
void openLedgerBills(BuildContext context, DateTime anchor) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LedgerBillsPage(anchor: anchor)),
  );
}

/// Monthly and annual statements, including drill-down by calendar month.
class LedgerBillsPage extends StatefulWidget {
  const LedgerBillsPage({super.key, required this.anchor, this.detail = false});
  final DateTime anchor;
  final bool detail;
  @override
  State<LedgerBillsPage> createState() => _LedgerBillsPageState();
}

class _LedgerBillsPageState extends State<LedgerBillsPage> {
  late int year = math.min(widget.anchor.year, DateTime.now().year);
  bool annual = false;
  late final reports =
      const TransactionFilter(isPending: false, currencies: [ledgerCurrency])
          .queryBuilder()
          .watch(triggerImmediately: true)
          .map((query) => LedgerBills(query.find(), DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final month = DateTime(widget.anchor.year, widget.anchor.month);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.detail ? "${month.year}年${month.month}月账单" : "账单"),
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<bool?>(
          valueListenable:
              TransitiveLocalPreferences().sessionPrivacyMode.valueNotifier,
          builder: (context, hidden, _) => hidden == true
              ? const Center(child: Text("金额已隐藏"))
              : StreamBuilder<LedgerBills>(
                  stream: reports,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("账单读取失败，请返回后重试"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bills = snapshot.requireData;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          children: widget.detail
                              ? [_MonthReport(bills: bills, month: month)]
                              : overview(bills),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  List<Widget> overview(LedgerBills bills) {
    final available = {...bills.years.keys, bills.now.year, year}.toList()
      ..sort((a, b) => b.compareTo(a));
    final months = year == bills.now.year ? bills.now.month : 12;
    return [
      Row(
        children: [
          if (!annual)
            DropdownButton<int>(
              value: year,
              underline: const SizedBox.shrink(),
              items: [
                for (final y in available)
                  DropdownMenuItem(value: y, child: Text("$y年")),
              ],
              onChanged: (y) {
                if (y != null) setState(() => year = y);
              },
            ),
          const Spacer(),
          Flexible(
            flex: 4,
            child: LedgerChoiceBar<bool>(
              options: const {false: "月账单", true: "年账单"},
              selected: annual,
              onSelect: (v) => setState(() => annual = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _BalanceCard(
        label: annual ? "累计结余" : "$year年结余",
        totals: annual ? bills.total : bills.years[year] ?? BillTotals(),
      ),
      const SizedBox(height: 18),
      _BillLine(
        period: annual ? "年份" : "月份",
        cells: const ["收入", "支出", "结余"],
        header: true,
      ),
      if (annual && bills.years.isEmpty)
        const Padding(
          padding: EdgeInsets.all(22),
          child: Center(child: Text("暂无账单")),
        ),
      if (annual)
        for (final y in available.where(bills.years.containsKey))
          _BillLine.total(
            period: "$y年",
            totals: bills.years[y]!,
            onTap: () => setState(() {
              year = y;
              annual = false;
            }),
          )
      else
        for (int m = months; m >= 1; m--)
          _BillLine.total(
            period: "$m月",
            totals: bills.month(DateTime(year, m)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LedgerBillsPage(anchor: DateTime(year, m), detail: true),
              ),
            ),
          ),
    ];
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({
    required this.period,
    required this.cells,
    this.header = false,
    this.onTap,
  });
  factory _BillLine.total({
    required String period,
    required BillTotals totals,
    required VoidCallback onTap,
  }) => _BillLine(
    period: period,
    cells: [
      _amount(totals.income),
      _amount(totals.expense),
      _amount(totals.balance),
    ],
    onTap: onTap,
  );
  final String period;
  final List<String> cells;
  final bool header;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: header ? 34 : 50),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: header ? 12 : 14,
            color: header ? colors.onSurfaceVariant : colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(period),
                ),
              ),
              for (final cell in cells)
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(cell),
                    ),
                  ),
                ),
              SizedBox(
                width: 16,
                child: header
                    ? null
                    : Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.totals,
    this.previous,
  });
  final String label;
  final BillTotals totals;
  final BillTotals? previous;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: light
              ? const [Color(0xFFFFEDAD), Color(0xFFFFF6D9)]
              : [colors.surfaceContainerHigh, colors.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _amount(totals.balance),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          if (previous != null) Text("上月结余  ${_amount(previous!.balance)}"),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric("收入", _amount(totals.income))),
              Expanded(child: _Metric("支出", _amount(totals.expense))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .65),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _MonthReport extends StatefulWidget {
  const _MonthReport({required this.bills, required this.month});
  final LedgerBills bills;
  final DateTime month;
  @override
  State<_MonthReport> createState() => _MonthReportState();
}

class _MonthReportState extends State<_MonthReport> {
  int? selected;
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final bills = widget.bills;
    final m = widget.month;
    final prev = DateTime(m.year, m.month - 1);
    final spend = bills.breakdown(m, expense: true);
    final income = bills.breakdown(m, expense: false);
    final previous = bills.breakdown(prev, expense: true);
    final changes = {for (final c in previous.categories) c.id: -c.cents};
    for (final c in spend.categories) {
      changes.update(c.id, (v) => v + c.cents, ifAbsent: () => c.cents);
    }
    final biggest = changes.entries.where((e) => e.value != 0).toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final ranking =
        (bills.entries[m] ?? <Transaction>[])
            .where((r) => r.amount < 0)
            .toList()
          ..sort((a, b) => a.amount.compareTo(b.amount));
    final peak = spend.buckets.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    final activity = bills.activity(m);
    final cats = CategoriesProvider.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceCard(
          label: "本月结余",
          totals: bills.month(m),
          previous: bills.month(prev),
        ),
        _Section("支出分类", [
          if (spend.totalCents == 0)
            const Text("本月暂无支出")
          else ...[
            LedgerRing(
              stats: spend,
              kind: "支出",
              selectedCategory: selected,
              onSelect: (v) => setState(() => selected = v),
              showAmounts: true,
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(child: Text("单笔支出排行")),
                if (ranking.length > 3)
                  TextButton(
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? "收起" : "查看更多"),
                  ),
              ],
            ),
            for (final (i, r)
                in ranking.take(expanded ? ranking.length : 3).indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: LedgerCategoryIcon(
                  category: r.category.target,
                  expenseTitle: r.title,
                  diameter: 34,
                ),
                title: Text(
                  "${i + 1}.  ${r.title?.trim().isNotEmpty == true ? r.title : r.category.target?.name ?? '未分类'}",
                ),
                subtitle: Text(
                  "${m.month}月${r.transactionDate.toLocal().day}日",
                ),
                trailing: Text(_amount((r.amount * 100).round())),
                onTap: () => context.push("/transaction/${r.id}"),
              ),
          ],
        ]),
        _Section("支出趋势", [
          Row(
            children: [
              Expanded(child: _Metric("单日最高", _amount(peak.value))),
              Expanded(
                child: _Metric(
                  "日均支出",
                  _amount((spend.totalCents / spend.buckets.length).round()),
                ),
              ),
            ],
          ),
          if (peak.value > 0)
            Text(
              "${m.month}月${peak.key.day}日",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: 12),
          LedgerTrend(
            stats: spend,
            interval: LedgerInterval.month,
            kind: "支出",
            showDailyList: false,
          ),
        ]),
        _Section("近六个月支出", [
          _SixMonths(bills: bills, month: m, expense: true),
          if (biggest.isNotEmpty) ...[
            const Divider(height: 26),
            Text("较${prev.month}月变化最大的分类"),
            for (final e in biggest.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: LedgerCategoryIcon(
                  category: cats.get(e.key),
                  diameter: 30,
                ),
                title: Text(cats.get(e.key)?.name ?? "未分类"),
                trailing: Text(
                  "${e.value > 0 ? '增加' : '减少'} ${_amount(e.value.abs())}",
                ),
              ),
          ],
        ]),
        _Section("收入分类", [
          _Metric("总收入", _amount(income.totalCents)),
          if (income.categories.isEmpty) const Text("本月暂无收入"),
          for (final c in income.categories)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.name)),
                      Text(
                        "${percentage(c.cents, income.totalCents)}    ${_amount(c.cents)}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: c.cents / income.totalCents,
                    color: ledgerChartCategoryColor(context, c.id),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
          const Divider(height: 26),
          const Text("近六个月收入"),
          _SixMonths(bills: bills, month: m, expense: false),
        ]),
        _Section("截至本月的记账记录", [
          Row(
            children: [
              Expanded(child: _Metric("连续记账", "${activity.streak} 天")),
              Expanded(child: _Metric("有记录的天数", "${activity.days} 天")),
              Expanded(child: _Metric("累计笔数", "${activity.count} 笔")),
            ],
          ),
        ]),
        if ((bills.entries[m] ?? []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_outlined, size: 17),
              label: const Text("分享月账单"),
              onPressed: () async {
                final totals = bills.month(m);
                final summary = [
                  "${m.year}年${m.month}月账单",
                  "收入 ${_amount(totals.income)}",
                  "支出 ${_amount(totals.expense)}",
                  "结余 ${_amount(totals.balance)}",
                  for (final c in spend.categories)
                    "${c.name}  ${_amount(c.cents)}  ${percentage(c.cents, spend.totalCents)}",
                ].join("\n");
                try {
                  await SharePlus.instance.share(ShareParams(text: summary));
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("未能打开系统分享")));
                }
              },
            ),
          ),
      ],
    );
  }
}

class _SixMonths extends StatelessWidget {
  const _SixMonths({
    required this.bills,
    required this.month,
    required this.expense,
  });
  final LedgerBills bills;
  final DateTime month;
  final bool expense;
  @override
  Widget build(BuildContext context) {
    final dates = [
      for (int i = 5; i >= 0; i--) DateTime(month.year, month.month - i),
    ];
    final values = [
      for (final d in dates)
        expense ? bills.month(d).expense : bills.month(d).income,
    ];
    final peak = values.fold(1, math.max);
    final color = expense ? _spending : _earning;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, date) in dates.indexed)
            Expanded(
              child: Semantics(
                label: "${date.year}年${date.month}月 ${_amount(values[i])}",
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _amount(values[i]),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: values[i] / peak * 78,
                      decoration: BoxDecoration(
                        color: i == 5 ? color : color.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${date.month}月",
                      style: Theme.of(context).textTheme.labelSmall,
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
