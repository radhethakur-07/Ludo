import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/services/firebase_service.dart';
import 'package:duo_ludo/services/room_service.dart';
import 'package:duo_ludo/ui/screens/game_screen.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// Private room waiting lobby screen for host and joining players.
class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final RoomService _roomService = RoomService();
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<RoomModel?>? _sub;
  RoomModel? _currentRoom;

  @override
  void initState() {
    super.initState();
    _sub = _roomService.streamRoom(widget.roomCode).listen((room) {
      if (!mounted) return;
      setState(() {
        _currentRoom = room;
      });

      // If second player joined and game is active, launch into game screen!
      if (room != null &&
          room.opponent != null &&
          room.status == GameStatus.inProgress) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              roomCode: widget.roomCode,
              isHost: widget.isHost,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code ${widget.roomCode} copied to clipboard!'),
        backgroundColor: AppTheme.surfaceCard,
      ),
    );
  }

  void _shareInvite() {
    final shareText =
        '🎲 Play Duo Ludo with me! Join my private 2-player match with Room Code: ${widget.roomCode}\n'
        'Download Duo Ludo and enter the code to play instantly!';
    Share.share(shareText, subject: 'Duo Ludo Match Invitation');
  }

  @override
  Widget build(BuildContext context) {
    final room = _currentRoom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Room Code Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'ROOM CODE',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.roomCode,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 38,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surface,
                            foregroundColor: AppTheme.textLight,
                            elevation: 0,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Code'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _shareInvite,
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share Invite'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Players Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PLAYERS (1/2)',
                  style: TextStyle(
                    color: AppTheme.textMuted.withOpacity(0.8),
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Player 1 (Host)
              _buildPlayerCard(
                name: room?.host.displayName ?? 'Host Player',
                colorName: room?.host.color.displayName ?? 'Red',
                color: room?.host.color.primaryColor ?? AppTheme.redPrimary,
                isReady: true,
                badgeText: 'HOST',
              ),
              const SizedBox(height: 14),

              // Player 2 (Opponent)
              if (room?.opponent != null)
                _buildPlayerCard(
                  name: room!.opponent!.displayName,
                  colorName: room.opponent!.color.displayName,
                  color: room.opponent!.color.primaryColor,
                  isReady: true,
                  badgeText: 'OPPONENT',
                )
              else
                _buildWaitingPlayerCard(),

              const SizedBox(height: 24),

              // Choose Your Token Color Section
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined, color: AppTheme.gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'CHOOSE YOUR COLOR',
                      style: TextStyle(
                        color: AppTheme.textMuted.withOpacity(0.9),
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildColorSelector(room),

              const Spacer(),

              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.blueAccent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Send this room code to your opponent. The match starts immediately once they join!',
                        style: TextStyle(
                          color: AppTheme.textMuted.withOpacity(0.9),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required String colorName,
    required Color color,
    required bool isReady,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 22,
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$colorName Team',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingPlayerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.greenPrimary.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for opponent...',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Green Team',
                  style: TextStyle(
                    color: AppTheme.greenLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(RoomModel? room) {
    final myUid = _firebaseService.currentUserId;
    final isMeHost = widget.isHost || (room?.host.uid == myUid);
    final myCurrentColor = isMeHost
        ? (room?.host.color ?? PlayerColor.red)
        : (room?.opponent?.color ?? PlayerColor.green);
    final opponentColor = isMeHost ? room?.opponent?.color : room?.host.color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: PlayerColor.values.map((color) {
        final isSelectedByMe = color == myCurrentColor;
        final isTakenByOther = color == opponentColor;

        return GestureDetector(
          onTap: () async {
            if (isSelectedByMe) return;
            if (isTakenByOther) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${color.displayName} is already reserved by another player!'),
                  backgroundColor: AppTheme.surfaceCard,
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }

            try {
              await _roomService.selectPlayerColor(
                roomCode: widget.roomCode,
                playerUid: myUid,
                newColor: color,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: AppTheme.surfaceCard,
                  ),
                );
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelectedByMe
                    ? Colors.white
                    : (isTakenByOther
                        ? Colors.transparent
                        : color.primaryColor.withOpacity(0.4)),
                width: isSelectedByMe ? 3 : 1.5,
              ),
              boxShadow: isSelectedByMe
                  ? [
                      BoxShadow(
                        color: color.primaryColor.withOpacity(0.55),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Opacity(
              opacity: isTakenByOther ? 0.35 : 1.0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.primaryColor,
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 0.8,
                    colors: [
                      color.lightColor,
                      color.primaryColor,
                      color.darkColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: isSelectedByMe
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : (isTakenByOther
                          ? const Icon(Icons.lock,
                              color: Colors.white70, size: 18)
                          : null),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
