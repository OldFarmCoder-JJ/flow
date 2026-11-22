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
        final available = totals.balance - reserved - plan.savings;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Text("可支配收入", style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    available < 0 ? "本月资金缺口" : "本月还能花",
                    style: theme.textTheme.titleSmall,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "¥ ${_money(available.abs())}",
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (totals.income == 0) const Text("本月尚无已入账收入。"),
                  const Text("已入账收入减去已花、待付预留和储蓄目标。"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final item in [
              ("已入账收入", totals.income),
              ("已花支出", totals.expense),
              ("待付预留", reserved),
            ])
              ListTile(
                dense: true,
                title: Text(item.$1),
                trailing: Text(_money(item.$2)),
              ),
            ListTile(
              title: const Text("储蓄目标"),
              trailing: Text(_money(plan.savings)),
              leading: const Icon(Icons.savings_outlined),
              onTap: () => editAmount(null, "储蓄目标"),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text("必要开销预留", style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: addReserve,
                  icon: const Icon(Icons.add),
                  label: const Text("添加"),
                ),
              ],
            ),
            Text(
              "填这个月预计要花的总额。记入同一分类后，待付金额会自动减少。",
              style: theme.textTheme.bodySmall,
            ),
            for (final entry in plan.limits.entries)
              ListTile(
                title: Text(cats.get(entry.key)?.name ?? "已移除分类"),
                subtitle: Text("月计划 ${_money(entry.value)}"),
                trailing: Text("待付 ${_money(left[entry.key]!)}"),
                onTap: () =>
                    editAmount(entry.key, cats.get(entry.key)?.name ?? "已移除分类"),
              ),
          ],
        );
      },
    );
  }
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
