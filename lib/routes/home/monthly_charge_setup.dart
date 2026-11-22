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
  String? error;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text("添加每月扣款"),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Category>(
            initialValue: category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: "支出分类"),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(value: c, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() {
              category = v;
              final n = widget.limits[v?.uuid];
              amount.text = n == null ? "" : (n / 100).toStringAsFixed(2);
              error = null;
            }),
          ),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: "每月金额（元）", errorText: error),
          ),
          DropdownButtonFormField<Account>(
            initialValue: account,
            isExpanded: true,
            decoration: const InputDecoration(labelText: "记入账户"),
            items: [
              for (final a in widget.accounts)
                DropdownMenuItem(value: a, child: Text(a.name)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => account = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("从下个月开始"),
            value: next,
            onChanged: (v) => setState(() => next = v),
          ),
          Text(next ? "下月起，每月 1 日记一笔支出。" : "保存后立即记入本月 1 日。若本月已记过，请选下月开始。"),
          if (!next && widget.limits.containsKey(category?.uuid))
            const Text("这会替换该分类本月的待付预留。"),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("取消"),
      ),
      FilledButton(
        onPressed: () {
          final c = category;
          final raw = amount.text.trim();
          if (c == null ||
              !RegExp(r"^\d{1,10}(\.\d{1,2})?$").hasMatch(raw) ||
              double.parse(raw) <= 0) {
            setState(() => error = "请选择分类并填写正数金额");
            return;
          }
          Navigator.pop(context, (
            account,
            c,
            (double.parse(raw) * 100).round(),
            next,
          ));
        },
        child: const Text("保存"),
      ),
    ],
  );
}
