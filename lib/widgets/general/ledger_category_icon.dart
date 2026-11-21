import "package:flow/entity/category.dart";
import "package:flow/widgets/general/flow_icon.dart";
import "package:flutter/material.dart";

/// Stable category accents shared by entry, history and reports.
Color ledgerCategoryAccent(Category? category) {
  final custom = category?.colorScheme?.primary;
  if (custom != null) return custom;
  const orange = Color(0xFFC45A17);
  const violet = Color(0xFF7850B6);
  const blue = Color(0xFF2C6EAF);
  const jade = Color(0xFF16836B);
  const rose = Color(0xFFB64469);
  const ochre = Color(0xFFA16B0D);
  const slate = Color(0xFF536A80);
  final name = category?.name.trim() ?? "";
  return switch (name) {
    "餐饮" || "零食" || "快递" => orange,
    "购物" || "娱乐" || "游戏" || "游戏账号" => violet,
    "交通" || "通讯" || "数码" || "旅行" => blue,
    "日用" || "健身" || "工资" || "理财" || "基金" || "退款" => jade,
    "礼金" || "红包" || "服饰" || "亲友" || "医疗" => rose,
    "住房" || "居家" || "学习" || "宠物" || "饮料" || "品茶" || "奖金" || "水电" => ochre,
    "办公" || "维修" || "兼职" || "其他" || "其它" || "" => slate,
    _ => const [
      orange,
      violet,
      blue,
      jade,
      rose,
      ochre,
      slate,
    ][name.runes.fold<int>(0, (sum, rune) => sum * 31 + rune) % 7],
  };
}

/// Renders the stored glyph on a matching tonal plate.
class LedgerCategoryIcon extends StatelessWidget {
  const LedgerCategoryIcon({
    super.key,
    required this.category,
    this.diameter = 42,
    this.selected = false,
  });

  final Category? category;
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
      dark ? .55 : .14,
    )!;
    final plate = Color.alphaBlend(
      accent.withValues(alpha: dark ? .24 : .12),
      colors.surface,
    );
    final glyph = category?.icon;
    return SizedBox.square(
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
                  size: diameter * .55,
                ),
        ),
      ),
    );
  }
}
