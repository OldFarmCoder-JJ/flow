import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/objectbox.g.dart";

const _subscriptions = {
  "codex",
  "cdoex",
  "codex会员",
  "codex订阅",
  "chatgptplus",
  "gptplus",
  "chatgpt订阅",
  "会员gpt",
  "百度网盘",
  "百度网盘会员",
  "百度云会员",
  "网盘会员",
  "百度网盘和夸克会员",
  "夸克会员",
  "夸克网盘",
  "夸克网盘会员",
  "网易云会员",
  "网易云音乐会员",
  "绿钻",
  "微信阅读会员",
  "微信读书会员",
  "uc会员",
  "汽水音乐会员",
  "一个月vpn",
};
const _gamePurchases = {
  "英雄联盟皮肤",
  "lol皮肤",
  "游戏皮肤",
  "lol抽奖",
  "怪物猎人物语3",
  "怪物猎人物语３",
};
const _sourceCategories = {
  "娱乐",
  "学习",
  "办公",
  "购物",
  "日用",
  "通讯",
  "其它",
  "其他",
  "数码",
};
const _tag = "ledger.categoryReview.v1";

/// Conservative corrections for unambiguous labels in the imported ledger.
String? reviewedExpenseCategory(String category, String title) {
  if (!_sourceCategories.contains(category)) return null;
  final key = title.trim().toLowerCase().replaceAll(RegExp(r"\s+"), "");
  if (_subscriptions.contains(key)) return "订阅";
  if (category == "娱乐" && _gamePurchases.contains(key)) return "游戏";
  if (category != "通讯" && {"话费", "电话费"}.contains(key)) return "通讯";
  return null;
}

/// Changes category links in one transaction. A marker preserves subsequent
/// manual edits if the user runs the review again after importing more rows.
int organizeLedgerCategories() {
  final db = ObjectBox(),
      categories = db.box<Category>(),
      transactions = db.box<Transaction>();
  return db.store.runInTransaction(TxMode.write, () {
    final byName = {for (final c in categories.getAll()) c.name: c};
    final query = transactions.query(Transaction_.amount.lessThan(0)).build();
    try {
      final changed = <Transaction>[];
      for (final row in query.find()) {
        if (row.isDeleted == true ||
            row.isTransfer ||
            row.extraTags.contains(_tag)) {
          continue;
        }
        final source = row.category.target?.name;
        if (source == null) continue;
        final name = row.title?.trim();
        final title = (name == null || name.isEmpty || name == source)
            ? row.description ?? ""
            : name;
        final dest = reviewedExpenseCategory(source, title);
        if (dest == null) continue;
        final target = byName.putIfAbsent(dest, () {
          final c = Category(name: dest, iconCode: "");
          categories.put(c);
          return c;
        });
        row.setCategory(target);
        row.extraTags = [...row.extraTags, _tag];
        changed.add(row);
      }
      if (changed.isNotEmpty) transactions.putMany(changed);
      return changed.length;
    } finally {
      query.close();
    }
  });
}
