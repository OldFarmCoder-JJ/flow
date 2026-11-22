import "package:flow/data/ledger_bills.dart";
import "package:flow/data/ledger_stats.dart";
import "package:flow/data/monthly_reserve.dart";
import "package:flow/data/transaction_filter.dart";
import "package:flow/data/transactions_filter/time_range.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/categories_provider.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

final _format = NumberFormat("#,##0.00", "zh_CN");
String _money(int cents) => _format.format(cents / 100);

/// Shows spendable income after recorded expenses and monthly reserves.
class SpendingRoomTab extends StatefulWidget {
  const SpendingRoomTab({super.key});

  @override
  State<SpendingRoomTab> createState() => _SpendingRoomTabState();
}

class _SpendingRoomTabState extends State<SpendingRoomTab> {
  late DateTime month = LedgerInterval.month.start(DateTime.now());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IconButton(
            tooltip: "上个月",
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(
              "${month.year}年${month.month}月",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: "下个月",
            icon: const Icon(Icons.chevron_right),
            onPressed:
                month.isBefore(LedgerInterval.month.start(DateTime.now()))
                ? () => setState(
                    () => month = DateTime(month.year, month.month + 1),
                  )
                : null,
          ),
        ],
      ),
      Expanded(
        child: _MonthlyRoom(key: ValueKey(month), month: month),
      ),
    ],
  );
}

class _MonthlyRoom extends StatefulWidget {
  const _MonthlyRoom({super.key, required this.month});
  final DateTime month;

  @override
  State<_MonthlyRoom> createState() => _MonthlyRoomState();
}

class _MonthlyRoomState extends State<_MonthlyRoom> {
  late final pref = LocalPreferences().monthlyReservePlan(widget.month);
  late MonthlyReserve plan = MonthlyReserve.decode(pref.value);
  late final reports =
      TransactionFilter(
            range: TransactionFilterTimeRange.fromTimeRange(
              LedgerInterval.month.range(widget.month),
            ),
            currencies: const [ledgerCurrency],
            isPending: false,
          )
          .queryBuilder()
          .watch(triggerImmediately: true)
          .map((q) => LedgerBills(q.find(), DateTime.now()));

