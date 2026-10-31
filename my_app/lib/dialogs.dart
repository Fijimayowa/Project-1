import 'package:flutter/material.dart'; // Flutter UI library for dialogs, buttons, and BuildContext.

import 'db.dart'; // Import database helper methods like orderCountFor.
import 'models.dart'; // Import app model classes like Restaurant and Order.

Future<bool> confirmDeleteRestaurant(BuildContext context, Restaurant r) async {
  // Asks the database how many orders belong to this restaurant before deleting it.
  final count = await AppDb.instance.orderCountFor(r.id!);
  // If the widget is no longer mounted, stop and return false to avoid using a dead context.
  if (!context.mounted) return false;
  // The message shown in the confirmation dialog depends on whether orders exist.
  final String message;
  if (count == 0) {
    // No orders are tied to the restaurant, so the dialog says it will just be removed.
    message = 'This restaurant will be removed.';
  } else {
    // If there are orders, show a warning that they will also be deleted.
    final word = count == 1 ? 'order' : 'orders';
    message = 'This will also delete its $count $word. This cannot be undone.';
  }
  // Open the shared confirmation dialog with the restaurant name and computed warning message.
  return _confirm(context, 'Delete ${r.name}?', message);
}

Future<bool> confirmDeleteOrder(BuildContext context, Order o) =>
    // Show a confirmation dialog asking whether to delete the selected order.
    _confirm(context, 'Delete this order?', '"${o.items}" will be removed.');

Future<bool> _confirm(
  // The current widget tree context used to display the dialog.
  BuildContext context,
  // The title of the alert dialog.
  String title,
  // The body text explaining what will be deleted.
  String message,
) async {
  // Display an alert dialog and wait for the user's choice.
  final ok = await showDialog<bool>(
    // The dialog is attached to the current screen context.
    context: context,
    // Build the actual alert dialog content.
    builder: (ctx) => AlertDialog(
      // Header text for the dialog.
      title: Text(title),
      // Message explaining the action.
      content: Text(message),
      // The buttons shown at the bottom of the dialog.
      actions: [
        // Cancel button closes the dialog and returns false.
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        // Delete button closes the dialog and returns true.
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  // If the user dismissed the dialog without a result, treat it as false.
  return ok ?? false;
}
