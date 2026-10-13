import 'dart:math';
import 'ludo_constants.dart';
import 'ludo_models.dart';

/// Pure Dart Ludo game engine with zero Flutter UI dependencies.
/// Provides deterministic rule validation, move execution, captures, and state serialization.
class LudoEngine {
  final Random _random;

  PlayerColor currentTurn;
  TurnPhase turnPhase;
  int? currentDiceRoll;
  int? lastDiceRoll;
  int consecutiveSixes;
  GameStatus status;
  PlayerColor? winner;

  // 4 tokens per player
  final Map<PlayerColor, List<LudoToken>> tokens;

  // History / log of moves
  final List<String> moveLog;

  LudoEngine({
    Random? random,
    PlayerColor initialTurn = PlayerColor.red,
    GameStatus initialStatus = GameStatus.inProgress,
    Map<PlayerColor, List<LudoToken>>? initialTokens,
    this.currentDiceRoll,
    this.lastDiceRoll,
    this.consecutiveSixes = 0,
    this.turnPhase = TurnPhase.waitingForRoll,
    this.status = GameStatus.inProgress,
    this.winner,
    List<String>? initialLog,
  })  : _random = random ?? Random(),
        currentTurn = initialTurn,
        tokens = initialTokens ?? {
          PlayerColor.red: List.generate(
            LudoConstants.tokensPerPlayer,
            (i) => LudoToken(id: i, owner: PlayerColor.red),
          ),
          PlayerColor.green: List.generate(
            LudoConstants.tokensPerPlayer,
            (i) => LudoToken(id: i, owner: PlayerColor.green),
          ),
        },
        moveLog = initialLog ?? [] {
    status = initialStatus;
  }

  /// Create a fresh new game instance.
  factory LudoEngine.newGame({Random? random}) {
    return LudoEngine(
      random: random,
      initialTurn: PlayerColor.red,
      initialStatus: GameStatus.inProgress,
      turnPhase: TurnPhase.waitingForRoll,
    );
  }

  /// Get tokens for a given player color.
  List<LudoToken> getTokensFor(PlayerColor color) =>
      List.unmodifiable(tokens[color]!);

  /// Get a specific token by player and id.
  LudoToken getToken(PlayerColor color, int tokenId) => tokens[color]![tokenId];

  /// Total tokens finished for a player.
  int getFinishedCount(PlayerColor color) =>
      tokens[color]!.where((t) => t.isFinished).length;

  /// Check if a specific player has won the game.
  bool hasPlayerWon(PlayerColor color) =>
      getFinishedCount(color) == LudoConstants.tokensPerPlayer;

  /// Returns list of legal token IDs that the current player can move for the current roll.
  List<int> getLegalMoves([int? diceRoll]) {
    final roll = diceRoll ?? currentDiceRoll;
    if (roll == null || status != GameStatus.inProgress) return [];

    final playerTokens = tokens[currentTurn]!;
    final List<int> legalTokenIds = [];

    for (final token in playerTokens) {
      if (canTokenMove(token, roll)) {
        legalTokenIds.add(token.id);
      }
    }

    return legalTokenIds;
  }

  /// Determines if a specific token can legally move given a dice roll.
  bool canTokenMove(LudoToken token, int roll) {
    if (token.owner != currentTurn) return false;
    if (token.isFinished) return false;

    if (token.isAtYard) {
      // Must roll a 6 to leave the yard
      return roll == 6;
    }

    final targetStep = token.stepCount + roll;
    // Cannot overshoot the home triangle (must be exact roll to enter or reach 56)
    return targetStep <= LudoConstants.stepHomeFinished;
  }

