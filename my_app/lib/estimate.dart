// Import the Order model and shared helpers such as money().
import 'models.dart';

// Holds the estimated cost and information about how it was calculated.
class Estimate {
  // The predicted cost of the next order.
  final double amount;
  // How many past orders were used for the estimate.
  final int basedOn;
  // The total of the newest order, used as a comparison baseline.
  final double baseline;

  // Create an estimate from its amount, order count, and baseline.
  const Estimate(this.amount, this.basedOn, this.baseline);

  // A short description of the estimation approach.
  static const method = 'Rule-based: average of the last 3 order totals.';

  // Format the estimate as a friendly sentence with a money value.
  String get message =>
      'Your next order will probably cost about ${money(amount)}.';

  // Describe how many orders were considered.
  String get explanation {
    // Choose singular or plural based on the number of orders.
    final word = basedOn == 1 ? 'order' : 'orders';
    // Return the completed explanation sentence.
    return 'Based on your last $basedOn $word from this restaurant.';
  }
}

// Calculate an estimate from the given past orders, or return null if none exist.
Estimate? estimateNextOrder(List<Order> orders) {
  // Stop when there are no orders to use.
  if (orders.isEmpty) return null;
  // Make a copy and sort it from newest order to oldest order.
  final sorted = [...orders]..sort((a, b) => b.date.compareTo(a.date));
  // Select up to the three newest orders.
  final recent = sorted.take(3).toList();
  // Add the totals of the selected orders.
  final sum = recent.fold<double>(0, (s, o) => s + o.total);
  // Return the average total, how many orders were used, and newest total.
  return Estimate(sum / recent.length, recent.length, sorted.first.total);
}
