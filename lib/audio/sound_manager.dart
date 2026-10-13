import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages sound effects and tactile haptic feedback with user preferences.
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  bool _isSoundEnabled = true;
  bool _isHapticsEnabled = true;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticsEnabled => _isHapticsEnabled;

  static const String _keySound = 'pref_sound_enabled';
  static const String _keyHaptics = 'pref_haptics_enabled';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool(_keySound) ?? true;
      _isHapticsEnabled = prefs.getBool(_keyHaptics) ?? true;
    } catch (_) {
      // SharedPreferences fallback
    }
  }

  Future<void> toggleSound(bool enabled) async {
    _isSoundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, enabled);
  }

  Future<void> toggleHaptics(bool enabled) async {
    _isHapticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, enabled);
  }

  /// Play dice rolling sound & haptic
  void playDiceRoll() {
    if (_isHapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (_isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play token step / move sound & light haptic
  void playTokenMove() {
    if (_isHapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    if (_isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play capture explosion sound & strong haptic vibration
  void playCapture() {
    if (_isHapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
    if (_isSoundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  /// Play safe star arrival sound
  void playSafeSquare() {
    if (_isHapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  /// Play victory fanfare and celebratory haptics
  void playVictory() {
    if (_isHapticsEnabled) {
      HapticFeedback.vibrate();
    }
    if (_isSoundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
  }
}
