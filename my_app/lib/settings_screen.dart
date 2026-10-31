import 'package:flutter/material.dart';

import 'settings_store.dart';
import 'ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _addressCtrl =
      TextEditingController(text: SettingsStore.instance.address);

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    await SettingsStore.instance.saveAddress(_addressCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Address saved')));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return PhotoBackground(
      asset: kSushiBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery address', style: titleStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Street, city',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saveAddress,
                        child: const Text('Save address'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: titleStyle),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system, label: Text('System')),
                        ButtonSegment(
                            value: ThemeMode.light, label: Text('Light')),
                        ButtonSegment(
                            value: ThemeMode.dark, label: Text('Dark')),
                      ],
                      selected: {SettingsStore.instance.themeMode.value},
                      onSelectionChanged: (s) {
                        SettingsStore.instance.setTheme(s.first);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
