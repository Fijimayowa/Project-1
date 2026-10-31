import 'package:flutter/material.dart'; // Import Flutter material UI library

// Import local project files
import 'db.dart';
import 'detail_screen.dart';
import 'dialogs.dart';
import 'form_screen.dart';
import 'models.dart';
import 'settings_store.dart';
import 'ui.dart';


// Main home screen widget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState(); // Create state for HomeScreen
}

// State class for HomeScreen
class _HomeScreenState extends State<HomeScreen> {
  List<Restaurant> _all = []; // All restaurants
  List<Order> _orders = []; // All orders
  bool _loading = true; // Loading state
  bool _grid = false; // Grid view toggle
  bool _lowFees = false; // Filter for low delivery fees
  String _cuisine = 'All'; // Selected cuisine filter
  String _query = ''; // Search query
  final _searchCtrl = TextEditingController(); // Controller for search input

  @override
  void initState() {
    super.initState();
    // Listen for database changes and load data
    AppDb.instance.version.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    // Clean up listeners and controllers
    AppDb.instance.version.removeListener(_load);
    _searchCtrl.dispose();
    super.dispose();
  }

  // Load restaurants and orders from the database
  Future<void> _load() async {
    final restaurants = await AppDb.instance.restaurants();
    final orders = await AppDb.instance.orders();
    if (!mounted) return;
    setState(() {
      _all = restaurants;
      _orders = orders;
      _loading = false;
      // Reset cuisine filter if not available
      if (_cuisine != 'All' && !restaurants.any((r) => r.cuisine == _cuisine)) {
        _cuisine = 'All';
      }
    });
  }

  // Get filtered list of restaurants to show
  List<Restaurant> get _shown {
    final q = _query.trim().toLowerCase();
    return _all.where((r) {
      if (_cuisine != 'All' && r.cuisine != _cuisine) return false;
      if (_lowFees && r.deliveryFee > 3.0) return false;
      if (q.isNotEmpty &&
          !r.name.toLowerCase().contains(q) &&
          !r.cuisine.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toast(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editAddress() async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _AddressDialog(initial: SettingsStore.instance.address),
    );
    if (saved == null) return;
    await SettingsStore.instance.saveAddress(saved);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openForm({Restaurant? existing}) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FormScreen.restaurant(existing: existing),
      ),
    );
    _toast(message);
  }

  Future<void> _openDetail(Restaurant r, {int? orderId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(restaurant: r, selectedOrderId: orderId),
      ),
    );
  }

  /// Called after the user already confirmed. The row is removed from the
  /// screen first (a swiped Dismissible must leave the tree right away),
  /// then from SQLite.
  Future<void> _deleteConfirmed(Restaurant r) async {
    setState(() => _all = _all.where((x) => x.id != r.id).toList());
    await AppDb.instance.deleteRestaurant(r.id!);
    _toast('Deleted ${r.name}');
  }

  Future<void> _delete(Restaurant r) async {
    final ok = await confirmDeleteRestaurant(context, r);
    if (!ok || !mounted) return;
    await _deleteConfirmed(r);
  }

  /// Long press menu (works in both list and grid).
  Future<void> _showActions(Restaurant r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                r.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(r.cuisine),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _openForm(existing: r);
    if (!mounted) return;
    if (action == 'delete') await _delete(r);
  }

  // ---------- Header sections ----------
  Widget _header(BuildContext context) {
    final address = SettingsStore.instance.address;
    final cuisines = [
      'All',
      ...{for (final r in _all) r.cuisine},
    ];
    final byId = {for (final r in _all) r.id!: r};
    final recent = _orders
        .where((o) => byId.containsKey(o.restaurantId))
        .take(6)
        .toList();
    const sectionStyle = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery address + list/grid toggle
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _editAddress,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            address.isEmpty ? 'Add delivery address' : address,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _grid ? Icons.view_list : Icons.grid_view,
                    color: Colors.white,
                  ),
                  tooltip: _grid ? 'Show as list' : 'Show as grid',
                  onPressed: () => setState(() => _grid = !_grid),
                ),
              ],
            ),
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.black87),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search FasterFood',
              hintStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black87),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Category row (cuisine filter)
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              for (final c in cuisines)
                CategoryItem(
                  icon: cuisineIcon(c),
                  label: c,
                  selected: _cuisine == c,
                  onTap: () => setState(() => _cuisine = c),
                ),
            ],
          ),
        ),

        // Filter pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                avatar: const Icon(Icons.local_offer, size: 18),
                label: const Text('Low delivery fee'),
                selected: _lowFees,
                onSelected: (v) => setState(() => _lowFees = v),
              ),
            ],
          ),
        ),

        // Green banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFBDE55B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FasterFood',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your favorites, a few taps away.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pick a restaurant and track your order.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.delivery_dining, size: 60, color: Color(0xFF1F5C5C)),
            ],
          ),
        ),

        // Past orders carousel
        if (recent.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Your past orders', style: sectionStyle),
          ),
          SizedBox(
            height: 215,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              children: [
                for (final o in recent)
                  PastOrderCard(
                    order: o,
                    restaurant: byId[o.restaurantId]!,
                    onTap: () =>
                        _openDetail(byId[o.restaurantId]!, orderId: o.id),
                  ),
              ],
            ),
          ),
        ],

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Restaurants', style: sectionStyle),
        ),
      ],
    );
  }

  Widget _restaurantList(List<Restaurant> shown) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 96),
      sliver: SliverList.builder(
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final r = shown[i];
          return Dismissible(
            key: ValueKey('restaurant-${r.id}'),
            direction: DismissDirection.endToStart, // swipe left to delete
            background: const DeleteBackground(),
            confirmDismiss: (_) => confirmDeleteRestaurant(context, r),
            onDismissed: (_) => _deleteConfirmed(r),
            child: RestaurantCard(
              restaurant: r,
              onTap: () => _openDetail(r),
              onEdit: () => _openForm(existing: r),
              onDelete: () => _delete(r),
              onLongPress: () => _showActions(r),
            ),
          );
        },
      ),
    );
  }

  Widget _restaurantGrid(List<Restaurant> shown) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final r = shown[i];
          return RestaurantGridTile(
            restaurant: r,
            onTap: () => _openDetail(r),
            onLongPress: () => _showActions(r),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;

    return PhotoBackground(
      asset: kKitchenBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(context)),
                  if (shown.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No restaurants found.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  else if (_grid)
                    _restaurantGrid(shown)
                  else
                    _restaurantList(shown),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add restaurant'),
        ),
      ),
    );
  }
}

/// Small dialog that owns (and disposes) its own text controller.
class _AddressDialog extends StatefulWidget {
  final String initial;
  const _AddressDialog({required this.initial});

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delivery address'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Street, city'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
