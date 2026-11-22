import "dart:convert";
import "package:flutter/material.dart";
import "package:flow/prefs/local_preferences.dart";

/// A local wordmark matched against an individual entry's name.
class MerchantMark {
  const MerchantMark(this.name, this.mark, this.color, this.aliases);
  final String name, mark, aliases;
  final int color;
  static const defaults = [
    MerchantMark("好想来", "好想来", 0xffab3038, "好想来"),
    MerchantMark("赵一鸣零食", "赵一鸣", 0xffac4827, "赵一鸣"),
    MerchantMark(
      "7-Eleven",
      "7·11",
      0xff147251,
      "711 7-11 7eleven 7-eleven 柒拾壹",
    ),
    MerchantMark("肯德基", "KFC", 0xffa32637, "肯德基 kfc 疯狂星期四 吮指原味鸡"),
    MerchantMark("麦当劳", "M", 0xffa52926, "麦当劳 金拱门 麦麦 mcdonald"),
    MerchantMark("智租", "智租", 0xff20568c, "智租"),
    MerchantMark("塔斯汀", "塔", 0xffa73430, "塔斯汀"),
    MerchantMark("瑞幸咖啡", "luckin", 0xff214599, "瑞幸 luckin"),
    MerchantMark("蜜雪冰城", "蜜雪", 0xffb82a3c, "蜜雪冰城 蜜雪"),
    MerchantMark("百度网盘", "网盘", 0xff235ca1, "百度网盘"),
    MerchantMark("夸克", "Q", 0xff454693, "夸克"),
    MerchantMark("好滋味", "好滋味", 0xffa9571e, "好滋味"),
    MerchantMark("魔爪", "爪", 0xff305d26, "魔爪"),
    MerchantMark("巴比馒头", "巴比", 0xff9f5234, "巴比"),
    MerchantMark("沙县小吃", "沙县", 0xff93452d, "沙县"),
    MerchantMark("美团优选", "优选", 0xff795919, "美团优选"),
    MerchantMark("全家便利店", "Family", 0xff197b70, "全家便利店 全家"),
    MerchantMark("汉堡王", "BK", 0xff963e29, "汉堡王 burgerking"),
    MerchantMark("德克士", "D", 0xff236444, "德克士 dicos"),
    MerchantMark("华莱士", "华", 0xff217148, "华莱士"),
    MerchantMark("萨莉亚", "萨莉亚", 0xff9a362e, "萨莉亚 萨利亚"),
    MerchantMark("蜂鸟众包", "蜂鸟", 0xff1c5d94, "蜂鸟众包"),
    MerchantMark("美团", "美团", 0xff795919, "美团"),
    MerchantMark("罗森", "LAWSON", 0xff245184, "罗森 lawson"),
    MerchantMark("霸王茶姬", "茶姬", 0xff754344, "霸王茶姬"),
    MerchantMark("Codex", "CX", 0xff364658, "codex"),
    MerchantMark("英雄联盟", "LOL", 0xff785e32, "英雄联盟"),
  ];
  static String? _cachedRaw;
  static List<MerchantMark> _cached = defaults;
  static List<MerchantMark> get all {
    final raw = LocalPreferences().merchantMarks.value;
    if (raw != _cachedRaw) {
      _cached = raw == null
          ? defaults
          : [
              for (final r in jsonDecode(raw) as List)
                MerchantMark(r[0], r[1], r[2], r[3]),
            ];
      _cachedRaw = raw;
    }
    return _cached;
  }

  static Future<void> save(List<MerchantMark> items) async {
    await LocalPreferences().merchantMarks.set(
      jsonEncode([
        for (final m in items) [m.name, m.mark, m.color, m.aliases],
      ]),
    );
  }

  static List<MerchantMark>? _indexed;
  static List<(String, MerchantMark)> _aliases = [];
  static final _sevenEleven = RegExp(r"(^|[^0-9])711([^0-9]|$)");

  static MerchantMark? match(String title) {
    final marks = all;
    if (!identical(_indexed, marks)) {
      _aliases = [
        for (final mark in marks)
          for (final alias in mark.keys) (alias, mark),
      ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
      _indexed = marks;
    }
    final text = title.toLowerCase();
    for (final (alias, mark) in _aliases) {
      if (alias == "711" ? _sevenEleven.hasMatch(text) : text.contains(alias)) {
        return mark;
      }
    }
    return null;
  }

  Set<String> get keys =>
      {name.toLowerCase(), ...aliases.toLowerCase().split(RegExp(r"[，,、\s]+"))}
        ..remove("");
}

/// Compact lettering and a contrasting stripe for transaction and picker rows.
class MerchantBadge extends StatelessWidget {
  const MerchantBadge(this.brand, {super.key, this.size = 42});
  final MerchantMark brand;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: brand.name,
    child: Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(brand.color),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size * .12,
            child: Row(
              children: [
                for (final stripe in switch (brand.mark) {
                  "7·11" => const [
                    Color(0xffeb853b),
                    Colors.white,
                    Color(0xffda4936),
                  ],
                  "KFC" => const [
                    Colors.white,
                    Color(0xffb02434),
                    Colors.white,
                    Color(0xffb02434),
                    Colors.white,
                  ],
                  "M" => const [Color(0xffffd751)],
                  _ => [
                    Colors.white.withValues(alpha: .44),
                    Colors.white.withValues(alpha: .16),
                  ],
                })
                  Expanded(
                    child: ColoredBox(
                      color: stripe,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * .09),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  brand.mark,
                  maxLines: 1,
                  style: TextStyle(
                    color: brand.mark == "M"
                        ? const Color(0xffffd751)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * .56,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
