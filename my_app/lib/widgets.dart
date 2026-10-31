import 'package:flutter/material.dart';

import 'estimate.dart';
import 'models.dart';

// Shows an order's progress and lets the user change its status.
class StatusTracker extends StatefulWidget {
  final OrderStatus status;
  final ValueChanged<OrderStatus> onChanged;

  const StatusTracker({
    super.key,
    required this.status,
    required this.onChanged,
  });

  @override
  State<StatusTracker> createState() => _StatusTrackerState();
}

class _StatusTrackerState extends State<StatusTracker> {
  // Keep the current status so the screen can update when it changes.
  late OrderStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
  }

  void _set(OrderStatus s) {
    // Update this screen and tell the parent about the new status.
    setState(() => _status = s);
    widget.onChanged(s); // parent saves it to SQLite
  }

  @override
  Widget build(BuildContext context) {
    // Use the theme color for completed steps.
    final color = Theme.of(context).colorScheme.primary;
    // Stop the user from moving past the final step.
    final canAdvance = _status != OrderStatus.delivered;
    return Column(
      children: [
        Row(
          children: [
            // Show every status and mark steps reached so far.
            for (final s in OrderStatus.values)
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      s.index <= _status.index
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: s.index <= _status.index ? color : Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                // Reset is disabled when already at the first step.
                onPressed: _status == OrderStatus.placed
                    ? null
                    : () => _set(OrderStatus.placed),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                // Move to the next status unless this order is finished.
                onPressed: canAdvance
                    ? () => _set(OrderStatus.values[_status.index + 1])
                    : null,
                child: const Text('Next step'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Lets the user choose a tip and shows its amount.
class TipSlider extends StatefulWidget {
  final int initialPercent;
  final double subtotal;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  const TipSlider({
    super.key,
    required this.initialPercent,
    required this.subtotal,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<TipSlider> createState() => _TipSliderState();
}

class _TipSliderState extends State<TipSlider> {
  // Store the slider value as a number.
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialPercent.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Work out the rounded tip percent and amount.
    final percent = _value.round();
    final tipAmount = widget.subtotal * percent / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tip: $percent% (${money(tipAmount)})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: _value,
          min: 0,
          max: 30,
          divisions: 30,
          label: '$percent%',
          onChanged: (v) {
            // Update the slider and share the new percent.
            setState(() => _value = v);
            widget.onChanged?.call(v.round());
          },
          onChangeEnd: (v) => widget.onChangeEnd?.call(v.round()),
        ),
      ],
    );
  }
}

// Shows a cost estimate and lets the user enter or hide an amount.
class EstimateCard extends StatefulWidget {
  final List<Order> orders;
  const EstimateCard({super.key, required this.orders});

  @override
  State<EstimateCard> createState() => _EstimateCardState();
}

class _EstimateCardState extends State<EstimateCard> {
  // Store the text field and the estimate choices.
  final _ctrl = TextEditingController();
  bool _ignored = false;
  double? _own;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _useOwn() {
    // Read the entered amount and check that it is above zero.
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    setState(() {
      _own = v;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    // Show a small message when the user hides the estimate.
    if (_ignored) {
      return Card(
        child: ListTile(
          title: const Text('Estimate hidden'),
          trailing: TextButton(
            onPressed: () => setState(() => _ignored = false),
            child: const Text('Show estimate'),
          ),
        ),
      );
    }

  // Get an estimate based on past orders.
    final est = estimateNextOrder(widget.orders);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order cost estimate', style: style.titleMedium),
            const SizedBox(height: 8),
            if (est == null)
              // Explain why there is no estimate to show.
              const Text('No past orders here yet, so there is no estimate.')
            else ...[
              Text(est.message),
              Text(est.explanation, style: style.bodySmall),
              Text(Estimate.method, style: style.bodySmall),
              Text(
                'Baseline (last order): ${money(est.baseline)}',
                style: style.bodySmall,
              ),
            ],
            if (_own != null) ...[
              // Show the amount entered by the user.
              const SizedBox(height: 8),
              Text(
                'Planning with your amount: ${money(_own!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    // Let the user enter an amount to plan with.
                    controller: _ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Your own amount (\$)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _useOwn(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _useOwn,
                  child: const Text('Use'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                // Hide the estimate and clear the user's amount.
                onPressed: () => setState(() {
                  _ignored = true;
                  _own = null;
                  _error = null;
                  _ctrl.clear();
                }),
                child: const Text('Ignore estimate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
