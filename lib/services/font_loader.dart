// lib/services/font_loader.dart
// Loads a user-uploaded .ttf or .otf file at runtime as a font family.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomFontLoader {
  CustomFontLoader._();
  static final CustomFontLoader instance = CustomFontLoader._();

  String? loadedFamilyName;

  /// Load a TTF/OTF font from raw bytes. The font becomes available under [familyName].
  Future<bool> loadFont(String familyName, Uint8List bytes) async {
    try {
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      loadedFamilyName = familyName;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_font_name',  familyName);
        await prefs.setString('custom_font_bytes', base64Encode(bytes));
      } catch (_) {}
      return true;
    } catch (_) { return false; }
  }

  /// Reload the previously saved custom font on app startup.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name  = prefs.getString('custom_font_name');
      final raw   = prefs.getString('custom_font_bytes');
      if (name != null && raw != null) {
        final bytes = base64Decode(raw);
        final loader = FontLoader(name);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        loadedFamilyName = name;
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_font_name');
      await prefs.remove('custom_font_bytes');
    } catch (_) {}
    loadedFamilyName = null;
  }
}
