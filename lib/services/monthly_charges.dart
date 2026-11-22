import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/recurring_transaction.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/objectbox/objectbox.g.dart";
import "package:flow/services/transactions.dart";
import "package:recurrence/recurrence.dart";
import "package:uuid/uuid.dart";

/// Month-start ledger entries. The template and its posting cursor share the
/// same database transaction as each batch, including across backup restores.
class MonthlyCharges {
  static const tag = "ledger.monthlyCharge";
  static bool owns(RecurringTransaction rule) =>
      rule.jsonTransactionTemplate.contains(tag) &&
      rule.template.extraTags.contains(tag);
  static List<RecurringTransaction> active() => ObjectBox()
      .box<RecurringTransaction>()
      .getAll()
      .where((r) => !r.disabled && owns(r))
      .toList();

  static RecurringTransaction create(
    Account account,
    Category category,
    int cents,
    DateTime start, {
    DateTime? now,
  }) {
    if (cents <= 0 || account.archived || account.currency != "CNY") {
      throw StateError("请检查金额和扣款账户");
    }
    final first = DateTime(start.year, start.month);
    final schedule = Recurrence.fromIndefinitely(
      start: first,
      rules: [MonthlyRecurrenceRule(day: 1)],
    );
    final template =
        Transaction(
            uuid: const Uuid().v4(),
            amount: -cents / 100,
            currency: account.currency,
            title: category.name,
            transactionDate: first,
            extraTags: [tag],
          )
          ..setCategory(category)
          ..setAccount(account);
    final rule = RecurringTransaction(
      rules: schedule.rules.map((r) => r.serialize()).toList(),
      range: schedule.range.encodeShort(),
      jsonTransactionTemplate: "",
    )..template = template;
    return ObjectBox().store.runInTransaction(TxMode.write, () {
      if (active().any((r) => r.template.categoryUuid == category.uuid)) {
        throw StateError("这个分类已有每月扣款");
      }
      ObjectBox().box<RecurringTransaction>().put(rule);
      postDue(rule.id, now ?? DateTime.now());
      return rule;
    });
  }

  static String entryUuid(String series, DateTime month) => const Uuid().v5(
    Namespace.url.value,
    "ledger/monthly/$series/${month.year}/${month.month}",
  );

  static Transaction? entry(RecurringTransaction rule, DateTime month) =>
      TransactionsService().findByIdentifierSync(
        entryUuid(rule.uuid, month),
        includeDeleted: true,
      );

  static void postDue(int id, DateTime anchor) {
    final db = ObjectBox();
    db.store.runInTransaction(TxMode.write, () {
      final box = db.box<RecurringTransaction>();
      final rule = box.get(id);
      if (rule == null || rule.disabled) return;
      final t = rule.template;
      final last = rule.lastGeneratedTransactionDate?.toLocal();
      var month = last == null
          ? t.transactionDate.toLocal()
          : DateTime(last.year, last.month + 1);
      if (month.isAfter(anchor)) return;
      final aq = db
          .box<Account>()
          .query(Account_.uuid.equals(t.accountUuid!))
          .build();
      final cq = db
          .box<Category>()
          .query(Category_.uuid.equals(t.categoryUuid!))
          .build();
      try {
        final a = aq.findFirst(), c = cq.findFirst();
        if (a == null || c == null || a.archived || a.currency != t.currency) {
          throw StateError("扣款账户或分类不可用");
        }
        while (!month.isAfter(anchor)) {
          if (entry(rule, month) == null) {
            a.createAndSaveTransaction(
              amount: t.amount,
              title: c.name,
              category: c,
              transactionDate: month,
              uuidOverride: entryUuid(rule.uuid, month),
              extraTags: [tag],
            );
          }
          rule.lastGeneratedTransactionDate = month;
          month = DateTime(month.year, month.month + 1);
        }
        box.put(rule);
      } finally {
        aq.close();
        cq.close();
      }
    });
  }

  static void changeAmount(RecurringTransaction rule, int cents) {
    if (cents <= 0) throw ArgumentError.value(cents);
    final box = ObjectBox().box<RecurringTransaction>();
    final current = box.get(rule.id);
    if (current == null || current.disabled) return;
    final template = current.template..amount = -cents / 100;
    current.template = template;
    box.put(current);
  }

  static void stop(RecurringTransaction rule) {
    final box = ObjectBox().box<RecurringTransaction>();
    final current = box.get(rule.id);
    if (current != null) box.put(current..disabled = true);
  }
}
