enum OrderStatus { placed, preparing, onTheWay, delivered }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Placed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
      };
}

class Restaurant {
  final int? id;
  final String name;
  final String cuisine;
  final double deliveryFee;

  const Restaurant({
    this.id,
    required this.name,
    required this.cuisine,
    required this.deliveryFee,
  });

  /// Logo image for known restaurants, or null (the UI then shows the first letter).
  String? get logoAsset {
    final n = name.toLowerCase();
    if (n.contains('burger king')) return 'assets/images/burger_king.png';
    if (n.contains('taco bell')) return 'assets/images/taco_bell.jpg';
    if (n.contains('sushi')) return 'assets/images/sushi.jpg';
    return null;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'cuisine': cuisine,
        'delivery_fee': deliveryFee,
      };

  factory Restaurant.fromMap(Map<String, Object?> m) => Restaurant(
        id: m['id'] as int,
        name: m['name'] as String,
        cuisine: m['cuisine'] as String,
        deliveryFee: (m['delivery_fee'] as num).toDouble(),
      );
}

class Order {
  final int? id;
  final int restaurantId;
  final String items;
  final double subtotal;
  final double deliveryFee; // copied from the restaurant when the order is made
  final int tipPercent; // 0-30
  final OrderStatus status;
  final DateTime date;

  const Order({
    this.id,
    required this.restaurantId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.tipPercent,
    this.status = OrderStatus.placed,
    required this.date,
  });

  double get tip => subtotal * tipPercent / 100;
  double get total => subtotal + deliveryFee + tip;

  Order copyWith({int? tipPercent, OrderStatus? status}) => Order(
        id: id,
        restaurantId: restaurantId,
        items: items,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        tipPercent: tipPercent ?? this.tipPercent,
        status: status ?? this.status,
        date: date,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'restaurant_id': restaurantId,
        'items': items,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'tip_percent': tipPercent,
        'status': status.index,
        'date': date.millisecondsSinceEpoch,
      };

  factory Order.fromMap(Map<String, Object?> m) => Order(
        id: m['id'] as int,
        restaurantId: m['restaurant_id'] as int,
        items: m['items'] as String,
        subtotal: (m['subtotal'] as num).toDouble(),
        deliveryFee: (m['delivery_fee'] as num).toDouble(),
        tipPercent: m['tip_percent'] as int,
        status: OrderStatus.values[m['status'] as int],
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

String money(double v) => '\$${v.toStringAsFixed(2)}';

String formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
