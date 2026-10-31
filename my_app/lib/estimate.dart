import 'models.dart';

/// "Order Cost Estimate": a small, local, rule-based helper.
/// Method: average of the last 3 order totals from one restaurant.
/// Baseline: the total of the most recent order.
class Estimate {
  final double amount;
  final int basedOn;
  final double baseline;

  const Estimate(this.amount, this.basedOn, this.baseline);

  static const method = 'Rule-based: average of the last 3 order totals.';

  String get message =>
      'Your next order will probably cost about ${money(amount)}.';

  String get explanation {
    final word = basedOn == 1 ? 'order' : 'orders';
    return 'Based on your last $basedOn $word from this restaurant.';
  }
}

/// Returns null when there are no past orders.
Estimate? estimateNextOrder(List<Order> orders) {
  if (orders.isEmpty) return null;
  final sorted = [...orders]..sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(3).toList();
  final sum = recent.fold<double>(0, (s, o) => s + o.total);
  return Estimate(sum / recent.length, recent.length, sorted.first.total);
}
