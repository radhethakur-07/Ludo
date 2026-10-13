import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local player profile and settings.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyNickname = 'pref_player_nickname';
  static const String _keySound = 'pref_sound_enabled';
  static const String _keyHaptics = 'pref_haptics_enabled';

  String _nickname = '';
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  String get nickname => _nickname;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_keySound) ?? true;
    _hapticsEnabled = prefs.getBool(_keyHaptics) ?? true;

    final savedNick = prefs.getString(_keyNickname);
    if (savedNick != null && savedNick.isNotEmpty) {
      _nickname = savedNick;
    } else {
      final randomNum = (Random().nextInt(9000) + 1000);
      _nickname = 'Player$randomNum';
      await prefs.setString(_keyNickname, _nickname);
    }
  }

  Future<void> setNickname(String name) async {
    _nickname = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, _nickname);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, enabled);
  }
}
