import "package:flow/data/money.dart";
import "package:flow/data/single_currency_flow.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flutter/material.dart";

/// Shows settled spending first, with income and net flow alongside it.
class LedgerFlowSummary extends StatelessWidget {
  const LedgerFlowSummary({super.key, required this.flow});

  final SingleCurrencyFlow flow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = colors.brightness == Brightness.light;
    final card = light ? const Color(0xFFFFF6E5) : colors.surfaceContainer;
    final edge = light ? const Color(0xFFF0DDBD) : colors.outlineVariant;
    final expense = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.north_east_rounded,
              size: 16,
              color: light ? const Color(0xFF9A501A) : colors.onSurface,
            ),
            const SizedBox(width: 4),
            Flexible(child: Text("本期支出", style: theme.textTheme.labelMedium)),
          ],
        ),
        const SizedBox(height: 4),
        MoneyText(
          flow.totalExpense,
          displayAbsoluteAmount: true,
          autoSize: true,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final secondary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryValue(label: "收入", money: flow.totalIncome),
        const SizedBox(height: 6),
        _SummaryValue(label: "结余", money: flow.totalFlow),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, size) {
          if (size.maxWidth < 255 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                expense,
                Divider(height: 20, color: edge),
                secondary,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: expense),
              Container(
                height: 50,
                width: 1,
                color: edge,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(flex: 4, child: secondary),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.money});
  final String label;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: MoneyText(
            money,
            autoSize: true,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
