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
import 'package:duo_ludo/ui/widgets/confetti_overlay.dart';
import 'package:duo_ludo/ui/widgets/dialogs/game_dialogs.dart';
import 'package:duo_ludo/ui/widgets/dice/dice_widget.dart';
import 'package:duo_ludo/ui/widgets/player_card_widget.dart';

/// Active game screen supporting 2-Player, 3-Player, 4-Player Local and Online Multiplayer.
class GameScreen extends StatefulWidget {
  final String? roomCode; // null = Local mode
  final bool isHost;
  final List<PlayerColor>? activePlayers;

  const GameScreen({
    super.key,
    this.roomCode,
    this.isHost = true,
    this.activePlayers,
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

  // Animation state
  bool _isMoving = false;
  LudoToken? _animatingToken;
  bool _isGameWon = false;

  bool get isOnline => widget.roomCode != null;
  PlayerColor get myColor => widget.isHost ? PlayerColor.red : PlayerColor.green;

  bool get isMyTurn {
    if (_isMoving) return false;
    if (!isOnline) return true; // Local mode: always allow turn player
    return _engine.currentTurn == myColor;
  }

  @override
  void initState() {
    super.initState();
    _engine = LudoEngine.newGame(activePlayers: widget.activePlayers);

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
          _handleTurnTimeout();
        }
      });
    });
  }

  void _handleTurnTimeout() {
    _countdownTimer?.cancel();
    if (_engine.status != GameStatus.inProgress || _isMoving) return;

    if (!isOnline) {
      setState(() {
        _engine.timeoutPassTurn();
      });
      _soundManager.playTurnAlert();
      _startTurnTimer();
    } else if (isMyTurn) {
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
    if (!isMyTurn || _engine.turnPhase != TurnPhase.waitingForRoll || _isMoving) return;

    if (!isOnline) {
      setState(() {
        _engine.rollDice();
      });
      _startTurnTimer();
      _checkGameStatus();
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

  Future<void> _onTokenTapped(int tokenId) async {
    if (!isMyTurn || _engine.turnPhase != TurnPhase.waitingForMove || _isMoving) return;

    if (!isOnline) {
      final currentToken = _engine.getToken(_engine.currentTurn, tokenId);
      final fromStep = currentToken.stepCount;
      final roll = _engine.currentDiceRoll!;
      final targetStep = fromStep == LudoConstants.stepYard ? 0 : fromStep + roll;

      final res = _engine.moveToken(tokenId);

      // Smooth step-by-step movement along individual board cells
      await _animateTokenStepByStep(
        token: currentToken,
        fromStep: fromStep,
        toStep: targetStep,
        res: res,
      );
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

  Future<void> _animateTokenStepByStep({
    required LudoToken token,
    required int fromStep,
    required int toStep,
    required MoveResult res,
  }) async {
    setState(() => _isMoving = true);
    _countdownTimer?.cancel();

    if (fromStep == LudoConstants.stepYard) {
      setState(() {
        _animatingToken = token.copyWith(stepCount: 0);
      });
      _soundManager.playTokenMove();
      await Future.delayed(const Duration(milliseconds: 200));
    } else {
      for (int step = fromStep + 1; step <= toStep; step++) {
        if (!mounted) break;
        setState(() {
          _animatingToken = token.copyWith(stepCount: step);
        });
        _soundManager.playTokenMove();
        await Future.delayed(const Duration(milliseconds: 110));
      }
    }

    if (!mounted) return;
    setState(() {
      _animatingToken = null;
      _isMoving = false;
    });

    _handlePostMoveFeedback(res);
    _startTurnTimer();
    _checkGameStatus();
  }

  void _handlePostMoveFeedback(MoveResult res) {
    if (res.capturedToken != null) {
      _soundManager.playCapture();
    } else if (res.toStep == LudoConstants.stepHomeFinished) {
      _soundManager.playTokenHome();
    }

    if (res.gameWon) {
      setState(() => _isGameWon = true);
      _soundManager.playVictory();
      _showGameOverModal(_engine.winner!);
    } else if (!res.extraTurnGranted) {
      _soundManager.playTurnAlert();
    }
  }

  void _checkGameStatus() {
    if (_engine.status == GameStatus.completed && _engine.winner != null) {
      setState(() => _isGameWon = true);
      _soundManager.playVictory();
      _showGameOverModal(_engine.winner!);
    }
  }

  void _showGameOverModal(PlayerColor winner) {
    final isMe = (!isOnline && winner == _engine.activePlayers.first) ||
        (isOnline && winner == myColor);

    GameDialogs.showVictoryDialog(
      context: context,
      winner: winner,
      isMeWinner: isMe,
      onRematch: () {
        if (!isOnline) {
          setState(() {
            _isGameWon = false;
            _engine = LudoEngine.newGame(activePlayers: widget.activePlayers);
          });
          _startTurnTimer();
        } else {
          setState(() => _isGameWon = false);
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
    final activePlayers = _engine.activePlayers;
    final legalMoves = isMyTurn ? _engine.getLegalMoves() : <int>[];

    final canRoll = isMyTurn &&
        _engine.turnPhase == TurnPhase.waitingForRoll &&
        _engine.status == GameStatus.inProgress &&
        !_isMoving;

    final lastLog = _engine.moveLog.isNotEmpty ? _engine.moveLog.last : 'Match in progress';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleLeave();
        }
      },
      child: ConfettiOverlay(
        isPlaying: _isGameWon,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(
              isOnline
                  ? 'Room: ${widget.roomCode}'
                  : '${activePlayers.length}-Player Pass & Play',
            ),
            actions: [
              // BGM Toggle button
              IconButton(
                icon: Icon(
                  _soundManager.isBgmEnabled ? Icons.music_note : Icons.music_off,
                  color: _soundManager.isBgmEnabled ? AppTheme.gold : AppTheme.textMuted,
                ),
                tooltip: 'Toggle Music',
                onPressed: () {
                  setState(() {
                    _soundManager.toggleBgm(!_soundManager.isBgmEnabled);
                  });
                },
              ),
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
                // 1. Top Player Panels Section
                _buildTopPlayerSection(),

                // 2. Center Classic Ludo Board View
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: LudoBoardWidget(
                      tokens: _engine.tokens,
                      activePlayers: activePlayers,
                      currentTurn: _engine.currentTurn,
                      legalMoveTokenIds: legalMoves,
                      isInteractive: isMyTurn && !_isMoving,
                      animatingToken: _animatingToken,
                      onTokenTapped: _onTokenTapped,
                    ),
                  ),
                ),

                // 3. Move Ticker Announcement Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _engine.currentTurn.primaryColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.campaign_outlined,
                          color: _engine.currentTurn.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastLog,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Bottom Controls: Dice and Current Turn Player Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active Turn Player Card
                      PlayerCardWidget(
                        player: PlayerProfile(
                          uid: 'current',
                          displayName: isOnline && _onlineRoom != null
                              ? (_engine.currentTurn == myColor
                                  ? (widget.isHost ? _onlineRoom!.host.displayName : _onlineRoom!.opponent?.displayName ?? 'You')
                                  : (widget.isHost ? _onlineRoom!.opponent?.displayName ?? 'Opponent' : _onlineRoom!.host.displayName))
                              : '${_engine.currentTurn.displayName} Turn',
                          color: _engine.currentTurn,
                        ),
                        isCurrentTurn: true,
                        finishedTokens: _engine.getFinishedCount(_engine.currentTurn),
                        remainingSeconds: _secondsRemaining,
                        isMe: isOnline ? _engine.currentTurn == myColor : true,
                      ),

                      // Animated 3D Dice Widget
                      DiceWidget(
                        value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                        canRoll: canRoll,
                        turnColor: _engine.currentTurn,
                        onRoll: _onDiceRoll,
                        size: 64,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPlayerSection() {
    final activePlayers = _engine.activePlayers;

    // In 2-player mode, show the opponent at the top
    if (activePlayers.length == 2) {
      final opponentColor = activePlayers.firstWhere(
        (c) => c != _engine.currentTurn,
        orElse: () => activePlayers.last,
      );

      final oppProfile = (isOnline && _onlineRoom != null)
          ? ((widget.isHost ? _onlineRoom!.opponent : _onlineRoom!.host) ??
              PlayerProfile(
                uid: 'opp',
                displayName: '${opponentColor.displayName} Team',
                color: opponentColor,
              ))
          : PlayerProfile(
              uid: 'opp',
              displayName: '${opponentColor.displayName} Team',
              color: opponentColor,
            );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PlayerCardWidget(
              player: oppProfile,
              isCurrentTurn: _engine.currentTurn == opponentColor,
              finishedTokens: _engine.getFinishedCount(opponentColor),
              remainingSeconds: _secondsRemaining,
              isMe: false,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: opponentColor.primaryColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: opponentColor.primaryColor.withOpacity(0.4)),
              ),
              child: Text(
                'OPPONENT',
                style: TextStyle(
                  color: opponentColor.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // In 3-player or 4-player mode, show horizontal list of other active players
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          for (final color in activePlayers)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PlayerCardWidget(
                player: PlayerProfile(
                  uid: color.name,
                  displayName: color.displayName,
                  color: color,
                ),
                isCurrentTurn: _engine.currentTurn == color,
                finishedTokens: _engine.getFinishedCount(color),
                remainingSeconds: _secondsRemaining,
                isMe: _engine.currentTurn == color,
              ),
            ),
        ],
      ),
    );
  }
}
