import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/services/firebase_service.dart';
import 'package:duo_ludo/services/room_service.dart';
import 'package:duo_ludo/services/settings_service.dart';
import 'package:duo_ludo/ui/screens/game_screen.dart';
import 'package:duo_ludo/ui/screens/lobby_screen.dart';
import 'package:duo_ludo/ui/screens/settings_screen.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';
import 'package:duo_ludo/ui/widgets/dialogs/game_dialogs.dart';

/// Main home dashboard for Duo Ludo with game modes, room actions, and profile display.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SettingsService _settingsService = SettingsService();
  final FirebaseService _firebaseService = FirebaseService();
  final RoomService _roomService = RoomService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _handleCreateRoom() async {
    setState(() => _isLoading = true);
    try {
      final hostUid = await _firebaseService.ensureAnonymousUser();
      final roomCode = await _roomService.createRoom(
        hostName: _settingsService.nickname,
        hostUid: hostUid,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: roomCode,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create room: $e')),
      );
    }
  }

  Future<void> _handleJoinRoom() async {
    final code = await GameDialogs.showJoinRoomDialog(context);
    if (code == null || code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final guestUid = await _firebaseService.ensureAnonymousUser();
      await _roomService.joinRoom(
        roomCode: code,
        guestName: _settingsService.nickname,
        guestUid: guestUid,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomCode: code,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.redPrimary,
        ),
      );
    }
  }

  void _startLocalGame() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Select Players',
          style: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlayerCountOption(
              title: '2 Players',
              subtitle: 'Red vs Yellow (Classic Opposite)',
              colors: [PlayerColor.red, PlayerColor.yellow],
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GameScreen(
                      roomCode: null,
                      isHost: true,
                      activePlayers: [PlayerColor.red, PlayerColor.yellow],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildPlayerCountOption(
              title: '3 Players',
              subtitle: 'Red, Green & Yellow',
              colors: [PlayerColor.red, PlayerColor.green, PlayerColor.yellow],
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GameScreen(
                      roomCode: null,
                      isHost: true,
                      activePlayers: [
                        PlayerColor.red,
                        PlayerColor.green,
                        PlayerColor.yellow,
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildPlayerCountOption(
              title: '4 Players',
              subtitle: 'Full Board (Red, Green, Yellow, Blue)',
              colors: [
                PlayerColor.red,
                PlayerColor.green,
                PlayerColor.yellow,
                PlayerColor.blue,
              ],
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GameScreen(
                      roomCode: null,
                      isHost: true,
                      activePlayers: [
                        PlayerColor.red,
                        PlayerColor.green,
                        PlayerColor.yellow,
                        PlayerColor.blue,
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCountOption({
    required String title,
    required String subtitle,
    required List<PlayerColor> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Row(
              children: [
                for (final c in colors)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('DUO LUDO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Player Profile Bar
                    _buildProfileBar(),
                    const SizedBox(height: 24),

                    // Game Mode Cards
                    _buildModeCard(
                      title: 'Pass & Play',
                      subtitle: 'Play 2-player local match on this device',
                      icon: Icons.phone_android_rounded,
                      color: AppTheme.gold,
                      onTap: _startLocalGame,
                      badge: 'OFFLINE READY',
                    ),
                    const SizedBox(height: 16),

                    _buildModeCard(
                      title: 'Create Private Room',
                      subtitle: 'Generate a code & invite a friend online',
                      icon: Icons.add_circle_outline_rounded,
                      color: AppTheme.redPrimary,
                      onTap: _handleCreateRoom,
                      badge: 'HOST',
                    ),
                    const SizedBox(height: 16),

                    _buildModeCard(
                      title: 'Join Room',
                      subtitle: 'Enter a 6-character room code to join',
                      icon: Icons.login_rounded,
                      color: AppTheme.greenPrimary,
                      onTap: _handleJoinRoom,
                      badge: 'GUEST',
                    ),
                    const SizedBox(height: 28),

                    // Firebase status indicator
                    _buildStatusBanner(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.gold.withOpacity(0.2),
            radius: 24,
            child: const Icon(
              Icons.sports_esports_rounded,
              color: AppTheme.gold,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _settingsService.nickname,
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Guest Player • Ready',
                  style: TextStyle(
                    color: AppTheme.greenLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.textMuted, size: 20),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isOnlineReady = _firebaseService.isFirebaseAvailable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnlineReady
              ? AppTheme.greenPrimary.withOpacity(0.3)
              : AppTheme.gold.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnlineReady ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
            color: isOnlineReady ? AppTheme.greenPrimary : AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOnlineReady
                  ? 'Firebase Online Multiplayer Connected'
                  : 'Multiplayer: Ready (Local Pass & Play always available)',
              style: TextStyle(
                color: isOnlineReady ? AppTheme.greenLight : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