  Future<void> editAmount(String? id, String name) async {
    final original = id == null ? plan.savings : plan.limits[id] ?? 0;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(label: name, original: original),
    );
    if (!mounted || amount == null) return;
    await saveAmount(id, amount);
  }

  Future<void> actions(String? id, String name) async {
    final edit = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("修改金额"),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(id == null ? "移除储蓄目标" : "删除这项预留"),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || edit == null) return;
    if (edit) {
      await editAmount(id, name);
    } else {
      await saveAmount(id, 0);
    }
  }

  Future<void> saveAmount(String? id, int amount) async {
    final updated = plan.change(id, amount);
    try {
      await pref.set(updated.encode());
      if (mounted) setState(() => plan = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("保存失败，请重试")));
      }
    }
  }

  Future<void> addReserve() async {
    final choices = CategoriesProvider.of(context)
        .categoriesFor(TransactionType.expense)
        .where((c) => !plan.limits.containsKey(c.uuid))
        .toList();
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: choices.isEmpty
            ? const ListTile(title: Text("暂无可添加的分类"))
            : ListView.builder(
                itemCount: choices.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(choices[i].name),
                  onTap: () => Navigator.pop(context, i),
                ),
              ),
      ),
    );
    if (mounted && choice != null) {
      await editAmount(choices[choice].uuid, choices[choice].name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cats = CategoriesProvider.of(context);
    return StreamBuilder<LedgerBills>(
      stream: reports,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("暂时无法读取本月流水"));
        final bills = snapshot.data;
        if (bills == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final totals = bills.month(widget.month);
        final left = plan.remaining(bills.entries[widget.month] ?? const []);
        final reserved = left.values.fold(0, (sum, n) => sum + n);
        final past = widget.month.isBefore(
          LedgerInterval.month.start(DateTime.now()),
        );
        final available = past
            ? totals.balance
            : totals.balance - reserved - plan.savings;
        final dark = theme.brightness == Brightness.dark;
        final green = dark ? const Color(0xff86deba) : const Color(0xff11634a);
        final red = dark ? const Color(0xffffada8) : const Color(0xffa13740);
        final tone = available == 0
            ? colors.onSurfaceVariant
            : available > 0
            ? green
            : red;
        final largest = totals.income > totals.expense
            ? totals.income
            : totals.expense;
        final heading = past
            ? (available == 0
                  ? "当月收支持平"
                  : available > 0
                  ? "当月盈余"
                  : "当月赤字")
            : (available < 0 ? "本月资金缺口" : "本月还能花");
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Text(past ? "月度收支" : "可支配收入", style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  tone.withValues(alpha: .09),
                  colors.surface,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        available == 0
                            ? Icons.balance
                            : available > 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: tone,
                      ),
                      const SizedBox(width: 8),
                      Text(heading, style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "¥ ${_money(available.abs())}",
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    past ? "当月已入账收入 − 当月已花支出" : "收支结余 − 待付预留 − 储蓄目标",
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final (label, amount, color, icon) in [
              ("已入账收入", totals.income, green, Icons.south_west),
              ("已花支出", totals.expense, red, Icons.north_east),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 6),
                        Expanded(child: Text(label)),
                        Text(
                          _money(amount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: largest == 0 ? 0 : amount / largest,
                      color: color,
                      backgroundColor: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            if (!past || plan.savings > 0 || plan.limits.isNotEmpty) ...[
              const Divider(height: 32),
              if (!past || plan.savings > 0)
                _PlanTile(
                  name: "储蓄目标",
                  detail: _money(plan.savings),
                  icon: Icons.savings_outlined,
                  onEdit: () => editAmount(null, "储蓄目标"),
                  onActions: plan.savings == 0
                      ? null
                      : () => actions(null, "储蓄目标"),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      past ? "当月预留记录" : "必要开销预留",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!past)
                    TextButton.icon(
                      onPressed: addReserve,
                      icon: const Icon(Icons.add),
                      label: const Text("添加"),
                    ),
                ],
              ),
              if (!past)
                Text(
                  "待付合计 ¥ ${_money(reserved)}",
                  style: theme.textTheme.bodyMedium,
                ),
              for (final entry in plan.limits.entries)
                _PlanTile(
                  name: cats.get(entry.key)?.name ?? "已移除分类",
                  icon: Icons.bookmark_outline,
                  subtitle: "月计划 ${_money(entry.value)}",
                  detail: "${past ? '未用' : '待付'} ${_money(left[entry.key]!)}",
                  onEdit: () => editAmount(
                    entry.key,
                    cats.get(entry.key)?.name ?? "已移除分类",
                  ),
                  onActions: () =>
                      actions(entry.key, cats.get(entry.key)?.name ?? "已移除分类"),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.name,
    required this.detail,
    required this.icon,
    required this.onEdit,
    required this.onActions,
    this.subtitle,
  });
  final String name, detail;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(name),
    subtitle: Wrap(
      spacing: 12,
      children: [if (subtitle != null) Text(subtitle!), Text(detail)],
    ),
    onTap: onEdit,
    onLongPress: onActions,
    trailing: IconButton(
      tooltip: onActions == null ? "设置$name" : "管理$name",
      icon: Icon(onActions == null ? Icons.edit_outlined : Icons.more_horiz),
      onPressed: onActions ?? onEdit,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.label, required this.original});
  final String label;
  final int original;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final controller = TextEditingController(
    text: widget.original == 0
        ? ""
        : (widget.original / 100).toStringAsFixed(2),
  );
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final text = controller.text.trim();
    if (!RegExp(r"^\d{1,10}(\.\d{1,2})?$").hasMatch(text)) {
      setState(() => error = "请输入金额，最多两位小数");
      return;
    }
    Navigator.pop(context, (double.parse(text) * 100).round());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: (_) => submit(),
      decoration: InputDecoration(
        labelText: "本月计划金额（元）",
        helperText: "填 0 可取消预留",
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("取消"),
      ),
      FilledButton(onPressed: submit, child: const Text("保存")),
    ],
  );
}
