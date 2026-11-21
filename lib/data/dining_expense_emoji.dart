/// Food names take priority over shop names in a dining expense title.
final _foods = <(String, RegExp)>[
  ("🍔", RegExp(r"汉堡(?!王)|巨无霸|麦香鸡|麦香鱼|麦满分|芝士堡|鸡腿堡|牛肉堡|板烧堡")),
  ("🍟", RegExp(r"薯条|薯角")),
  ("🍗", RegExp(r"炸鸡|鸡翅|鸡腿|鸡块|麦乐鸡|鸡米花")),
  ("🦆", RegExp(r"烤鸭|鸭脖|鸭腿")),
  ("🍜", RegExp(r"拉面|板面|拌面|汤面|炒面|刀削面|阳春面|牛肉面|泡面|米线|米粉|螺蛳粉|酸辣粉")),
  ("🍚", RegExp(r"盖[码浇]饭|炒饭|煲仔饭|卤肉饭|便当|米饭")),
  ("🥟", RegExp(r"饺子|水饺|锅贴|馄饨|抄手|包子|小笼包")),
  ("🍲", RegExp(r"牛肉汤|羊肉汤|麻辣烫|冒菜|火锅|砂锅")),
  ("🍢", RegExp(r"炸串|烤串|烧烤|串串")),
  ("🍕", RegExp(r"披萨|比萨")),
  ("🍰", RegExp(r"蛋糕|提拉米苏")),
  ("🥚", RegExp(r"鸡蛋|茶叶蛋|水煮蛋|卤蛋|煎蛋|荷包蛋|蒸蛋")),
  ("🥤", RegExp(r"可乐|汽水")),
  ("🧋", RegExp(r"奶茶|珍珠鲜奶")),
  ("☕", RegExp(r"咖啡|拿铁|卡布奇诺")),
  (
    "🍔",
    RegExp(
      r"麦当劳|金拱门|麦麦|肯德基|德克士|汉堡王|华莱士|\bkfc\b|mcdonald",
      caseSensitive: false,
    ),
  ),
];

/// Returns a display-only glyph for a named food or fast-food shop.
/// Generic titles such as “午餐” keep the category's chosen icon.
String? diningExpenseEmoji(String? categoryName, String? title) {
  if (categoryName?.trim() != "餐饮" || title == null || title.isEmpty) {
    return null;
  }
  for (final (emoji, pattern) in _foods) {
    if (pattern.hasMatch(title) || title.contains(emoji)) return emoji;
  }
  return null;
}
