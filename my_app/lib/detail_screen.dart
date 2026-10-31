import 'package:flutter/material.dart';

import 'db.dart';
import 'dialogs.dart';
import 'form_screen.dart';
import 'models.dart';
import 'ui.dart';
import 'widgets.dart';

// Shows a restaurant's details and lets the user manage its orders.
/// Restaurant detail: estimate, its orders, and the selected order's
/// status tracker and tip slider.
class DetailScreen extends StatefulWidget {
  final Restaurant restaurant;
  final int? selectedOrderId;

  const DetailScreen({
    super.key,
    required this.restaurant,
    this.selectedOrderId,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Current restaurant, its orders, selected order, and loading state.
  late Restaurant _restaurant;
  List<Order> _orders = [];
  int? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Start listening for database changes and load the restaurant's data.
    _restaurant = widget.restaurant;
    _selectedId = widget.selectedOrderId;
    AppDb.instance.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    // Stop listening when this screen is closed.
    AppDb.instance.version.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    // Refresh the restaurant and its orders from the database.
    final r = await AppDb.instance.restaurant(_restaurant.id!);
    if (r == null) return; // restaurant was deleted
    final orders = await AppDb.instance.orders(restaurantId: r.id);
    if (!mounted) return;
    setState(() {
      _restaurant = r;
      _orders = orders;
      _loading = false;
    });
  }

  /// The selected order, or the newest one if nothing is selected.
  Order? get _selected {
    // Return the chosen order, or the first order if none is chosen.
    if (_orders.isEmpty) return null;
    return _orders.firstWhere(
      (o) => o.id == _selectedId,
      orElse: () => _orders.first,
    );
  }

  void _toast(String? message) {
    // Display a brief message after an action.
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Update the screen right away, then save to SQLite.
  Future<void> _update(Order base, {int? tip, OrderStatus? status}) async {
    // Update the screen immediately, then save the order to the database.
    final current = _orders.firstWhere(
      (o) => o.id == base.id,
      orElse: () => base,
    );
    final updated = current.copyWith(tipPercent: tip, status: status);
    setState(() {
      _orders = [for (final o in _orders) o.id == updated.id ? updated : o];
    });
    await AppDb.instance.saveOrder(updated);
  }

  Future<void> _editRestaurant() async {
    // Open the restaurant edit form and show its result.
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FormScreen.restaurant(existing: _restaurant),
      ),
    );
    _toast(message);
  }

  Future<void> _deleteRestaurant() async {
    // Confirm deletion, remove the restaurant, and return to the previous screen.
    final ok = await confirmDeleteRestaurant(context, _restaurant);
    if (!ok || !mounted) return;
    await AppDb.instance.deleteRestaurant(_restaurant.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _openOrderForm({Order? existing}) async {
    // Open a form to add a new order or edit an existing one.
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormScreen.order(restaurant: _restaurant, existing: existing),
      ),
    );
    _toast(message);
  }

  /// Called after the user already confirmed. Removes the row from the
  /// screen first (a swiped Dismissible must leave the tree), then SQLite.
  Future<void> _deleteOrderConfirmed(Order o) async {
    // Remove the order from the page first, then delete it from storage.
    setState(() {
      _orders = _orders.where((x) => x.id != o.id).toList();
      if (_selectedId == o.id) _selectedId = null;
    });
    await AppDb.instance.deleteOrder(o.id!);
    _toast('Order deleted');
  }

  Future<void> _deleteOrder(Order o) async {
    // Ask for confirmation before deleting an order.
    final ok = await confirmDeleteOrder(context, o);
    if (!ok || !mounted) return;
    await _deleteOrderConfirmed(o);
  }

  @override
  Widget build(BuildContext context) {
    // Display restaurant details, its orders, and controls for the selected order.
    final sel = _selected;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final lightTitle = titleStyle?.copyWith(color: Colors.white);

    return PhotoBackground(
      asset: backgroundFor(_restaurant),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(_restaurant.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit restaurant',
              onPressed: _editRestaurant,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete restaurant',
              onPressed: _deleteRestaurant,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    '${_restaurant.cuisine} • Delivery ${money(_restaurant.deliveryFee)}',
                    style: lightTitle,
                  ),
                  const SizedBox(height: 8),
                  EstimateCard(orders: _orders),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _openOrderForm(),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Place new order'),
                  ),
                  const SizedBox(height: 16),
                  Text('Orders', style: lightTitle),
                  if (_orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No orders yet. Place one above.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  for (final o in _orders)
                    Dismissible(
                      key: ValueKey('order-${o.id}'),
                      direction: DismissDirection.endToStart,
                      background: const DeleteBackground(),
                      confirmDismiss: (_) => confirmDeleteOrder(context, o),
                      onDismissed: (_) => _deleteOrderConfirmed(o),
                      child: OrderTile(
                        order: o,
                        selected: o.id == sel?.id,
                        onTap: () => setState(() => _selectedId = o.id),
                        onLongPress: () => _openOrderForm(existing: o),
                      ),
                    ),
                  if (sel != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selected order', style: titleStyle),
                            Text(sel.items),
                            const SizedBox(height: 12),
                            StatusTracker(
                              key: ValueKey('status-${sel.id}'),
                              status: sel.status,
                              onChanged: (s) => _update(sel, status: s),
                            ),
                            const Divider(height: 32),
                            TipSlider(
                              key: ValueKey('tip-${sel.id}'),
                              initialPercent: sel.tipPercent,
                              subtotal: sel.subtotal,
                              onChangeEnd: (p) => _update(sel, tip: p),
                            ),
                            const Divider(height: 32),
                            Text('Subtotal: ${money(sel.subtotal)}'),
                            Text('Delivery: ${money(sel.deliveryFee)}'),
                            Text('Tip: ${money(sel.tip)}'),
                            Text(
                              'Total: ${money(sel.total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _openOrderForm(existing: sel),
                                    child: const Text('Edit order'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _deleteOrder(sel),
                                    child: const Text('Delete order'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
