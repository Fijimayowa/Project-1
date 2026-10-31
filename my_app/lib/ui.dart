import 'package:flutter/material.dart';

import 'models.dart';

// ---------- Background photos ----------
const kKitchenBg = 'assets/images/bg_kitchen.jpg';
const kBurgersBg = 'assets/images/bg_burgers.jpg';
const kSushiBg = 'assets/images/bg_sushi.jpg';

/// Picks a background photo that fits the restaurant.
String backgroundFor(Restaurant r) {
  final n = r.name.toLowerCase();
  if (n.contains('sushi') || r.cuisine == 'Japanese') return kSushiBg;
  if (n.contains('burger') || r.cuisine == 'American') return kBurgersBg;
  return kKitchenBg;
}

IconData cuisineIcon(String cuisine) => switch (cuisine) {
      'All' => Icons.restaurant_menu,
      'American' => Icons.fastfood,
      'Japanese' => Icons.ramen_dining,
      'Mexican' => Icons.lunch_dining,
      'Italian' => Icons.local_pizza,
      'Indian' => Icons.dinner_dining,
      'Chinese' => Icons.rice_bowl,
      _ => Icons.restaurant,
    };

// =====================================================================
// StatelessWidget: full-screen photo with a dark layer on top.
// Put a transparent Scaffold inside; text outside cards should be white.
// =====================================================================
class PhotoBackground extends StatelessWidget {
  final String asset;
  final Widget child;

  const PhotoBackground({super.key, required this.asset, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: Colors.black),
        ),
        const ColoredBox(color: Colors.black54),
        child,
      ],
    );
  }
}

// =====================================================================
// StatelessWidget: restaurant logo on a white tile (or its first letter)
// =====================================================================
class RestaurantLogo extends StatelessWidget {
  final Restaurant restaurant;
  final double? width;
  final double? height;
  final double radius;

  const RestaurantLogo({
    super.key,
    required this.restaurant,
    this.width,
    this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final logo = restaurant.logoAsset;
    final initial =
        restaurant.name.isEmpty ? '?' : restaurant.name[0].toUpperCase();
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: logo == null
          ? Center(
              child: FittedBox(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            )
          : Image.asset(logo, fit: BoxFit.contain),
    );
  }
}

// =====================================================================
// StatelessWidget: restaurant card (big logo on top, like DoorDash)
// =====================================================================
class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RestaurantLogo(
              restaurant: restaurant,
              width: double.infinity,
              height: 150,
              radius: 0,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${restaurant.cuisine} • ${money(restaurant.deliveryFee)} delivery',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// StatelessWidget: restaurant tile for the grid view
// =====================================================================
class RestaurantGridTile extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const RestaurantGridTile({
    super.key,
    required this.restaurant,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RestaurantLogo(
                restaurant: restaurant,
                width: double.infinity,
                height: double.infinity,
                radius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${restaurant.cuisine} • ${money(restaurant.deliveryFee)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// StatelessWidget: card in the "Your past orders" carousel
// =====================================================================
class PastOrderCard extends StatelessWidget {
  final Order order;
  final Restaurant restaurant;
  final VoidCallback onTap;

  const PastOrderCard({
    super.key,
    required this.order,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 250,
      child: Card(
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RestaurantLogo(
                restaurant: restaurant,
                width: double.infinity,
                height: 110,
                radius: 0,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      order.items,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                    Text(
                      '${money(order.total)} • ${order.status.label}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// StatelessWidget: round category icon + label (like DoorDash's row)
// =====================================================================
class CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// StatelessWidget: order tile (shows the restaurant logo when given)
// =====================================================================
class OrderTile extends StatelessWidget {
  final Order order;
  final Restaurant? restaurant; // shown on the History screen
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const OrderTile({
    super.key,
    required this.order,
    required this.onTap,
    this.restaurant,
    this.selected = false,
    this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final line2 = '${formatDate(order.date)} • ${order.status.label}';
    final r = restaurant;
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: r == null
            ? null
            : RestaurantLogo(restaurant: r, width: 48, height: 48),
        title: Text(r == null ? order.items : r.name),
        subtitle: Text(r == null ? line2 : '${order.items}\n$line2'),
        isThreeLine: r != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(money(order.total),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete order',
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// =====================================================================
// StatelessWidget: red background shown while swiping to delete
// =====================================================================
class DeleteBackground extends StatelessWidget {
  const DeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}
