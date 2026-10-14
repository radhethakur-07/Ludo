import 'dart:async';
import 'package:flutter/material.dart';
import 'package:duo_ludo/audio/sound_manager.dart';
import 'package:duo_ludo/engine/ludo_constants.dart';
import 'package:duo_ludo/engine/ludo_engine.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/services/firebase_service.dart';
import 'package:duo_ludo/services/room_service.dart';
import 'package:duo_ludo/services/voice_chat_service.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';
import 'package:duo_ludo/ui/widgets/board/ludo_board_widget.dart';
import 'package:duo_ludo/ui/widgets/confetti_overlay.dart';
import 'package:duo_ludo/ui/widgets/dialogs/game_dialogs.dart';
import 'package:duo_ludo/ui/widgets/dice/dice_widget.dart';
import 'package:duo_ludo/ui/screens/settings_screen.dart';
import 'package:duo_ludo/ui/widgets/player_card_widget.dart';

/// Full interactive game screen with player-relative dice layout,
/// animated classic board, voice chat, emoji reactions, and sound effects.
class GameScreen extends StatefulWidget {
  final String? roomCode;
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
  final VoiceChatService _voiceService = VoiceChatService();

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

  // Emoji reactions state
  bool _showEmojiPicker = false;
  String? _floatingEmoji;
  PlayerColor? _floatingEmojiColor;
  Timer? _floatingEmojiTimer;
  int? _lastSeenReactionTimestamp;

  bool get isOnline => widget.roomCode != null;

  PlayerColor get myColor {
    if (!isOnline || _onlineRoom == null) {
      return widget.isHost ? PlayerColor.red : PlayerColor.green;
    }
    return widget.isHost
        ? _onlineRoom!.host.color
        : (_onlineRoom!.opponent?.color ?? PlayerColor.green);
  }

  bool get isMyTurn {
    if (_isMoving) return false;
    if (!isOnline) return true; // Local mode: always allow current player
    return _engine.currentTurn == myColor;
  }