  /// Rolls the dice. Optionally pass [fixedRoll] for testing or backend validation.
  /// Returns the rolled value (1..6).
  int rollDice({int? fixedRoll}) {
    if (status != GameStatus.inProgress) {
      throw StateError('Cannot roll dice when game is not in progress.');
    }
    if (turnPhase != TurnPhase.waitingForRoll) {
      throw StateError('Cannot roll dice in current phase: $turnPhase');
    }

    final roll = fixedRoll ?? (_random.nextInt(6) + 1);
    currentDiceRoll = roll;
    lastDiceRoll = roll;

    if (roll == 6) {
      consecutiveSixes++;
    } else {
      consecutiveSixes = 0;
    }

    // Rule of Three Sixes: 3 consecutive 6s forfeit the turn
    if (consecutiveSixes >= LudoConstants.maxConsecutiveSixes) {
      moveLog.add(
        '${currentTurn.displayName} rolled three consecutive 6s! Turn forfeited.',
      );
      consecutiveSixes = 0;
      currentDiceRoll = null;
      _passTurn();
      return roll;
    }

    final legalMoves = getLegalMoves(roll);
    moveLog.add(
      '${currentTurn.displayName} rolled a $roll. (${legalMoves.length} legal moves)',
    );

    if (legalMoves.isEmpty) {
      // No valid moves possible, immediately pass turn
      _passTurn();
    } else {
      turnPhase = TurnPhase.waitingForMove;
    }

    return roll;
  }

  /// Executes a move for the specified [tokenId].
  /// Returns [MoveResult] containing details of the move, captures, and extra turns.
  MoveResult moveToken(int tokenId) {
    if (status != GameStatus.inProgress) {
      throw StateError('Game is not in progress.');
    }
    if (turnPhase != TurnPhase.waitingForMove) {
      throw StateError('Not in waitingForMove phase.');
    }
    if (currentDiceRoll == null) {
      throw StateError('No active dice roll.');
    }

    final token = tokens[currentTurn]![tokenId];
    if (!canTokenMove(token, currentDiceRoll!)) {
      throw ArgumentError(
        'Token $tokenId cannot legally move with roll $currentDiceRoll',
      );
    }

    final fromStep = token.stepCount;
    final int toStep;
    if (token.isAtYard) {
      toStep = LudoConstants.stepStart; // Enters track at step 0
    } else {
      toStep = token.stepCount + currentDiceRoll!;
    }

    // Update the moving token
    final updatedToken = token.copyWith(stepCount: toStep);
    tokens[currentTurn]![tokenId] = updatedToken;

    // Check for capture
    LudoToken? capturedToken;
    if (updatedToken.isOnTrack) {
      final targetTile = updatedToken.trackTileIndex!;
      // Safe tiles cannot have captures
      if (!LudoConstants.safeTiles.contains(targetTile)) {
        final opponent = currentTurn.opposite;
        for (int i = 0; i < tokens[opponent]!.length; i++) {
          final oppToken = tokens[opponent]![i];
          if (oppToken.isOnTrack && oppToken.trackTileIndex == targetTile) {
            // Captured! Send opponent token back to yard
            capturedToken = oppToken;
            tokens[opponent]![i] = oppToken.copyWith(
              stepCount: LudoConstants.stepYard,
            );
            moveLog.add(
              '${currentTurn.displayName} CAPTURED ${opponent.displayName} token #${oppToken.id} at tile $targetTile!',
            );
            break;
          }
        }
      }
    }

    // Check for win
    final gameWon = hasPlayerWon(currentTurn);
    if (gameWon) {
      status = GameStatus.completed;
      winner = currentTurn;
      turnPhase = TurnPhase.turnFinished;
      moveLog.add('🏆 ${currentTurn.displayName} has WON the game!');
      return MoveResult(
        movedToken: updatedToken,
        fromStep: fromStep,
        toStep: toStep,
        capturedToken: capturedToken,
        extraTurnGranted: false,
        extraTurnReason: ExtraTurnReason.none,
        gameWon: true,
      );
    }

    // Determine extra turn:
    // 1. Captured an opponent's token
    // 2. Rolled a 6 (and consecutiveSixes < 3)
    bool extraTurnGranted = false;
    ExtraTurnReason reason = ExtraTurnReason.none;

    if (capturedToken != null) {
      extraTurnGranted = true;
      reason = ExtraTurnReason.capturedOpponent;
      moveLog.add('${currentTurn.displayName} earned a bonus roll for capturing!');
    } else if (currentDiceRoll == 6 &&
        consecutiveSixes < LudoConstants.maxConsecutiveSixes) {
      extraTurnGranted = true;
      reason = ExtraTurnReason.rolledSix;
      moveLog.add('${currentTurn.displayName} earned an extra roll for rolling 6!');
    }

    currentDiceRoll = null;

    if (extraTurnGranted) {
      turnPhase = TurnPhase.waitingForRoll;
      // currentTurn remains the same
    } else {
      _passTurn();
    }

    return MoveResult(
      movedToken: updatedToken,
      fromStep: fromStep,
      toStep: toStep,
      capturedToken: capturedToken,
      extraTurnGranted: extraTurnGranted,
      extraTurnReason: reason,
      gameWon: false,
    );
  }

