// Import Flutter's widgets and Material Design components.
import 'package:flutter/material.dart';

// Import the app's database, data models, settings, and reusable widgets.
import 'db.dart';
import 'models.dart';
import 'settings_store.dart';
import 'widgets.dart';

// Show a form for adding or editing a restaurant or an order.
class FormScreen extends StatefulWidget {
  // Hold the restaurant being edited, if there is one.
  final Restaurant? restaurant;
  // Hold the order being edited, if there is one.
  final Order? order;
  // Tell the screen whether this form is for an order.
  final bool isOrder;

  // Create a restaurant form, optionally filled with an existing restaurant.
  const FormScreen.restaurant({super.key, Restaurant? existing})
    : restaurant = existing,
      order = null,
      isOrder = false;

  // Create an order form for the given restaurant, optionally editing an order.
  const FormScreen.order({
    super.key,
    required Restaurant restaurant,
    Order? existing,
  }) : restaurant = restaurant,
       order = existing,
       isOrder = true;

  // Create the state object that manages this screen.
  @override
  State<FormScreen> createState() => _FormScreenState();
}

// Keep form values and build the screen's interactive content.
class _FormScreenState extends State<FormScreen> {
  // List the cuisine choices shown in the dropdown.
  static const _cuisines = [
    'American',
    'Japanese',
    'Mexican',
    'Italian',
    'Indian',
    'Chinese',
    'Other',
  ];

  // Track form validation and manage the text fields.
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();

  // Store the selected cuisine, tip, order date, and save status.
  String? _cuisine;
  int _tip = 15;
  DateTime _date = DateTime.now();
  bool _saving = false;

  // Fill the fields when editing an existing restaurant or order.
  @override
  void initState() {
    // Let Flutter finish setting up the state first.
    super.initState();
    // Get the restaurant and order passed into this screen.
    final r = widget.restaurant;
    final o = widget.order;
    // Load restaurant details when showing a restaurant form.
    if (!widget.isOrder) {
      _nameCtrl.text = r?.name ?? '';
      _feeCtrl.text = r == null ? '' : r.deliveryFee.toStringAsFixed(2);
      _cuisine = r?.cuisine;
    // Otherwise, load order details into the form.
    } else {
      _itemsCtrl.text = o?.items ?? '';
      _subtotalCtrl.text = o == null ? '' : o.subtotal.toStringAsFixed(2);
      _tip = o?.tipPercent ?? 15;
      _date = o?.date ?? DateTime.now();
    }
  }

