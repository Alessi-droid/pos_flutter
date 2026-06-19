// lib/providers/config_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigProvider extends ChangeNotifier {
  static const String _textScaleKey = 'text_scale_factor';
  double _textScaleFactor = 1.0;

  double get textScaleFactor => _textScaleFactor;

  ConfigProvider() {
    _loadTextScale();
  }

  Future<void> _loadTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    _textScaleFactor = prefs.getDouble(_textScaleKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double value) async {
    _textScaleFactor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, value);
    notifyListeners();
  }
}