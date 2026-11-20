import "package:flow/data/ledger_stats.dart";
import "package:flow/data/transaction_filter.dart";
import "package:flow/data/transactions_filter/time_range.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/services/transactions.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:moment_dart/moment_dart.dart";
import "package:share_plus/share_plus.dart";

/// Previews the exact monthly summary that can be shared with an AI assistant.
class LedgerAnalysisPage extends StatefulWidget {
  const LedgerAnalysisPage({super.key});

  @override
  State<LedgerAnalysisPage> createState() => _LedgerAnalysisPageState();
}

class _LedgerAnalysisPageState extends State<LedgerAnalysisPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<String?> report = loadMonth();

  Future<String?> loadMonth() async {
    final start = month;
    final end = DateTime(start.year, start.month + 1);
    final filter = TransactionFilter(
      range: TransactionFilterTimeRange.fromTimeRange(
        CustomTimeRange(start, end.subtract(const Duration(milliseconds: 1))),
      ),
    );
    final rows = await TransactionsService().findMany(filter);
    return monthlyAnalysisText(start, rows, DateTime.now());
  }

  void move(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    report = loadMonth();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("AI 账本分析")),
    body: SafeArea(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: "上个月",
                onPressed: () => move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text("${month.year} 年 ${month.month} 月"),
              IconButton(
                tooltip: "下个月",
                onPressed:
                    DateTime(
                      month.year,
                      month.month + 1,
                    ).isAfter(DateTime.now())
                    ? null
                    : () => move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<String?>(
              future: report,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => move(0),
                      child: const Text("读取失败，点击重试"),
                    ),
                  );
                }
                final text = snapshot.data;
                if (text == null) {
                  return const Center(child: Text("这个月还没有可分析的收支"));
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(text),
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("已复制，可直接粘贴给 ChatGPT"),
                                  ),
                                );
                              }
                            },
                            child: const Text("复制给 ChatGPT"),
                          ),
                          FilledButton(
                            onPressed: () async {
                              try {
                                await SharePlus.instance.share(
                                  ShareParams(text: text),
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("分享失败，可以复制月报"),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text("分享月报"),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Aggregates settled entries by currency without including transaction notes.
String? monthlyAnalysisText(
  DateTime month,
  Iterable<Transaction> rows,
  DateTime now,
) {
  final groups = <String, List<Transaction>>{};
  for (final row in rows) {
    final date = row.transactionDate.toLocal();
    if (!isSettledLedgerEntry(row, now) ||
        date.year != month.year ||
        date.month != month.month) {
      continue;
    }
    (groups[row.currency] ??= []).add(row);
  }
  if (groups.isEmpty) return null;
  final lines = <String>["${month.year} 年 ${month.month} 月个人收支汇总"];
  for (final currency in groups.keys.toList()..sort()) {
    double income = 0, expense = 0;
    final categories = <String, double>{};
    for (final row in groups[currency]!) {
      if (row.amount >= 0) {
        income += row.amount;
        continue;
      }
      expense -= row.amount;
      final category = row.category.target?.name ?? "未分类";
      categories.update(
        category,
        (value) => value - row.amount,
        ifAbsent: () => -row.amount,
      );
    }
    lines.addAll([
      "",
      currency == "CNY"
          ? "${groups[currency]!.length} 笔"
          : "$currency · ${groups[currency]!.length} 笔",
      "收入 ${income.toStringAsFixed(2)}，支出 ${expense.toStringAsFixed(2)}，结余 ${(income - expense).toStringAsFixed(2)}",
    ]);
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final item in sorted) {
      lines.add("${item.key}：${item.value.toStringAsFixed(2)}");
    }
  }
  lines.add("\n请根据以上汇总分析主要支出、各分类占比和下月可尝试的调整。请区分账本事实和建议，跨币种分别分析。");
  return lines.join("\n");
}
