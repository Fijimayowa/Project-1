// Provides Flutter widgets and UI types.
import 'package:flutter/material.dart';

// Provides access to the app's local database.
import 'db.dart';
// Provides the screen used to view an order.
import 'detail_screen.dart';
// Provides the order deletion confirmation dialog.
import 'dialogs.dart';
// Provides the order, restaurant, and status data types.
import 'models.dart';
// Provides shared UI widgets and helpers.
import 'ui.dart';

// Displays the user's past orders.
class HistoryScreen extends StatefulWidget {
  // Creates the history screen.
  const HistoryScreen({super.key});

  // Creates the state that holds and updates this screen's data.
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

// Stores the data and behavior for the history screen.
class _HistoryScreenState extends State<HistoryScreen> {
  // Holds the orders loaded from the database.
  List<Order> _orders = [];
  // Maps restaurant IDs to their restaurant details.
  Map<int, Restaurant> _restaurants = {};
  // Holds the selected status filter, or null to show every order.
  OrderStatus? _status;
  // Tracks whether the first database load is still running.
  bool _loading = true;

  // Sets up the database listener and starts loading data.
  @override
  void initState() {
    // Runs the normal setup for a StatefulWidget.
    super.initState();
    // Reloads the screen when the database version changes.
    AppDb.instance.version.addListener(_load);
    // Loads the initial orders and restaurant data.
    _load();
  }

  // Removes the database listener when this screen is disposed.
  @override
  void dispose() {
    // Stops listening for database version changes.
    AppDb.instance.version.removeListener(_load);
    // Runs the normal cleanup for a StatefulWidget.
    super.dispose();
  }

  // Loads orders and restaurants from the database.
  Future<void> _load() async {
    // Gets all saved orders.
    final orders = await AppDb.instance.orders();
    // Gets all saved restaurants.
    final restaurants = await AppDb.instance.restaurants();
    // Stops if this screen no longer exists.
    if (!mounted) return;
    // Saves the loaded data and ends the loading state.
    setState(() {
      // Replaces the current order list.
      _orders = orders;
      // Builds a lookup map using each restaurant's ID.
      _restaurants = {for (final r in restaurants) r.id!: r};
      // Indicates that loading is complete.
      _loading = false;
    });
  }

  // Opens the details for the given order.
  Future<void> _open(Order o) async {
    // Looks up the restaurant associated with the order.
    final r = _restaurants[o.restaurantId];
    // Does nothing if that restaurant is unavailable.
    if (r == null) return;
    // Pushes the order detail screen onto the navigation stack.
    await Navigator.push(
      context,
      MaterialPageRoute(
        // Passes the restaurant and order ID to the detail screen.
        builder: (_) => DetailScreen(restaurant: r, selectedOrderId: o.id),
      ),
    );
  }

  // Removes an order after deletion has been confirmed.
  Future<void> _deleteConfirmed(Order o) async {
    // Removes the order from the visible list immediately.
    setState(() => _orders = _orders.where((x) => x.id != o.id).toList());
    // Deletes the order from the database.
    await AppDb.instance.deleteOrder(o.id!);
    // Stops if the screen was removed while deletion was running.
    if (!mounted) return;
    // Replaces any current message and shows confirmation.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Order deleted')));
  }

  // Asks the user before deleting an order.
  Future<void> _delete(Order o) async {
    // Shows the confirmation dialog.
    final ok = await confirmDeleteOrder(context, o);
    // Stops if deletion was declined or the screen was removed.
    if (!ok || !mounted) return;
    // Performs the deletion after confirmation.
    await _deleteConfirmed(o);
  }