  // Release text field resources when this screen is removed.
  @override
    // Dispose of each text controller.
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    _itemsCtrl.dispose();
    _subtotalCtrl.dispose();
    // Let the parent state class finish cleanup.
    super.dispose();
  }

  // Read the subtotal as a number, or use zero if it is not valid yet.
  double get _subtotal => double.tryParse(_subtotalCtrl.text.trim()) ?? 0;

  // Get the delivery fee from the order or restaurant, or use zero.
  double get _fee =>
      widget.order?.deliveryFee ?? widget.restaurant?.deliveryFee ?? 0;

  // Open the date picker and save the selected date.
  Future<void> _pickDate() async {
    // Ask the user to choose a date.
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    // Stop if the screen is gone or no date was selected.
    if (!mounted || picked == null) return;
    // Update the displayed date.
    setState(() => _date = picked);
  }

  // Validate and save the restaurant or order.
  Future<void> _save() async {
    // Stop if any field has invalid input.
      // Show that saving is in progress.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Save the appropriate kind of record and prepare a confirmation.
    try {
      final String message;
      // Save an order when this is an order form.
      if (widget.isOrder) {
          // Keep the existing order's details that are not edited here.
        final old = widget.order;
        await AppDb.instance.saveOrder(
          Order(
            id: old?.id,
            restaurantId: widget.restaurant!.id!,
            items: _itemsCtrl.text.trim(),
            subtotal: double.parse(_subtotalCtrl.text.trim()),
            deliveryFee: _fee,
            tipPercent: _tip,
            status: old?.status ?? OrderStatus.placed,
            date: _date,
          ),
        );
        message = old == null ? 'Order placed' : 'Order updated';
        // Save a restaurant when this is a restaurant form.
      } else {
        final old = widget.restaurant;
        await AppDb.instance.saveRestaurant(
          Restaurant(
            id: old?.id,
            name: _nameCtrl.text.trim(),
            cuisine: _cuisine!,
            deliveryFee: double.parse(_feeCtrl.text.trim()),
          ),
        );
        message = old == null ? 'Restaurant added' : 'Restaurant updated';
      }
      // Return the confirmation message to the previous screen.
      if (!mounted) return;
      Navigator.pop(context, message);
      // Show an error message if saving failed.
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  // Build the cancel and save/place-order buttons.
  Widget _buttons() {
      // Cancel without saving.
      // Save the form, or show a spinner while saving.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isOrder ? 'Place order' : 'Save'),
          ),
        ),
      ],
    );
  }

  // Build the fields used to add or edit a restaurant.
  List<Widget> _restaurantFields() {
    return [
      // Enter and validate the restaurant name.
      TextFormField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Restaurant name',
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
      ),
      // Add space between form fields.
      const SizedBox(height: 16),
      // Choose and validate a cuisine.
      DropdownButtonFormField<String>(
        initialValue: _cuisine, // use `value:` on older Flutter versions
        decoration: const InputDecoration(
          labelText: 'Cuisine',
          border: OutlineInputBorder(),
        ),
        items: _cuisines
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() => _cuisine = v),
        validator: (v) => v == null ? 'Pick a cuisine' : null,
      ),
      // Add space before the delivery fee.
      const SizedBox(height: 16),
      // Enter and validate the delivery fee.
      TextFormField(
        controller: _feeCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Delivery fee',
          prefixText: '\$',
          border: OutlineInputBorder(),
        ),
        validator: (v) {
          final n = double.tryParse((v ?? '').trim());
          if (n == null || n < 0) return 'Enter a fee of 0 or more';
          return null;
        },
      ),
      // Add space before the form buttons.
      const SizedBox(height: 24),
      // Show cancel and save buttons.
      _buttons(),
    ];
  }

  // Build the fields and cost summary used for an order.
  List<Widget> _orderFields() {
    // Read the saved delivery address.
    final address = SettingsStore.instance.address;
    // Calculate tip amount, total cost, and title style.
    final tipAmount = _subtotal * _tip / 100;
    final total = _subtotal + _fee + tipAmount;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return [
      // Show the restaurant and delivery address.
      Text('Ordering from ${widget.restaurant!.name}', style: titleStyle),
      const SizedBox(height: 4),
      Text(
        address.isEmpty
            ? 'No delivery address set (add one in Settings).'
            : 'Delivering to: $address',
      ),
      const SizedBox(height: 16),
      // Enter the items and validate that the field is not empty.
      TextFormField(
        controller: _itemsCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Items (separate with commas)',
          hintText: 'e.g. Cheeseburger, Fries',
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Add at least one item' : null,
      ),
      const SizedBox(height: 16),
      // Enter and validate the items subtotal.
      TextFormField(
        controller: _subtotalCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Items subtotal',
          prefixText: '\$',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          final n = double.tryParse((v ?? '').trim());
          if (n == null || n <= 0) return 'Enter an amount above 0';
          return null;
        },
      ),
      const SizedBox(height: 12),
      // Open the date picker.
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today),
        label: Text('Order date: ${formatDate(_date)}'),
      ),
      const SizedBox(height: 12),
      // Let the user select the tip percentage.
      TipSlider(
        initialPercent: _tip,
        subtotal: _subtotal,
        onChanged: (v) => setState(() => _tip = v),
      ),
      // Show delivery fee, tip, and total cost.
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delivery: ${money(_fee)}'),
              Text('Tip: ${money(tipAmount)}'),
              Text(
                'Total: ${money(total)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      // Add space before the form buttons.
      const SizedBox(height: 16),
      // Show cancel and place-order buttons.
      _buttons(),
    ];
  }

  // Build the overall page and choose the correct form fields.
  @override
  Widget build(BuildContext context) {
    // Choose a title based on the form type and whether an item exists.
    final String title;
    if (widget.isOrder) {
      title = widget.order == null ? 'New order' : 'Edit order';
    } else {
      title = widget.restaurant == null ? 'New restaurant' : 'Edit restaurant';
    }

    // Put the form inside a standard page layout.
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // Validate fields and display the correct set in a scrollable list.
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: widget.isOrder ? _orderFields() : _restaurantFields(),
        ),
      ),
    );
  }
}
