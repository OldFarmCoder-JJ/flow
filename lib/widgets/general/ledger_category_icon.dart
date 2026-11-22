import "package:flow/data/merchant_mark.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/entity/category.dart";
import "package:flow/data/dining_expense_emoji.dart";
import "package:flow/data/flow_icon.dart";
import "package:flow/widgets/general/flow_icon.dart";
import "package:flutter/material.dart";

/// Stable category accents shared by entry, history and reports.
Color ledgerCategoryAccent(Category? category) {
  final custom = category?.colorScheme?.primary;
  if (custom != null) return custom;
  final name = category?.name.trim() ?? "";
  return switch (name) {
    "订阅" => const Color(0xff55849a),
    "购物" => const Color(0xFF8175DF),
    "餐饮" => const Color(0xFF27AA84),
    "娱乐" => const Color(0xFFEF8854),
    "游戏" || "游戏账号" => const Color(0xFFE7B83D),
    "医疗" => const Color(0xFF4AAAD1),
    "交通" => const Color(0xFF528AD4),
    "住房" => const Color(0xFFD78368),
    "日用" => const Color(0xFF68A46D),
    "通讯" => const Color(0xFF438F9C),
    "数码" => const Color(0xFF687DC2),
    "零食" => const Color(0xFFE59399),
    "饮料" => const Color(0xFFC09153),
    "品茶" => const Color(0xFF8BA65A),
    "礼金" || "红包" => const Color(0xFFD96C82),
    "工资" => const Color(0xFF388D76),
    "兼职" => const Color(0xFF579EBD),
    "理财" || "基金" => const Color(0xFF729750),
    "维修" || "办公" => const Color(0xFF658399),
    "水电" => const Color(0xFF519DAE),
    "服饰" || "亲友" => const Color(0xFFB578AB),
    "其它" || "其他" || "" => const Color(0xFF8896A3),
    _ => const [
      Color(0xFF7986C6),
      Color(0xFFB67E8C),
      Color(0xFF6F9A86),
      Color(0xFFB78D58),
      Color(0xFF688CAB),
      Color(0xFFAF83B0),
    ][name.runes.fold<int>(0, (hash, rune) => hash * 31 + rune) % 6],
  };
}

/// Renders the stored glyph on a matching tonal plate.
class LedgerCategoryIcon extends StatelessWidget {
  const LedgerCategoryIcon({
    super.key,
    required this.category,
    this.diameter = 42,
    this.selected = false,
    this.expenseTitle,
    this.incomeTitle,
  });

  final Category? category;

  /// Supply the entry title only when showing an individual expense.
  final String? expenseTitle;
  final String? incomeTitle;
  final double diameter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = ledgerCategoryAccent(category);
    final ink = Color.lerp(
      accent,
      dark ? Colors.white : Colors.black,
      dark ? .55 : .32,
    )!;
    final plate = Color.alphaBlend(
      accent.withValues(alpha: dark ? .24 : .12),
      colors.surface,
    );
    final emoji = diningExpenseEmoji(category?.name, expenseTitle);
    final glyph = emoji == null ? category?.icon : FlowIconData.emoji(emoji);
    final fallback = SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plate,
          border: selected ? Border.all(color: ink, width: 2) : null,
          borderRadius: BorderRadius.circular(diameter * .34),
        ),
        child: Center(
          child: glyph == null
              ? Icon(Icons.category_outlined, color: ink, size: diameter * .55)
              : FlowIcon(
                  glyph,
                  color: ink,
                  fill: selected ? 1 : 0,
                  size: diameter * (emoji == null ? .55 : .76),
                ),
        ),
      ),
    );
    final title = expenseTitle ?? incomeTitle;
    if (title == null || title.isEmpty) return fallback;
    return ListenableBuilder(
      listenable: LocalPreferences().merchantMarks.valueNotifier,
      child: fallback,
      builder: (_, child) {
        final brand = MerchantMark.match(title);
        return brand == null ? child! : MerchantBadge(brand, size: diameter);
      },
    );
  }
}
