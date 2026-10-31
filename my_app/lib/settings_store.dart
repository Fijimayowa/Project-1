import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Delivery address and theme, saved with SharedPreferences.
class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  String address = '';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    address = p.getString('address') ?? '';
    final saved = p.getString('theme');
    themeMode.value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveAddress(String value) async {
    address = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('address', value);
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', mode.name);
  }
}
