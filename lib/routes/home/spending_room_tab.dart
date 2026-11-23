import "dart:async";

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

import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/recurring_transaction.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/services/monthly_charges.dart";
import "package:flow/services/transactions.dart";
part "monthly_charge_setup.dart";

final _format = NumberFormat("#,##0.00", "zh_CN");
String _money(int cents) => _format.format(cents / 100);

/// Shows spendable income after recorded expenses and monthly reserves.
class SpendingRoomTab extends StatefulWidget {
  const SpendingRoomTab({super.key});

  @override
  State<SpendingRoomTab> createState() => _SpendingRoomTabState();
}

class _SpendingRoomTabState extends State<SpendingRoomTab> {
  DateTime? selected;
  DateTime today = DateUtils.dateOnly(DateTime.now());
  late final AppLifecycleListener lifecycle;
  Timer? timer;
  DateTime get current => LedgerInterval.month.start(today);
  DateTime get month => selected ?? current;

  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(onResume: refreshDay);
    refreshDay();
  }

  void refreshDay() {
    final now = DateTime.now();
    final day = DateUtils.dateOnly(now);
    if (day != today) setState(() => today = day);
    timer?.cancel();
    timer = Timer(
      DateTime(day.year, day.month, day.day + 1).difference(now),
      refreshDay,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    lifecycle.dispose();
    super.dispose();
  }

  void showMonth(DateTime value) => setState(() {
    selected = value == current ? null : value;
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IconButton(
            tooltip: "上个月",
            icon: const Icon(Icons.chevron_left),
            onPressed: () => showMonth(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: TextButton(
              onPressed: selected == null ? null : () => showMonth(current),
              child: Text(
                "${month.year}年${month.month}月${selected == null ? '' : ' · 回本月'}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: "下个月",
            icon: const Icon(Icons.chevron_right),
            onPressed: month.isBefore(current)
                ? () => showMonth(DateTime(month.year, month.month + 1))
                : null,
          ),
        ],
      ),
      Expanded(
        child: _MonthlyRoom(key: ValueKey((month, today)), month: month),
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
    final edit = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(context, "edit"),
            ),
            if (id != null &&
                widget.month == LedgerInterval.month.start(DateTime.now()) &&
                !MonthlyCharges.active().any(
                  (r) => r.template.categoryUuid == id,
                ))
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text("改为每月 1 日扣款"),
                onTap: () => Navigator.pop(context, "repeat"),
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(id == null ? "移除储蓄目标" : "删除这项预留"),
              onTap: () => Navigator.pop(context, "delete"),
            ),
          ],
        ),
      ),
    );
    if (!mounted || edit == null) return;
    if (edit == "repeat") {
      await addCharge(id);
      return;
    }
    if (edit == "edit") {
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

  Future<void> addCharge([String? categoryId]) async {
    final rules = MonthlyCharges.active();
    final choices = CategoriesProvider.of(context)
        .categoriesFor(TransactionType.expense)
        .where((c) => !rules.any((r) => r.template.categoryUuid == c.uuid))
        .toList();
    final accounts = AccountsProvider.of(
      context,
    ).activeAccounts.where((a) => a.currency == ledgerCurrency).toList();
    if (choices.isEmpty || accounts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("需要一个可用的人民币账户和支出分类")));
      return;
    }
    final result = await showModalBottomSheet<(Account, Category, int, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ChargeSetup(
        initial: choices.where((c) => c.uuid == categoryId).firstOrNull,
        categories: choices,
        accounts: accounts,
        limits: plan.limits,
      ),
    );
    if (!mounted || result == null) return;
    final (a, c, n, next) = result;
    final now = DateTime.now();
    try {
      MonthlyCharges.create(
        a,
        c,
        n,
        DateTime(now.year, now.month + (next ? 1 : 0)),
      );
      if (!next && plan.limits.containsKey(c.uuid)) await saveAmount(c.uuid, 0);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("无法建立扣款：$e")));
      }
    }
  }

  Future<void> manageCharge(RecurringTransaction rule) async {
    final row = MonthlyCharges.entry(rule, widget.month);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row != null)
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(row.isDeleted == true ? "恢复本月扣款" : "仅跳过本月"),
                subtitle: const Text("其他月份继续执行"),
                onTap: () => Navigator.pop(c, "toggle"),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("修改以后每月金额"),
              onTap: () => Navigator.pop(c, "edit"),
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text("停止以后扣款"),
              subtitle: const Text("保留已记入的流水"),
              onTap: () => Navigator.pop(c, "stop"),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == "toggle" && row != null) {
      if (row.isDeleted == true) {
        TransactionsService().recoverFromBinSync(row.id);
      } else {
        TransactionsService().moveToBinSync(row.id);
      }
    } else if (action == "stop") {
      MonthlyCharges.stop(rule);
    } else if (action == "edit") {
      final cents = await showDialog<int>(
        context: context,
        builder: (_) => _AmountDialog(
          label: "修改以后每月金额",
          original: (rule.template.amount.abs() * 100).round(),
          charge: true,
        ),
      );
      if (cents == null || !mounted) return;
      MonthlyCharges.changeAmount(rule, cents);
    }
    if (mounted) setState(() {});
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
        final rules = past ? <RecurringTransaction>[] : MonthlyCharges.active();
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
            if (past && (bills.entries[widget.month]?.isEmpty ?? true))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text("当月没有已入账流水")),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tone.withValues(alpha: .065),
                    colors.surface,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(heading, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "¥ ${_money(available.abs())}",
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: tone,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (!past && available > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "含今天还剩 ${_daysLeft(bills.now)} 天 · 日均可用 ¥ ${_money(available ~/ _daysLeft(bills.now))}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const Divider(height: 24),
                    _BalanceLine(
                      label: "已入账收入",
                      value: "+${_money(totals.income)}",
                      color: green,
                    ),
                    _BalanceLine(
                      label: "已花支出",
                      value: "−${_money(totals.expense)}",
                      color: red,
                    ),
                    if (!past) ...[
                      if (plan.limits.isNotEmpty)
                        _BalanceLine(
                          label: "尚需预留",
                          value: "−${_money(reserved)}",
                        ),
                      _BalanceLine(
                        label: "储蓄目标",
                        value: plan.savings == 0
                            ? "设置"
                            : "−${_money(plan.savings)}",
                        onTap: () => editAmount(null, "储蓄目标"),
                        onLongPress: plan.savings == 0
                            ? null
                            : () => actions(null, "储蓄目标"),
                      ),
                    ],
                  ],
                ),
              ),
            if (!past || plan.savings > 0 || plan.limits.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      past ? "当月计划记录" : "支出安排",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!past)
                    PopupMenuButton<String>(
                      tooltip: "添加支出安排",
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "＋ 添加",
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: "monthly", child: Text("每月固定扣款")),
                        PopupMenuItem(value: "once", child: Text("仅本月预留")),
                      ],
                      onSelected: (kind) {
                        if (kind == "monthly") {
                          addCharge();
                        } else {
                          addReserve();
                        }
                      },
                    ),
                ],
              ),
              if (past && plan.savings > 0)
                _BalanceLine(label: "当时的储蓄目标", value: _money(plan.savings)),
              if (!past) ...[
                if (rules.isEmpty && plan.limits.isEmpty)
                  Text(
                    "房租等固定支出可按月记账，临时开销可只预留本月。",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                for (final rule in rules)
                  Builder(
                    builder: (c) {
                      final row = MonthlyCharges.entry(rule, widget.month);
                      final startsLater = rule.template.transactionDate
                          .toLocal()
                          .isAfter(widget.month);
                      final status = startsLater
                          ? "下月开始"
                          : row == null
                          ? (rule.lastGeneratedTransactionDate == null
                                ? "待入账"
                                : "本月无扣款")
                          : row.isDeleted == true
                          ? "本月已跳过"
                          : "本月已记 ¥ ${_money((-row.amount * 100).round())}";
                      return _PlanTile(
                        name: rule.template.title ?? "必要扣款",
                        icon: Icons.event_repeat,
                        detail: status,
                        subtitle:
                            "每月 1 日 · ¥ ${_money((-rule.template.amount * 100).round())}",
                        onEdit: () => manageCharge(rule),
                        onActions: () => manageCharge(rule),
                      );
                    },
                  ),
              ],
              for (final entry in plan.limits.entries)
                _PlanTile(
                  name: cats.get(entry.key)?.name ?? "已移除分类",
                  icon: Icons.bookmark_outline,
                  subtitle: "月计划 ${_money(entry.value)}",
                  detail: "${past ? '未用' : '待付'} ${_money(left[entry.key]!)}",
                  onEdit: past
                      ? null
                      : () => editAmount(
                          entry.key,
                          cats.get(entry.key)?.name ?? "已移除分类",
                        ),
                  onActions: past
                      ? null
                      : () => actions(
                          entry.key,
                          cats.get(entry.key)?.name ?? "已移除分类",
                        ),
                ),
            ],
          ],
        );
      },
    );
  }
}

int _daysLeft(DateTime date) =>
    DateTime(date.year, date.month + 1, 0).day - date.day + 1;

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.label,
    required this.value,
    this.color,
    this.onTap,
    this.onLongPress,
  });
  final String label, value;
  final Color? color;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: onTap == null ? 32 : 48),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(label, style: theme.textTheme.bodyMedium),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
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
  final VoidCallback? onEdit;
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
    trailing: onEdit == null
        ? null
        : IconButton(
            tooltip: onActions == null ? "设置$name" : "管理$name",
            icon: Icon(
              onActions == null ? Icons.edit_outlined : Icons.more_horiz,
            ),
            onPressed: onActions ?? onEdit,
          ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.label,
    required this.original,
    this.charge = false,
  });
  final bool charge;
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
    if (widget.charge && double.parse(text) <= 0) {
      setState(() => error = "请输入大于零的金额");
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
        labelText: widget.charge ? "每月金额（元）" : "本月计划金额（元）",
        helperText: widget.charge ? null : "填 0 可取消预留",
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
