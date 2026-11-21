import "package:flow/data/flow_icon.dart";
import "package:flow/entity/_base.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/flow_color_scheme.dart";
import "package:flow/utils/json/utc_datetime_converter.dart";
import "package:flutter/material.dart";
import "package:json_annotation/json_annotation.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:objectbox/objectbox.dart";
import "package:uuid/uuid.dart";

part "category.g.dart";

@Entity()
@JsonSerializable(explicitToJson: true, converters: [UTCDateTimeConverter()])
class Category implements EntityBase {
  @JsonKey(includeFromJson: false, includeToJson: false)
  int id;

  @override
  @Unique()
  String uuid;

  @Property(type: PropertyType.date)
  DateTime createdDate;

  static const int maxNameLength = 48;

  @Unique()
  String name;

  @Backlink("category")
  @JsonKey(includeFromJson: false, includeToJson: false)
  final transactions = ToMany<Transaction>();

  String iconCode;

  String? colorSchemeName;

  @Transient()
  FlowColorScheme? get colorScheme => getThemeStrict(colorSchemeName);

  /// Resolves a stored icon, using a recognizable glyph for imported defaults.
  @Transient()
  FlowIconData get icon {
    final stored = FlowIconData.tryParse(iconCode);
    const generic = Symbols.category_rounded;
    if (stored != null &&
        (stored is! IconFlowIcon ||
            stored.iconData.codePoint != generic.codePoint ||
            stored.iconData.fontFamily != generic.fontFamily)) {
      return stored;
    }
    return FlowIconData.icon(_fallbackIcons[name] ?? generic);
  }

  static const _fallbackIcons = <String, IconData>{
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
    "礼金": Icons.card_giftcard_outlined,
    "奖金": Icons.workspace_premium_outlined,
    "兼职": Icons.badge_outlined,
    "理财": Icons.trending_up,
    "红包": Icons.redeem_outlined,
    "退款": Icons.assignment_return_outlined,
    "其他": Icons.category_outlined,
    "其它": Icons.category_outlined,
  };

  Category({
    this.id = 0,
    required this.name,
    required this.iconCode,
    DateTime? createdDate,
    this.colorSchemeName,
  }) : createdDate = createdDate ?? DateTime.now(),
       uuid = const Uuid().v4();

  Category.preset({
    required this.name,
    required this.iconCode,
    required this.uuid,
    this.colorSchemeName,
  }) : createdDate = DateTime.now(),
       id = -1;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
