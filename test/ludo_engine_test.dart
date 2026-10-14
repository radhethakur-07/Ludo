import 'package:flutter_test/flutter_test.dart';
import 'package:duo_ludo/engine/ludo_constants.dart';
import 'package:duo_ludo/engine/ludo_engine.dart';
import 'package:duo_ludo/engine/ludo_models.dart';

void main() {
  group('LudoEngine Core Rules & Mechanics', () {
    late LudoEngine engine;

    setUp(() {
      engine = LudoEngine.newGame();
    });

    test('Initial game state is valid for all colors', () {
      expect(engine.currentTurn, PlayerColor.red);
      expect(engine.turnPhase, TurnPhase.waitingForRoll);
      expect(engine.status, GameStatus.inProgress);
      expect(engine.winner, isNull);
      expect(engine.consecutiveSixes, 0);

      // All 4 colors must have 4 tokens starting in Yard
      for (final color in PlayerColor.values) {
        final tokens = engine.getTokensFor(color);
        expect(tokens.length, 4);
        expect(tokens.every((t) => t.isAtYard), isTrue);
      }
    });

    test('Tokens in yard cannot move on roll 1 to 5, and turn passes', () {
      final roll = engine.rollDice(fixedRoll: 3);
      expect(roll, 3);
      // No moves available, so turn should pass automatically to Green!
      expect(engine.getLegalMoves(), isEmpty);
      expect(engine.currentTurn, PlayerColor.green);
      expect(engine.turnPhase, TurnPhase.waitingForRoll);
    });

    test('Token in yard can exit on roll 6, moving to step 0', () {
      final roll = engine.rollDice(fixedRoll: 6);
      expect(roll, 6);
      expect(engine.turnPhase, TurnPhase.waitingForMove);
      final legal = engine.getLegalMoves();
      expect(legal.length, 4); // All 4 yard tokens can exit

      final result = engine.moveToken(0);
      expect(result.toStep, LudoConstants.stepStart);
      expect(engine.getToken(PlayerColor.red, 0).stepCount, 0);
      expect(engine.getToken(PlayerColor.red, 0).trackTileIndex, LudoConstants.redStartTile);

      // Rolling 6 gives an extra turn!
      expect(result.extraTurnGranted, isTrue);
      expect(result.extraTurnReason, ExtraTurnReason.rolledSix);
      expect(engine.currentTurn, PlayerColor.red);
      expect(engine.turnPhase, TurnPhase.waitingForRoll);
    });

    test('Three consecutive sixes forfeits the turn', () {
      // First 6
      engine.rollDice(fixedRoll: 6);
      engine.moveToken(0);
      expect(engine.consecutiveSixes, 1);
      expect(engine.currentTurn, PlayerColor.red);

      // Second 6
      engine.rollDice(fixedRoll: 6);
      engine.moveToken(0);
      expect(engine.consecutiveSixes, 2);
      expect(engine.currentTurn, PlayerColor.red);

      // Third 6 -> turn forfeit penalty
      engine.rollDice(fixedRoll: 6);
      expect(engine.consecutiveSixes, 0);
      expect(engine.currentTurn, PlayerColor.green); // Switched to Green!
      expect(engine.turnPhase, TurnPhase.waitingForRoll);
    });

    test('Token moves forward on track according to dice roll', () {
      // Exit yard
      engine.rollDice(fixedRoll: 6);
      engine.moveToken(0);

      // Next roll: 4
      engine.rollDice(fixedRoll: 4);
      final result = engine.moveToken(0);
      expect(result.fromStep, 0);
      expect(result.toStep, 4);
      expect(result.extraTurnGranted, isFalse);

      // Turn passed to Green
      expect(engine.currentTurn, PlayerColor.green);
    });

    test('Safe squares protect opponent token from capture', () {
      // Set up:
      // Red token 0 at step 8 (safe star at tile 8)
      // Green token 0 at track tile 8 (from Green start 13, step 47 is track tile (13+47)%52 = 8)
      final customEngine = LudoEngine(
        activePlayers: [PlayerColor.red, PlayerColor.green],
        initialTurn: PlayerColor.green,
        initialTokens: {
          PlayerColor.red: [
            const LudoToken(id: 0, owner: PlayerColor.red, stepCount: 8), // tile 8
            const LudoToken(id: 1, owner: PlayerColor.red),
            const LudoToken(id: 2, owner: PlayerColor.red),
            const LudoToken(id: 3, owner: PlayerColor.red),
          ],
          PlayerColor.green: [
            const LudoToken(id: 0, owner: PlayerColor.green, stepCount: 43), // tile (13+43)%52 = 4
            const LudoToken(id: 1, owner: PlayerColor.green),
            const LudoToken(id: 2, owner: PlayerColor.green),
            const LudoToken(id: 3, owner: PlayerColor.green),
          ],
        },
      );

      // Green rolls 4 -> step 47 -> tile (13+47)%52 = 8
      customEngine.rollDice(fixedRoll: 4);
      final result = customEngine.moveToken(0);

      // Tile 8 is safe! No capture should occur
      expect(result.capturedToken, isNull);
      expect(customEngine.getToken(PlayerColor.red, 0).stepCount, 8); // Red stays intact!
    });

    test('Capturing an opponent sends them to yard and awards an extra turn', () {
      // Set up:
      // Red token 0 at step 5 (tile 5, not safe)
      // Green token 0 at step 40 (tile (13+40)%52 = 1, not safe)
      // Green rolls 4 -> step 44 -> tile (13+44)%52 = 5 (lands on Red!)
      final customEngine = LudoEngine(
        activePlayers: [PlayerColor.red, PlayerColor.green],
        initialTurn: PlayerColor.green,
        initialTokens: {
          PlayerColor.red: [
            const LudoToken(id: 0, owner: PlayerColor.red, stepCount: 5),
            const LudoToken(id: 1, owner: PlayerColor.red),
            const LudoToken(id: 2, owner: PlayerColor.red),
            const LudoToken(id: 3, owner: PlayerColor.red),
          ],
          PlayerColor.green: [
            const LudoToken(id: 0, owner: PlayerColor.green, stepCount: 40),
            const LudoToken(id: 1, owner: PlayerColor.green),
            const LudoToken(id: 2, owner: PlayerColor.green),
            const LudoToken(id: 3, owner: PlayerColor.green),
          ],
        },
      );

      customEngine.rollDice(fixedRoll: 4);
      final result = customEngine.moveToken(0);

      // Captured Red token 0
      expect(result.capturedToken, isNotNull);
      expect(result.capturedToken!.owner, PlayerColor.red);
      expect(result.capturedToken!.id, 0);

      // Red token returned to yard
      expect(customEngine.getToken(PlayerColor.red, 0).isAtYard, isTrue);

      // Green awarded extra turn for capture
      expect(result.extraTurnGranted, isTrue);
      expect(result.extraTurnReason, ExtraTurnReason.capturedOpponent);
      expect(customEngine.currentTurn, PlayerColor.green);
      expect(customEngine.turnPhase, TurnPhase.waitingForRoll);
    });

    test('Token cannot overshoot home triangle (exact roll rule)', () {
      // Token at step 54 (needs roll of 2 to reach 56)
      final customEngine = LudoEngine(
        initialTurn: PlayerColor.red,
        initialTokens: {
          PlayerColor.red: [
            const LudoToken(id: 0, owner: PlayerColor.red, stepCount: 54),
            const LudoToken(id: 1, owner: PlayerColor.red),
            const LudoToken(id: 2, owner: PlayerColor.red),
            const LudoToken(id: 3, owner: PlayerColor.red),
          ],
          PlayerColor.green: List.generate(
            4,
            (i) => LudoToken(id: i, owner: PlayerColor.green),
          ),
        },
      );

      // Roll 3 -> 54 + 3 = 57 > 56 -> Overshoots! Legal moves should be empty
      customEngine.rollDice(fixedRoll: 3);
      expect(customEngine.canTokenMove(customEngine.getToken(PlayerColor.red, 0), 3), isFalse);
      expect(customEngine.getLegalMoves(), isEmpty);
      // Turn automatically passed to Green
      expect(customEngine.currentTurn, PlayerColor.green);
    });

    test('Exact roll lands token in home triangle and triggers win on 4 finished tokens', () {
      final customEngine = LudoEngine(
        initialTurn: PlayerColor.red,
        initialTokens: {
          PlayerColor.red: [
            const LudoToken(id: 0, owner: PlayerColor.red, stepCount: 56), // already finished
            const LudoToken(id: 1, owner: PlayerColor.red, stepCount: 56), // already finished
            const LudoToken(id: 2, owner: PlayerColor.red, stepCount: 56), // already finished
            const LudoToken(id: 3, owner: PlayerColor.red, stepCount: 54), // needs 2
          ],
          PlayerColor.green: List.generate(
            4,
            (i) => LudoToken(id: i, owner: PlayerColor.green),
          ),
        },
      );

      customEngine.rollDice(fixedRoll: 2);
      final result = customEngine.moveToken(3);

      expect(result.toStep, 56);
      expect(result.gameWon, isTrue);
      expect(customEngine.status, GameStatus.completed);
      expect(customEngine.winner, PlayerColor.red);
      expect(customEngine.hasPlayerWon(PlayerColor.red), isTrue);
    });

    test('Four-player rotation cycles through Red -> Green -> Yellow -> Blue -> Red', () {
      final fourPlayerEngine = LudoEngine.newGame(
        activePlayers: [
          PlayerColor.red,
          PlayerColor.green,
          PlayerColor.yellow,
          PlayerColor.blue,
        ],
      );

      expect(fourPlayerEngine.currentTurn, PlayerColor.red);

      // Red rolls 2 (no moves in yard -> passes)
      fourPlayerEngine.rollDice(fixedRoll: 2);
      expect(fourPlayerEngine.currentTurn, PlayerColor.green);

      // Green rolls 3 -> passes
      fourPlayerEngine.rollDice(fixedRoll: 3);
      expect(fourPlayerEngine.currentTurn, PlayerColor.yellow);

      // Yellow rolls 4 -> passes
      fourPlayerEngine.rollDice(fixedRoll: 4);
      expect(fourPlayerEngine.currentTurn, PlayerColor.blue);

      // Blue rolls 5 -> passes back to Red
      fourPlayerEngine.rollDice(fixedRoll: 5);
      expect(fourPlayerEngine.currentTurn, PlayerColor.red);
    });

    test('Three-player rotation cycles through Red -> Green -> Yellow -> Red', () {
      final threePlayerEngine = LudoEngine.newGame(
        activePlayers: [
          PlayerColor.red,
          PlayerColor.green,
          PlayerColor.yellow,
        ],
      );

      expect(threePlayerEngine.currentTurn, PlayerColor.red);

      threePlayerEngine.rollDice(fixedRoll: 1);
      expect(threePlayerEngine.currentTurn, PlayerColor.green);

      threePlayerEngine.rollDice(fixedRoll: 2);
      expect(threePlayerEngine.currentTurn, PlayerColor.yellow);

      threePlayerEngine.rollDice(fixedRoll: 3);
      expect(threePlayerEngine.currentTurn, PlayerColor.red);
    });

    test('State serialization (toMap and fromMap) faithfully round-trips 4-player game state', () {
      engine.rollDice(fixedRoll: 6);
      engine.moveToken(0);
      engine.rollDice(fixedRoll: 5);
      engine.moveToken(0);

      final map = engine.toMap();
      final restored = LudoEngine.fromMap(map);

      expect(restored.currentTurn, engine.currentTurn);
      expect(restored.turnPhase, engine.turnPhase);
      expect(restored.currentDiceRoll, engine.currentDiceRoll);
      expect(restored.lastDiceRoll, engine.lastDiceRoll);
      expect(restored.consecutiveSixes, engine.consecutiveSixes);
      expect(restored.status, engine.status);
      expect(restored.getToken(PlayerColor.red, 0).stepCount, 5);
      expect(restored.activePlayers, engine.activePlayers);
    });
  });
}
