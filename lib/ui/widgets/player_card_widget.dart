import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// Player status card displaying nickname, turn indicator, connection status, and score for all 4 colors.
class PlayerCardWidget extends StatelessWidget {
  final PlayerProfile player;
  final bool isCurrentTurn;
  final int finishedTokens;
  final int remainingSeconds;
  final bool isMe;

  const PlayerCardWidget({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.finishedTokens,
    this.remainingSeconds = 25,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = player.color.primaryColor;
    final darkColor = player.color.darkColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppTheme.surfaceCard
            : AppTheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? primaryColor : Colors.white.withOpacity(0.1),
          width: isCurrentTurn ? 2.2 : 1,
        ),
        boxShadow: [
          if (isCurrentTurn)
            BoxShadow(
              color: primaryColor.withOpacity(0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Avatar Circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, darkColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: Colors.white.withOpacity(0.9),
                  size: 22,
                ),
                // Connection indicator dot
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: player.isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Player Name & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      player.displayName,
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontWeight:
                            isCurrentTurn ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Finished tokens score dots
                  for (int i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 2.5),
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: i < finishedTokens
                            ? primaryColor
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 3),
                  Text(
                    '$finishedTokens/4',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Turn countdown badge if it's current turn
          if (isCurrentTurn) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primaryColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                '${remainingSeconds}s',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
