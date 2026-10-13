import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// Player status card displaying nickname, turn indicator, connection status, and score.
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
    final isRed = player.color == PlayerColor.red;
    final primaryColor = isRed ? AppTheme.redPrimary : AppTheme.greenPrimary;
    final secondaryColor =
        isRed ? AppTheme.redSecondary : AppTheme.greenSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppTheme.surfaceCard
            : AppTheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentTurn ? primaryColor : Colors.white.withOpacity(0.1),
          width: isCurrentTurn ? 2.2 : 1,
        ),
        boxShadow: [
          if (isCurrentTurn)
            BoxShadow(
              color: primaryColor.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Avatar Circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 6,
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
                  size: 26,
                ),
                // Connection indicator dot
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: player.isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Player Name & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.displayName,
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontWeight:
                          isCurrentTurn ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isMe)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Finished tokens score
                  for (int i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < finishedTokens
                            ? primaryColor
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '$finishedTokens/4 Home',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Turn countdown ring if it's current turn
          if (isCurrentTurn) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
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
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
