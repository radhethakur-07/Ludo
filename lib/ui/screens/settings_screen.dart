import 'package:flutter/material.dart';
import 'package:duo_ludo/audio/sound_manager.dart';
import 'package:duo_ludo/services/settings_service.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// Screen for managing player profile nickname, sound, haptics, and game rules.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _soundManager = SoundManager();
  late TextEditingController _nameController;
  late TextEditingController _agoraAppIdController;

  bool _sound = true;
  bool _haptics = true;
  bool _bgm = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _settingsService.nickname);
    _agoraAppIdController =
        TextEditingController(text: _settingsService.agoraAppId);
    _sound = _settingsService.soundEnabled;
    _haptics = _settingsService.hapticsEnabled;
    _bgm = _soundManager.isBgmEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _agoraAppIdController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      _settingsService.setNickname(name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname updated!')),
      );
    }
  }

  void _saveAgoraAppId() {
    final appId = _agoraAppIdController.text.trim();
    _settingsService.setAgoraAppId(appId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice Chat App ID saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Card
          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLAYER PROFILE',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          maxLength: 14,
                          decoration: InputDecoration(
                            labelText: 'Nickname',
                            counterText: '',
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _saveName(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onPressed: _saveName,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Audio & Haptics Card
          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUDIO & FEEDBACK',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Sound Effects'),
                    subtitle: const Text('Dice roll, move clicks, and alert tones'),
                    value: _sound,
                    activeColor: AppTheme.gold,
                    onChanged: (val) {
                      setState(() => _sound = val);
                      _settingsService.setSoundEnabled(val);
                      _soundManager.toggleSound(val);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    title: const Text('Background Music'),
                    subtitle: const Text('Calming ambient game music'),
                    value: _bgm,
                    activeColor: AppTheme.gold,
                    onChanged: (val) {
                      setState(() => _bgm = val);
                      _soundManager.toggleBgm(val);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    title: const Text('Haptic Vibration'),
                    subtitle: const Text('Tactile responses on rolls and captures'),
                    value: _haptics,
                    activeColor: AppTheme.gold,
                    onChanged: (val) {
                      setState(() => _haptics = val);
                      _settingsService.setHapticsEnabled(val);
                      _soundManager.toggleHaptics(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Voice Chat (Agora RTC) Card
          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mic, color: AppTheme.gold, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'LIVE VOICE CHAT (AGORA RTC)',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Talk with friends during online matches. Get your free App ID from console.agora.io (10,000 free minutes/mo).',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _agoraAppIdController,
                          decoration: InputDecoration(
                            labelText: 'Agora App ID',
                            hintText: 'Paste App ID here...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _saveAgoraAppId(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onPressed: _saveAgoraAppId,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Ludo Rules Reference
          Card(
            color: AppTheme.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CLASSIC LUDO RULES',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRuleRow(
                    '🎲 Roll a 6 to exit',
                    'A token in the base yard needs a roll of 6 to start.',
                  ),
                  _buildRuleRow(
                    '⭐ Safe Squares',
                    'Tokens on star tiles or start tiles cannot be captured.',
                  ),
                  _buildRuleRow(
                    '💥 Token Capture',
                    'Landing on an opponent token outside safe tiles sends them back to yard and grants you an extra roll!',
                  ),
                  _buildRuleRow(
                    '🔁 Bonus Roll on 6',
                    'Rolling a 6 grants an extra turn (max 3 in a row).',
                  ),
                  _buildRuleRow(
                    '🏠 Bonus Roll on Home',
                    'Moving a token into the final center triangle awards a bonus roll!',
                  ),
                  _buildRuleRow(
                    '🎯 Exact Roll for Home',
                    'Tokens must roll the exact number required to enter the center triangle.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