  @override
  void initState() {
    super.initState();
    _engine = LudoEngine.newGame(activePlayers: widget.activePlayers);

    if (isOnline) {
      _listenToRoom();
      _voiceService.joinVoiceChannel(
        roomCode: widget.roomCode!,
        playerUid: _firebaseService.currentUserId,
      );
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

      // Check reactions
      if (room.latestReaction != null &&
          room.latestReaction!.timestamp != _lastSeenReactionTimestamp) {
        _lastSeenReactionTimestamp = room.latestReaction!.timestamp;
        _triggerFloatingEmoji(
          room.latestReaction!.emoji,
          room.latestReaction!.senderColor,
        );
      }

      // Check win dialog
      if (_engine.status == GameStatus.completed && _engine.winner != null) {
        _showGameOverModal(_engine.winner!);
      }
    });
  }

  void _triggerFloatingEmoji(String emoji, PlayerColor color) {
    _floatingEmojiTimer?.cancel();
    setState(() {
      _floatingEmoji = emoji;
      _floatingEmojiColor = color;
    });
    _floatingEmojiTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _floatingEmoji = null;
          _floatingEmojiColor = null;
        });
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
    _floatingEmojiTimer?.cancel();
    if (isOnline) {
      _voiceService.leaveVoiceChannel();
    }
    super.dispose();
  }

  void _onDiceRoll() {
    if (!isMyTurn ||
        _engine.turnPhase != TurnPhase.waitingForRoll ||
        _isMoving) {
      return;
    }

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
    if (!isMyTurn ||
        _engine.turnPhase != TurnPhase.waitingForMove ||
        _isMoving) {
      return;
    }

    if (!isOnline) {
      final currentToken = _engine.getToken(_engine.currentTurn, tokenId);
      final fromStep = currentToken.stepCount;
      final roll = _engine.currentDiceRoll!;
      final targetStep =
          fromStep == LudoConstants.stepYard ? 0 : fromStep + roll;

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

  void _handleVoiceChatPressed() {
    if (!_voiceService.isVoiceConfigured) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mic, color: AppTheme.gold),
              SizedBox(width: 8),
              Text('Live Voice Chat',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Online real-time voice chat uses Agora RTC (10,000 free minutes/month).',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13.5),
              ),
              SizedBox(height: 12),
              Text(
                'To enable live voice transmission:\n'
                '1. Create a free project at agora.io\n'
                '2. Pass --dart-define=AGORA_APP_ID=YOUR_APP_ID on build\n\n'
                'Microphone permissions are requested on first unmute.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Open Settings',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text('Dismiss', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      );
      return;
    }
    _voiceService.toggleMute();
  }

  Future<void> _sendEmojiReaction(String emoji) async {
    setState(() => _showEmojiPicker = false);
    _soundManager.playDiceLand();
    _triggerFloatingEmoji(emoji, myColor);

    if (isOnline) {
      await _roomService.sendReaction(
        roomCode: widget.roomCode!,
        playerUid: _firebaseService.currentUserId,
        playerName: widget.isHost
            ? (_onlineRoom?.host.displayName ?? 'Host')
            : (_onlineRoom?.opponent?.displayName ?? 'Opponent'),
        playerColor: myColor,
        emoji: emoji,
      );
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

    final lastLog =
        _engine.moveLog.isNotEmpty ? _engine.moveLog.last : 'Match in progress';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleLeave();
        }
      },
      child: ConfettiOverlay(
        isPlaying: _isGameWon,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                isOnline
                    ? 'Room: ${widget.roomCode}'
                    : '${activePlayers.length}-Player Match',
              ),
              actions: [
                // Live Voice Chat toggle
                IconButton(
                  icon: StreamBuilder<VoiceChatState>(
                    stream: _voiceService.stateStream,
                    initialData: _voiceService.state,
                    builder: (context, snapshot) {
                      final state =
                          snapshot.data ?? VoiceChatState.disconnected;
                      if (state == VoiceChatState.connected &&
                          !_voiceService.isMuted) {
                        return const Icon(Icons.mic, color: Color(0xFF10B981));
                      } else if (state == VoiceChatState.unconfigured) {
                        return const Icon(Icons.mic_none,
                            color: AppTheme.textMuted);
                      } else {
                        return const Icon(Icons.mic_off,
                            color: Color(0xFFEF4444));
                      }
                    },
                  ),
                  tooltip: 'Voice Chat',
                  onPressed: _handleVoiceChatPressed,
                ),

                // Emoji Reaction bar toggle
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: AppTheme.gold),
                  tooltip: 'Emoji Reactions',
                  onPressed: () =>
                      setState(() => _showEmojiPicker = !_showEmojiPicker),
                ),

                // BGM Toggle button
                IconButton(
                  icon: Icon(
                    _soundManager.isBgmEnabled
                        ? Icons.music_note
                        : Icons.music_off,
                    color: _soundManager.isBgmEnabled
                        ? AppTheme.gold
                        : AppTheme.textMuted,
                  ),
                  tooltip: 'Toggle Music',
                  onPressed: () {
                    setState(() {
                      _soundManager.toggleBgm(!_soundManager.isBgmEnabled);
                    });
                  },
                ),

                // Exit Game
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded,
                      color: AppTheme.redLight),
                  tooltip: 'Leave Game',
                  onPressed: _handleLeave,
                ),
              ],
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // 1. Top Player Area with Player-Relative Dice
                      _buildTopPlayerRelativeSection(canRoll),

                      // 2. Center Classic Ludo Board
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                      ),

                      // 3. Move Ticker Announcement Bar
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _engine.currentTurn.primaryColor
                                .withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.campaign_outlined,
                                color: _engine.currentTurn.primaryColor,
                                size: 16),
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

                      // 4. Bottom Player Area with Player-Relative Dice
                      _buildBottomPlayerRelativeSection(canRoll),
                    ],
                  ),

                  // Floating Emoji Reaction Animation
                  if (_floatingEmoji != null) _buildFloatingEmojiBanner(),

                  // Emoji Quick Reactions Drawer
                  if (_showEmojiPicker) _buildEmojiPickerDrawer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top Player Row: Renders top player card and the active dice when it's the top player's turn!
  Widget _buildTopPlayerRelativeSection(bool canRoll) {
    final activePlayers = _engine.activePlayers;

    if (activePlayers.length == 2) {
      final topColor = activePlayers.firstWhere(
        (c) => isOnline ? c != myColor : c != activePlayers.first,
        orElse: () => activePlayers.last,
      );

      final topProfile = (isOnline && _onlineRoom != null)
          ? ((topColor == _onlineRoom!.host.color
                  ? _onlineRoom!.host
                  : _onlineRoom!.opponent) ??
              PlayerProfile(
                uid: 'top',
                displayName: '${topColor.displayName} Team',
                color: topColor,
              ))
          : PlayerProfile(
              uid: 'top',
              displayName: '${topColor.displayName} Team',
              color: topColor,
            );

      final isTopTurn = _engine.currentTurn == topColor;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Player Card
            PlayerCardWidget(
              player: topProfile,
              isCurrentTurn: isTopTurn,
              finishedTokens: _engine.getFinishedCount(topColor),
              remainingSeconds: _secondsRemaining,
              isMe: isOnline ? myColor == topColor : false,
            ),

            // Player-Relative Dice: When it is the top player's turn, dice appears right here!
            if (isTopTurn)
              DiceWidget(
                value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                canRoll: canRoll && (isOnline ? isMyTurn : true),
                turnColor: topColor,
                onRoll: _onDiceRoll,
                size: 58,
              )
            else
              _buildInactiveDiceSlot(topColor, _engine.lastDiceRoll),
          ],
        ),
      );
    }

    // In 3-player or 4-player games: Top Row shows Player 1 & Player 2
    final topPlayers = activePlayers.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final color in topPlayers) ...[
            PlayerCardWidget(
              player: PlayerProfile(
                uid: color.name,
                displayName: color.displayName,
                color: color,
              ),
              isCurrentTurn: _engine.currentTurn == color,
              finishedTokens: _engine.getFinishedCount(color),
              remainingSeconds: _secondsRemaining,
              isMe: isOnline ? myColor == color : _engine.currentTurn == color,
            ),
            if (_engine.currentTurn == color)
              DiceWidget(
                value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                canRoll: canRoll && (isOnline ? isMyTurn : true),
                turnColor: color,
                onRoll: _onDiceRoll,
                size: 54,
              ),
          ],
        ],
      ),
    );
  }

  /// Bottom Player Row: Renders bottom player card and the active dice when it's the bottom player's turn!
  Widget _buildBottomPlayerRelativeSection(bool canRoll) {
    final activePlayers = _engine.activePlayers;

    if (activePlayers.length == 2) {
      final bottomColor = isOnline ? myColor : activePlayers.first;

      final bottomProfile = (isOnline && _onlineRoom != null)
          ? ((bottomColor == _onlineRoom!.host.color
                  ? _onlineRoom!.host
                  : _onlineRoom!.opponent) ??
              PlayerProfile(
                uid: 'bottom',
                displayName: '${bottomColor.displayName} Team',
                color: bottomColor,
              ))
          : PlayerProfile(
              uid: 'bottom',
              displayName: '${bottomColor.displayName} Team',
              color: bottomColor,
            );

      final isBottomTurn = _engine.currentTurn == bottomColor;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bottom Player Card
            PlayerCardWidget(
              player: bottomProfile,
              isCurrentTurn: isBottomTurn,
              finishedTokens: _engine.getFinishedCount(bottomColor),
              remainingSeconds: _secondsRemaining,
              isMe: isOnline ? myColor == bottomColor : true,
            ),

            // Player-Relative Dice: When it is bottom player's turn, dice appears right here!
            if (isBottomTurn)
              DiceWidget(
                value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                canRoll: canRoll && (isOnline ? isMyTurn : true),
                turnColor: bottomColor,
                onRoll: _onDiceRoll,
                size: 58,
              )
            else
              _buildInactiveDiceSlot(bottomColor, _engine.lastDiceRoll),
          ],
        ),
      );
    }

    // In 3-player or 4-player games: Bottom Row shows remaining players
    final bottomPlayers = activePlayers.skip(2).toList();
    if (bottomPlayers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final color in bottomPlayers) ...[
            PlayerCardWidget(
              player: PlayerProfile(
                uid: color.name,
                displayName: color.displayName,
                color: color,
              ),
              isCurrentTurn: _engine.currentTurn == color,
              finishedTokens: _engine.getFinishedCount(color),
              remainingSeconds: _secondsRemaining,
              isMe: isOnline ? myColor == color : _engine.currentTurn == color,
            ),
            if (_engine.currentTurn == color)
              DiceWidget(
                value: _engine.currentDiceRoll ?? _engine.lastDiceRoll,
                canRoll: canRoll && (isOnline ? isMyTurn : true),
                turnColor: color,
                onRoll: _onDiceRoll,
                size: 54,
              ),
          ],
        ],
      ),
    );
  }

  /// Inactive dice preview showing the last rolled number or placeholder
  Widget _buildInactiveDiceSlot(PlayerColor color, int? lastValue) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.primaryColor.withOpacity(0.2), width: 1.2),
      ),
      child: Center(
        child: Text(
          lastValue != null ? '$lastValue' : '🎲',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Floating emoji reaction animation overlay
  Widget _buildFloatingEmojiBanner() {
    if (_floatingEmoji == null) return const SizedBox.shrink();

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (_floatingEmojiColor?.primaryColor ?? AppTheme.gold)
                        .withOpacity(0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _floatingEmoji!,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Compact Emoji Reaction drawer
  Widget _buildEmojiPickerDrawer() {
    const emojis = ['😂', '👏', '🎉', '😮', '❤️', '🔥', '👑', '🎲'];

    return Positioned(
      top: 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.gold.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () => _sendEmojiReaction(emoji),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
