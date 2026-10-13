import 'dart:async';
import 'package:flutter/material.dart';
import 'package:duo_ludo/audio/sound_manager.dart';
import 'package:duo_ludo/engine/ludo_constants.dart';
import 'package:duo_ludo/engine/ludo_engine.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/services/firebase_service.dart';
import 'package:duo_ludo/services/room_service.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';
import 'package:duo_ludo/ui/widgets/board/ludo_board_widget.dart';
import 'package:duo_ludo/ui/widgets/dialogs/game_dialogs.dart';
import 'package:duo_ludo/ui/widgets/dice/dice_widget.dart';
import 'package:duo_ludo/ui/widgets/player_card_widget.dart';

/// Active game screen supporting both Local Pass & Play and Online Multiplayer.
class GameScreen extends StatefulWidget {
  final String? roomCode; // null = Local mode
  final bool isHost;

  const GameScreen({
    super.key,
    this.roomCode,
    this.isHost = true,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final SoundManager _soundManager = SoundManager();
  final RoomService _roomService = RoomService();
  final FirebaseService _firebaseService = FirebaseService();

  late LudoEngine _engine;
  StreamSubscription<RoomModel?>? _roomSubscription;
  RoomModel? _onlineRoom;

  // Local turn timer
  Timer? _countdownTimer;
  int _secondsRemaining = LudoConstants.turnTimeoutSeconds;

  bool get isOnline => widget.roomCode != null;
  PlayerColor get myColor => widget.isHost ? PlayerColor.red : PlayerColor.green;

  bool get isMyTurn {
    if (!isOnline) return true; // Local mode: always allow turn player
    return _engine.currentTurn == myColor;
  }

  @override
  void initState() {
    super.initState();
    _engine = LudoEngine.newGame();

    if (isOnline) {
      _listenToRoom();
    } else {
      _startTurnTimer();
    }
  }

  void _listenToRoom() {
    _roomSubscription =
        _roomService.streamRoom(widget.roomCode!).listen((room) {
      if (!mounted || room == null) return;

      setState(() {
        _onlineRoom = room;
        _engine = room.engine;
      });

      _startTurnTimer();

      // Check win dialog
      if (_engine.status == GameStatus.completed && _engine.winner != null) {
        _showGameOverModal(_engine.winner!);
      }
    });
  }

  void _startTurnTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = LudoConstants.turnTimeoutSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          // Time expired
          _handleTurnTimeout();
        }
      });
    });
  }

  void _handleTurnTimeout() {
    _countdownTimer?.cancel();
    if (_engine.status != GameStatus.inProgress) return;

    if (!isOnline) {
      setState(() {
        _engine.timeoutPassTurn();
      });
      _startTurnTimer();
    } else if (isMyTurn) {
      // For online match, if current turn player times out, pass turn
      _roomService.submitDiceRoll(
        roomCode: widget.roomCode!,
        playerUid: _firebaseService.currentUserId,
      ).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _onDiceRoll() {
    if (!isMyTurn || _engine.turnPhase != TurnPhase.waitingForRoll) return;

    if (!isOnline) {
      setState(() {
        _engine.rollDice();
      });
      _startTurnTimer();
      _checkLocalGameStatus();
    } else {
      _roomService.submitDiceRoll(
        roomCode: widget.roomCode!,
        playerUid: _firebaseService.currentUserId,
      ).catchError((err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString())),
        );
      });
    }
  }

  void _onTokenTapped(int tokenId) {
    if (!isMyTurn || _engine.turnPhase != TurnPhase.waitingForMove) return;

    if (!isOnline) {
      final res = _engine.moveToken(tokenId);
      _handleLocalMoveFeedback(res);
      setState(() {});
      _startTurnTimer();
      _checkLocalGameStatus();
    } else {
      _roomService.submitMove(
        roomCode: widget.roomCode!,
        playerUid: _firebaseService.currentUserId,
        tokenId: tokenId,
      ).catchError((err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString())),
        );
      });
    }
  }

  void _handleLocalMoveFeedback(MoveResult res) {
    if (res.capturedToken != null) {
      _soundManager.playCapture();
    } else {
      _soundManager.playTokenMove();
    }

    if (res.gameWon) {
      _soundManager.playVictory();
      _showGameOverModal(_engine.winner!);
    }
  }

  void _checkLocalGameStatus() {
    if (_engine.status == GameStatus.completed && _engine.winner != null) {
      _soundManager.playVictory();
      _showGameOverModal(_engine.winner!);
    }
  }

  void _showGameOverModal(PlayerColor winner) {
    final isMe = (!isOnline && winner == PlayerColor.red) || (isOnline && winner == myColor);

    GameDialogs.showVictoryDialog(
      context: context,
      winner: winner,
      isMeWinner: isMe,
      onRematch: () {
        if (!isOnline) {
          setState(() {
            _engine = LudoEngine.newGame();
          });
          _startTurnTimer();
        } else {
          _roomService.requestRematch(widget.roomCode!);
        }
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _handleLeave() async {
    final leave = await GameDialogs.showLeaveConfirmDialog(context);
    if (leave && mounted) {
      if (isOnline) {
        _roomService.leaveRoom(
          widget.roomCode!,
          _firebaseService.currentUserId,
        );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final redTokens = _engine.getTokensFor(PlayerColor.red);
    final greenTokens = _engine.getTokensFor(PlayerColor.green);
    final legalMoves = isMyTurn ? _engine.getLegalMoves() : <int>[];

    final hostPlayer = _onlineRoom?.host ??
        PlayerProfile(
          uid: 'p1',
          displayName: isOnline ? 'Host' : 'Player 1 (Red)',
          color: PlayerColor.red,
        );

    final guestPlayer = _onlineRoom?.opponent ??
        PlayerProfile(
          uid: 'p2',
          displayName: isOnline ? 'Opponent' : 'Player 2 (Green)',
          color: PlayerColor.green,
        );

    // In online mode, top card is opponent and bottom card is me
    final topPlayer = isOnline
        ? (widget.isHost ? guestPlayer : hostPlayer)
        : hostPlayer;

    final bottomPlayer = isOnline
        ? (widget.isHost ? hostPlayer : guestPlayer)
        : guestPlayer;

    final canRoll = isMyTurn &&
        _engine.turnPhase == TurnPhase.waitingForRoll &&
        _engine.status == GameStatus.inProgress;

    final lastLog = _engine.moveLog.isNotEmpty ? _engine.moveLog.last : 'Match in progress';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleLeave();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(isOnline ? 'Room: ${widget.roomCode}' : 'Pass & Play'),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded, color: AppTheme.redLight),
              tooltip: 'Leave Game',
              onPressed: _handleLeave,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Player Card (Opponent in online mode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PlayerCardWidget(
                      player: topPlayer,
                      isCurrentTurn: _engine.currentTurn == topPlayer.color,
                      finishedTokens: _engine.getFinishedCount(topPlayer.color),
                      remainingSeconds: _secondsRemaining,
                      isMe: isOnline ? topPlayer.color == myColor : false,
                    ),
                    if (isOnline)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi,
                              color: topPlayer.isConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              topPlayer.isConnected ? 'ONLINE' : 'AWAY',
                              style: TextStyle(
                                color: topPlayer.isConnected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Center Board View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LudoBoardWidget(
                    redTokens: redTokens,
                    greenTokens: greenTokens,
                    currentTurn: _engine.currentTurn,
                    legalMoveTokenIds: legalMoves,
                    isInteractive: isMyTurn,
                    onTokenTapped: _onTokenTapped,
                  ),
                ),
              ),

              // 3. Move Ticker Announcement Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined, color: AppTheme.gold, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastLog,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Controls: Dice and My Player Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PlayerCardWidget(
                      player: bottomPlayer,
                      isCurrentTurn: _engine.currentTurn == bottomPlayer.color,
                      finishedTokens: _engine.getFinishedCount(bottomPlayer.color),
                      remainingSeconds: _secondsRemaining,
                      isMe: isOnline ? bottomPlayer.color == myColor : true,
                    ),

                    // Dice Action Widget
                    DiceWidget(
                      value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                      canRoll: canRoll,
                      turnColor: _engine.currentTurn,
                      onRoll: _onDiceRoll,
                      size: 68,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
