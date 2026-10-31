import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/estimate.dart'; // change "my_app" if your project name differs
import 'package:my_app/models.dart';

/// Order with no delivery fee and no tip, so total == subtotal.
Order order(double total, int daysAgo) => Order(
      restaurantId: 1,
      items: 'Test item',
      subtotal: total,
      deliveryFee: 0,
      tipPercent: 0,
      date: DateTime(2026, 10, 20).subtract(Duration(days: daysAgo)),
    );

void main() {
  test('1. no past orders gives no estimate', () {
    expect(estimateNextOrder([]), isNull);
  });

  test('2. one past order uses that order', () {
    final e = estimateNextOrder([order(15, 1)])!;
    expect(e.amount, 15);
    expect(e.basedOn, 1);
  });

  test('3. three orders are averaged', () {
    final e = estimateNextOrder([order(10, 1), order(20, 2), order(30, 3)])!;
    expect(e.amount, 20);
    expect(e.basedOn, 3);
  });

  test('4. only the 3 most recent orders count', () {
    final e = estimateNextOrder(
        [order(10, 1), order(20, 2), order(30, 3), order(100, 10)])!;
    expect(e.amount, 20); // the $100 order is too old
    expect(e.basedOn, 3);
  });

  test('5. baseline is the most recent order, even if the list is unsorted', () {
    final e = estimateNextOrder([order(30, 3), order(10, 1), order(20, 2)])!;
    expect(e.baseline, 10);
  });
}
