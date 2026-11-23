part of "spending_room_tab.dart";

/// Monthly debits use a real ledger account and an explicitly selected start month.
class _ChargeSetup extends StatefulWidget {
  const _ChargeSetup({
    required this.initial,
    required this.categories,
    required this.accounts,
    required this.limits,
  });
  final Category? initial;
  final List<Category> categories;
  final List<Account> accounts;
  final Map<String, int> limits;
  @override
  State<_ChargeSetup> createState() => _ChargeSetupState();
}

class _ChargeSetupState extends State<_ChargeSetup> {
  late Category? category = widget.initial;
  late Account account = widget.accounts.first;
  late final amount = TextEditingController(
    text: widget.initial == null
        ? ""
        : ((widget.limits[widget.initial!.uuid] ?? 0) / 100).toStringAsFixed(2),
  );
  bool next = false;
  bool amountEdited = false;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void selectCategory(Category? value) => setState(() {
    category = value;
    if (!amountEdited) {
      final cents = widget.limits[value?.uuid];
      amount.text = cents == null ? "" : (cents / 100).toStringAsFixed(2);
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final first = DateTime(now.year, now.month + (next ? 1 : 0));
    final raw = amount.text.trim();
    final valid =
        category != null &&
        RegExp(r"^\d{1,10}(\.\d{1,2})?$").hasMatch(raw) &&
        double.parse(raw) > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("每月固定扣款", style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              _ChargeField(
                label: "支出分类",
                child: DropdownButtonFormField<Category>(
                  initialValue: category,
                  isExpanded: true,
                  hint: const Text("选择分类"),
                  items: [
                    for (final c in widget.categories)
                      DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: selectCategory,
                ),
              ),
              _ChargeField(
                label: "每月金额",
                child: TextField(
                  controller: amount,
                  onChanged: (v) => setState(() => amountEdited = v.isNotEmpty),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixText: "¥ ",
                    hintText: "0.00",
                  ),
                ),
              ),
              _ChargeField(
                label: "记入账户",
                child: DropdownButtonFormField<Account>(
                  initialValue: account,
                  isExpanded: true,
                  items: [
                    for (final a in widget.accounts)
                      DropdownMenuItem(value: a, child: Text(a.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => account = v);
                  },
                ),
              ),
              _ChargeField(
                label: "首次记账",
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text("从本月开始")),
                    ButtonSegment(value: true, label: Text("从下月开始")),
                  ],
                  selected: {next},
                  onSelectionChanged: (values) =>
                      setState(() => next = values.single),
                ),
              ),
              Text(
                next
                    ? "${first.year}年${first.month}月1日首次记入支出。"
                    : "保存后记入${first.month}月1日的支出。本月已经记过，可选下月开始。",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!next && widget.limits.containsKey(category?.uuid))
                const Text("将替换该分类本月的预留。"),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(context, (
                        account,
                        category!,
                        (double.parse(raw) * 100).round(),
                        next,
                      ))
                    : null,
                child: const Text("保存"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChargeField extends StatelessWidget {
  const _ChargeField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}
