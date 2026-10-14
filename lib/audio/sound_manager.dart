import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages playable audio assets, background music, and tactile haptic feedback.
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  bool _isSoundEnabled = true;
  bool _isHapticsEnabled = true;
  bool _isBgmEnabled = false;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticsEnabled => _isHapticsEnabled;
  bool get isBgmEnabled => _isBgmEnabled;

  static const String _keySound = 'pref_sound_enabled';
  static const String _keyHaptics = 'pref_haptics_enabled';
  static const String _keyBgm = 'pref_bgm_enabled';

  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool(_keySound) ?? true;
      _isHapticsEnabled = prefs.getBool(_keyHaptics) ?? true;
      _isBgmEnabled = prefs.getBool(_keyBgm) ?? false;

      _sfxPlayer = AudioPlayer();
      _bgmPlayer = AudioPlayer();
      await _bgmPlayer?.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer?.setVolume(0.25);

      if (_isBgmEnabled) {
        startBgm();
      }
    } catch (_) {
      // Audio fallback
    }
  }

  Future<void> toggleSound(bool enabled) async {
    _isSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySound, enabled);
    } catch (_) {}
  }

  Future<void> toggleHaptics(bool enabled) async {
    _isHapticsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHaptics, enabled);
    } catch (_) {}
  }

  Future<void> toggleBgm(bool enabled) async {
    _isBgmEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBgm, enabled);
    } catch (_) {}

    if (enabled) {
      startBgm();
    } else {
      stopBgm();
    }
  }

  void startBgm() {
    if (!_isBgmEnabled) return;
    try {
      _bgmPlayer?.play(AssetSource('audio/bgm.wav'));
    } catch (_) {}
  }

  void stopBgm() {
    try {
      _bgmPlayer?.stop();
    } catch (_) {}
  }

  Future<void> _playSfx(String path, {double volume = 0.85}) async {
    if (!_isSoundEnabled) return;
    try {
      _sfxPlayer?.stop();
      await _sfxPlayer?.setVolume(volume);
      await _sfxPlayer?.play(AssetSource(path));
    } catch (_) {
      // Fallback to system audio
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play dice rolling sound & haptic
  void playDiceRoll() {
    if (_isHapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    _playSfx('audio/dice_roll.wav');
  }

  /// Play dice landing impact sound
  void playDiceLand() {
    if (_isHapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    _playSfx('audio/dice_land.wav');
  }

  /// Play token step sound & light haptic
  void playTokenMove() {
    if (_isHapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    _playSfx('audio/token_step.wav', volume: 0.7);
  }

  /// Play capture explosion sound & strong haptic vibration
  void playCapture() {
    if (_isHapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
    _playSfx('audio/token_capture.wav', volume: 1.0);
  }

  /// Play safe star arrival sound
  void playSafeSquare() {
    if (_isHapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    _playSfx('audio/token_home.wav', volume: 0.6);
  }

  /// Play token reaching home sound
  void playTokenHome() {
    if (_isHapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    _playSfx('audio/token_home.wav', volume: 0.95);
  }

  /// Play player turn notification alert
  void playTurnAlert() {
    if (_isHapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    _playSfx('audio/turn_alert.wav', volume: 0.6);
  }

  /// Play victory fanfare and celebratory haptics
  void playVictory() {
    if (_isHapticsEnabled) {
      HapticFeedback.vibrate();
    }
    _playSfx('audio/victory.wav', volume: 1.0);
  }

  /// Play defeat sound
  void playDefeat() {
    _playSfx('audio/defeat.wav', volume: 0.8);
  }
}
