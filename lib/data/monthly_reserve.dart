import "dart:convert";
import "dart:math" as math;

import "package:flow/entity/transaction.dart";

/// Monthly savings target and planned spending per category, in fen.
class MonthlyReserve {
  const MonthlyReserve({this.savings = 0, this.limits = const {}});
  final int savings;
  final Map<String, int> limits;

  factory MonthlyReserve.decode(String? raw) {
    if (raw == null) return const MonthlyReserve();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return MonthlyReserve(
      savings: data["savings"] as int,
      limits: Map<String, int>.from(data["limits"] as Map),
    );
  }

  String encode() => jsonEncode({"savings": savings, "limits": limits});

  MonthlyReserve change(String? category, int cents) {
    if (category == null) return MonthlyReserve(savings: cents, limits: limits);
    final next = {...limits};
    if (cents == 0) {
      next.remove(category);
    } else {
      next[category] = cents;
    }
    return MonthlyReserve(savings: savings, limits: next);
  }

  /// Spending already posted in a category uses up that category's reserve.
  Map<String, int> remaining(Iterable<Transaction> settledMonthlyRows) {
    final left = {...limits};
    for (final row in settledMonthlyRows) {
      final id = row.categoryUuid;
      if (row.amount < 0 && id != null && left.containsKey(id)) {
        left[id] = math.max(0, left[id]! + (row.amount * 100).round());
      }
    }
    return left;
  }
}
