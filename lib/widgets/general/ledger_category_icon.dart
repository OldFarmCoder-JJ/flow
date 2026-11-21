import "package:flow/entity/category.dart";
import "package:flow/widgets/general/flow_icon.dart";
import "package:flutter/material.dart";

/// A category glyph shared by quick entry and chart rankings.
class LedgerCategoryIcon extends StatelessWidget {
  const LedgerCategoryIcon({
    super.key,
    required this.category,
    this.diameter = 42,
    this.selected = false,
    this.tint,
  });

  final Category? category;
  final double diameter;
  final bool selected;
  final Color? tint;

  static const _icons = <String, IconData>{
    "餐饮": Icons.restaurant_outlined,
    "购物": Icons.shopping_bag_outlined,
    "日用": Icons.cleaning_services_outlined,
    "交通": Icons.directions_bus_outlined,
    "零食": Icons.cookie_outlined,
    "健身": Icons.fitness_center_outlined,
    "娱乐": Icons.music_note_outlined,
    "通讯": Icons.phone_in_talk_outlined,
    "服饰": Icons.checkroom_outlined,
    "住房": Icons.home_outlined,
    "居家": Icons.chair_outlined,
    "数码": Icons.devices_outlined,
    "医疗": Icons.medical_services_outlined,
    "学习": Icons.school_outlined,
    "宠物": Icons.pets_outlined,
    "办公": Icons.work_outline,
    "维修": Icons.handyman_outlined,
    "亲友": Icons.people_outline,
    "水电": Icons.bolt_outlined,
    "游戏": Icons.sports_esports_outlined,
    "游戏账号": Icons.sports_esports_outlined,
    "饮料": Icons.local_drink_outlined,
    "品茶": Icons.emoji_food_beverage_outlined,
    "基金": Icons.savings_outlined,
    "快递": Icons.inventory_2_outlined,
    "旅行": Icons.luggage_outlined,
    "工资": Icons.account_balance_wallet_outlined,
    "奖金": Icons.workspace_premium_outlined,
    "兼职": Icons.badge_outlined,
    "理财": Icons.trending_up,
    "红包": Icons.redeem_outlined,
    "退款": Icons.assignment_return_outlined,
    "其他": Icons.category_outlined,
    "其它": Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final category = this.category;
    final glyph = _icons[category?.name];
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : tint?.withValues(alpha: .18) ?? colors.surfaceContainer,
          borderRadius: BorderRadius.circular(diameter * .32),
        ),
        child: Center(
          child: glyph != null || category == null
              ? Icon(
                  glyph ?? Icons.category_outlined,
                  color: foreground,
                  size: diameter * .52,
                )
              : FlowIcon(
                  category.icon,
                  color: foreground,
                  fill: 0,
                  size: diameter * .52,
                ),
        ),
      ),
    );
  }
}
