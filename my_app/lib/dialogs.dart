import 'package:flutter/material.dart';

import 'db.dart';
import 'models.dart';

/// Warns that deleting a restaurant also deletes its orders.
Future<bool> confirmDeleteRestaurant(BuildContext context, Restaurant r) async {
  final count = await AppDb.instance.orderCountFor(r.id!);
  if (!context.mounted) return false;
  final String message;
  if (count == 0) {
    message = 'This restaurant will be removed.';
  } else {
    final word = count == 1 ? 'order' : 'orders';
    message = 'This will also delete its $count $word. This cannot be undone.';
  }
  return _confirm(context, 'Delete ${r.name}?', message);
}

Future<bool> confirmDeleteOrder(BuildContext context, Order o) =>
    _confirm(context, 'Delete this order?', '"${o.items}" will be removed.');

Future<bool> _confirm(
    BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