  // Shows actions available for an order.
  Future<void> _showActions(Order o) async {
    // Opens a bottom sheet and stores the selected action.
    final action = await showModalBottomSheet<String>(
      context: context,
      // Builds the contents of the bottom sheet.
      builder: (ctx) => SafeArea(
        // Sizes the column to fit its contents.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Adds an option to open the order.
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('View order'),
              // Closes the sheet and returns the view action.
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            // Adds an option to delete the order.
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete order'),
              // Closes the sheet and returns the delete action.
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    // Stops if the screen was removed while the sheet was open.
    if (!mounted) return;
    // Opens the order if the user chose to view it.
    if (action == 'view') await _open(o);
    // Checks again in case opening the order removed this screen.
    if (!mounted) return;
    // Starts the delete confirmation if the user chose deletion.
    if (action == 'delete') await _delete(o);
  }

  // Builds the visible screen and its order list.
  @override
  Widget build(BuildContext context) {
    // Shows all orders or only those matching the selected status.
    final shown = _status == null
        ? _orders
        : _orders.where((o) => o.status == _status).toList();
    // Adds up the totals for the orders currently shown.
    final totalSpent = shown.fold<double>(0, (s, o) => s + o.total);

    // Places the page content over the burger photo background.
    return PhotoBackground(
      // Selects the background image asset.
      asset: kBurgersBg,
      // Builds the main page scaffold.
      child: Scaffold(
        // Lets the background show through the scaffold.
        backgroundColor: Colors.transparent,
        // Builds the top app bar.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          // Sets the page title.
          title: const Text('History'),
        ),
        // Shows a spinner while loading, otherwise shows the page content.
        body: _loading
            // Displays a centered white loading indicator.
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            // Shows spending stats, filters, and orders after loading.
            : Column(
                children: [
                  // Displays totals for the currently filtered orders.
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Shows the total amount spent.
                          _stat(context, 'Total spent', money(totalSpent)),
                          // Shows how many orders are displayed.
                          _stat(context, 'Orders', '${shown.length}'),
                        ],
                      ),
                    ),
                  ),
                  // Lets the user scroll horizontally through status filters.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Adds a filter that displays all orders.
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: _status == null,
                            // Clears the status filter when selected.
                            onSelected: (_) => setState(() => _status = null),
                          ),
                        ),
                        // Adds one filter chip for every order status.
                        for (final s in OrderStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s.label),
                              selected: _status == s,
                              // Filters the list to the selected status.
                              onSelected: (_) => setState(() => _status = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Gives the order list the remaining screen space.
                  Expanded(
                    child: shown.isEmpty
                        // Shows a message when the filter has no results.
                        ? const Center(
                            child: Text(
                              'No orders to show.',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        // Builds a scrolling list of the matching orders.
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            // Sets the number of rows to display.
                            itemCount: shown.length,
                            // Builds each order row on demand.
                            itemBuilder: (context, i) {
                              // Gets the order for this row.
                              final o = shown[i];
                              // Allows this row to be swiped away to delete.
                              return Dismissible(
                                // Gives this order row a stable unique key.
                                key: ValueKey('order-${o.id}'),
                                // Allows swiping only from right to left.
                                direction: DismissDirection.endToStart,
                                // Shows the delete background while swiping.
                                background: const DeleteBackground(),
                                // Requests confirmation before completing a swipe deletion.
                                confirmDismiss: (_) =>
                                    confirmDeleteOrder(context, o),
                                // Deletes the order after a confirmed swipe.
                                onDismissed: (_) => _deleteConfirmed(o),
                                // Displays the order and connects its actions.
                                child: OrderTile(
                                  order: o,
                                  // Provides restaurant details when available.
                                  restaurant: _restaurants[o.restaurantId],
                                  // Opens the order when tapped.
                                  onTap: () => _open(o),
                                  // Shows the action sheet when pressed and held.
                                  onLongPress: () => _showActions(o),
                                  // Starts the delete confirmation when requested.
                                  onDelete: () => _delete(o),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // Builds a small label and value used in the stats card.
  Widget _stat(BuildContext context, String label, String value) {
    // Stacks the statistic value above its label.
    return Column(
      children: [
        // Displays the value using the theme's headline style.
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        // Displays the statistic's description.
        Text(label),
      ],
    );
  }
}
