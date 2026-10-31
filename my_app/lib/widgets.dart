import 'package:flutter/material.dart';

import 'estimate.dart';
import 'models.dart';

// =====================================================================
// StatefulWidget: status tracker (Placed > Preparing > On the way > Delivered)
// =====================================================================
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
  late OrderStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
  }

  void _set(OrderStatus s) {
    setState(() => _status = s);
    widget.onChanged(s); // parent saves it to SQLite
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final canAdvance = _status != OrderStatus.delivered;
    return Column(
      children: [
        Row(
          children: [
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
                    Text(s.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
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
                onPressed: _status == OrderStatus.placed
                    ? null
                    : () => _set(OrderStatus.placed),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
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

// =====================================================================
// StatefulWidget: tip slider (0-30%)
// =====================================================================
class TipSlider extends StatefulWidget {
  final int initialPercent;
  final double subtotal;
  final ValueChanged<int>? onChanged; // every move
  final ValueChanged<int>? onChangeEnd; // when the finger lifts

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
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialPercent.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final percent = _value.round();
    final tipAmount = widget.subtotal * percent / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tip: $percent% (${money(tipAmount)})',
            style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: _value,
          min: 0,
          max: 30,
          divisions: 30,
          label: '$percent%',
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged?.call(v.round());
          },
          onChangeEnd: (v) => widget.onChangeEnd?.call(v.round()),
        ),
      ],
    );
  }
}

// =====================================================================
// StatefulWidget: Order Cost Estimate (rule-based, local)
// Shows the estimate, why, the method, and the baseline. The user can
// type their own amount or tap "Ignore estimate".
// =====================================================================
class EstimateCard extends StatefulWidget {
  final List<Order> orders;
  const EstimateCard({super.key, required this.orders});

  @override
  State<EstimateCard> createState() => _EstimateCardState();
}

class _EstimateCardState extends State<EstimateCard> {
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
              const Text(
                  'No past orders here yet, so there is no estimate.')
            else ...[
              Text(est.message),
              Text(est.explanation, style: style.bodySmall),
              Text(Estimate.method, style: style.bodySmall),
              Text('Baseline (last order): ${money(est.baseline)}',
                  style: style.bodySmall),
            ],
            if (_own != null) ...[
              const SizedBox(height: 8),
              Text('Planning with your amount: ${money(_own!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
