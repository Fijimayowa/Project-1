import 'package:flutter/material.dart';

import 'db.dart';
import 'models.dart';
import 'settings_store.dart';
import 'widgets.dart';

/// One form screen for both entities:
///   FormScreen.restaurant(...)  add or edit a restaurant
///   FormScreen.order(...)       add or edit an order
/// Pops with a message string when saved (or null if cancelled).
class FormScreen extends StatefulWidget {
  final Restaurant? restaurant; // being edited, or the order's restaurant
  final Order? order;
  final bool isOrder;

  const FormScreen.restaurant({super.key, Restaurant? existing})
      : restaurant = existing,
        order = null,
        isOrder = false;

  const FormScreen.order({
    super.key,
    required Restaurant restaurant,
    Order? existing,
  })  : restaurant = restaurant,
        order = existing,
        isOrder = true;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  static const _cuisines = [
    'American',
    'Japanese',
    'Mexican',
    'Italian',
    'Indian',
    'Chinese',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();

  String? _cuisine;
  int _tip = 15;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    final o = widget.order;
    if (!widget.isOrder) {
      _nameCtrl.text = r?.name ?? '';
      _feeCtrl.text = r == null ? '' : r.deliveryFee.toStringAsFixed(2);
      _cuisine = r?.cuisine;
    } else {
      _itemsCtrl.text = o?.items ?? '';
      _subtotalCtrl.text = o == null ? '' : o.subtotal.toStringAsFixed(2);
      _tip = o?.tipPercent ?? 15;
      _date = o?.date ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    _itemsCtrl.dispose();
    _subtotalCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => double.tryParse(_subtotalCtrl.text.trim()) ?? 0;

  double get _fee =>
      widget.order?.deliveryFee ?? widget.restaurant?.deliveryFee ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final String message;
      if (widget.isOrder) {
        final old = widget.order;
        await AppDb.instance.saveOrder(Order(
          id: old?.id,
          restaurantId: widget.restaurant!.id!,
          items: _itemsCtrl.text.trim(),
          subtotal: double.parse(_subtotalCtrl.text.trim()),
          deliveryFee: _fee,
          tipPercent: _tip,
          status: old?.status ?? OrderStatus.placed,
          date: _date,
        ));
        message = old == null ? 'Order placed' : 'Order updated';
      } else {
        final old = widget.restaurant;
        await AppDb.instance.saveRestaurant(Restaurant(
          id: old?.id,
          name: _nameCtrl.text.trim(),
          cuisine: _cuisine!,
          deliveryFee: double.parse(_feeCtrl.text.trim()),
        ));
        message = old == null ? 'Restaurant added' : 'Restaurant updated';
      }
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Widget _buttons() {
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

  List<Widget> _restaurantFields() {
    return [
      TextFormField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Restaurant name',
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
      ),
      const SizedBox(height: 16),
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
      const SizedBox(height: 16),
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
      const SizedBox(height: 24),
      _buttons(),
    ];
  }

  List<Widget> _orderFields() {
    final address = SettingsStore.instance.address;
    final tipAmount = _subtotal * _tip / 100;
    final total = _subtotal + _fee + tipAmount;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return [
      Text('Ordering from ${widget.restaurant!.name}', style: titleStyle),
      const SizedBox(height: 4),
      Text(address.isEmpty
          ? 'No delivery address set (add one in Settings).'
          : 'Delivering to: $address'),
      const SizedBox(height: 16),
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
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today),
        label: Text('Order date: ${formatDate(_date)}'),
      ),
      const SizedBox(height: 12),
      TipSlider(
        initialPercent: _tip,
        subtotal: _subtotal,
        onChanged: (v) => setState(() => _tip = v),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delivery: ${money(_fee)}'),
              Text('Tip: ${money(tipAmount)}'),
              Text('Total: ${money(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buttons(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    if (widget.isOrder) {
      title = widget.order == null ? 'New order' : 'Edit order';
    } else {
      title = widget.restaurant == null ? 'New restaurant' : 'Edit restaurant';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
