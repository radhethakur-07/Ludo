import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

class GameDialogs {
  /// Displays the victory celebration dialog with Rematch and Exit buttons.
  static Future<void> showVictoryDialog({
    required BuildContext context,
    required PlayerColor winner,
    required bool isMeWinner,
    required VoidCallback onRematch,
    required VoidCallback onExit,
  }) {
    final winnerColor = winner == PlayerColor.red
        ? AppTheme.redPrimary
        : AppTheme.greenPrimary;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy Icon
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gold.withOpacity(0.2),
                  border: Border.all(color: AppTheme.gold, width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppTheme.gold,
                  size: 46,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                isMeWinner ? 'VICTORY!' : 'GAME OVER',
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                '${winner.displayName} has conquered the board!',
                style: TextStyle(
                  color: winnerColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onExit();
                      },
                      child: const Text('Exit Home'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onRematch();
                      },
                      child: const Text('Rematch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays leave confirmation dialog.
  static Future<bool> showLeaveConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Game?',
          style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to leave this game? If you leave, the match will be forfeited.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Displays join room dialog where user enters 6-character room code.
  static Future<String?> showJoinRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Enter Room Code',
          style: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-character code provided by your friend to join the match.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 24,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'e.g. 7K2X9P',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 16,
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.gold, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.length == 6) {
                Navigator.of(ctx).pop(code);
              }
            },
            child: const Text('Join Room'),
          ),
        ],
      ),
    );
  }
}