  /// Switch turn to opposite player and reset roll state.
  void _passTurn() {
    consecutiveSixes = 0;
    currentDiceRoll = null;
    currentTurn = currentTurn.opposite;
    turnPhase = TurnPhase.waitingForRoll;
  }

  /// Forfeit current turn (e.g. on player disconnect or turn timeout).
  void timeoutPassTurn() {
    if (status != GameStatus.inProgress) return;
    moveLog.add('${currentTurn.displayName} turn timed out.');
    _passTurn();
  }

  /// Convert engine state to Firestore-compatible Map.
  Map<String, dynamic> toMap() {
    return {
      'currentTurn': currentTurn.name,
      'turnPhase': turnPhase.name,
      'currentDiceRoll': currentDiceRoll,
      'lastDiceRoll': lastDiceRoll,
      'consecutiveSixes': consecutiveSixes,
      'status': status.name,
      'winner': winner?.name,
      'redTokens': tokens[PlayerColor.red]!.map((t) => t.toMap()).toList(),
      'greenTokens': tokens[PlayerColor.green]!.map((t) => t.toMap()).toList(),
      'moveLog': moveLog.take(30).toList(), // keep recent log
    };
  }

  /// Restore engine state from Firestore Map.
  factory LudoEngine.fromMap(Map<String, dynamic> map, {Random? random}) {
    final currentTurn = PlayerColor.values.firstWhere(
      (c) => c.name == map['currentTurn'],
      orElse: () => PlayerColor.red,
    );
    final turnPhase = TurnPhase.values.firstWhere(
      (p) => p.name == map['turnPhase'],
      orElse: () => TurnPhase.waitingForRoll,
    );
    final status = GameStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => GameStatus.inProgress,
    );
    final winnerStr = map['winner'] as String?;
    final winner = winnerStr != null
        ? PlayerColor.values.firstWhere((c) => c.name == winnerStr)
        : null;

    final redList = (map['redTokens'] as List<dynamic>?)
            ?.map((e) => LudoToken.fromMap(e as Map<String, dynamic>))
            .toList() ??
        List.generate(4, (i) => LudoToken(id: i, owner: PlayerColor.red));

    final greenList = (map['greenTokens'] as List<dynamic>?)
            ?.map((e) => LudoToken.fromMap(e as Map<String, dynamic>))
            .toList() ??
        List.generate(4, (i) => LudoToken(id: i, owner: PlayerColor.green));

    final logs = (map['moveLog'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return LudoEngine(
      random: random,
      initialTurn: currentTurn,
      initialStatus: status,
      initialTokens: {
        PlayerColor.red: redList,
        PlayerColor.green: greenList,
      },
      currentDiceRoll: map['currentDiceRoll'] as int?,
      lastDiceRoll: map['lastDiceRoll'] as int?,
      consecutiveSixes: map['consecutiveSixes'] as int? ?? 0,
      turnPhase: turnPhase,
      winner: winner,
      initialLog: logs,
    );
  }
}
