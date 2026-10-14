import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duo_ludo/engine/ludo_engine.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/widgets/board/ludo_board_widget.dart';
import 'package:duo_ludo/ui/widgets/board/board_coordinates.dart';
import 'package:duo_ludo/ui/widgets/board/token_widget.dart';

void main() {
  group('Board Coordinates & Geometry Tests', () {
    test('Verify start positions for all four player quadrants', () {
      expect(BoardCoordinates.perimeterTiles[0], const GridPoint(6, 1)); // Red start
      expect(BoardCoordinates.perimeterTiles[13], const GridPoint(1, 8)); // Green start
      expect(BoardCoordinates.perimeterTiles[26], const GridPoint(8, 13)); // Yellow start
      expect(BoardCoordinates.perimeterTiles[39], const GridPoint(13, 6)); // Blue start
    });

    test('Verify yard dock positions for all four colors (4 tokens each)', () {
      for (final color in PlayerColor.values) {
        final docks = BoardCoordinates.getYardDocks(color);
        expect(docks.length, 4);
        for (final dock in docks) {
          expect(dock.row, inInclusiveRange(0.0, 14.0));
          expect(dock.col, inInclusiveRange(0.0, 14.0));
        }
      }
    });

    test('Verify runway steps for all four colors lead towards center', () {
      for (final color in PlayerColor.values) {
        final runway = BoardCoordinates.getRunway(color);
        expect(runway.length, 5);
        for (final pt in runway) {
          expect(pt.row, inInclusiveRange(1.0, 13.0));
          expect(pt.col, inInclusiveRange(1.0, 13.0));
        }
      }
    });

    test('Verify center home positions are strictly adjacent to center (7,7)', () {
      final centers = [
        BoardCoordinates.redCenterHome,
        BoardCoordinates.greenCenterHome,
        BoardCoordinates.yellowCenterHome,
        BoardCoordinates.blueCenterHome,
      ];
      for (final homePt in centers) {
        expect((homePt.row - 7.0).abs(), lessThanOrEqualTo(1.0));
        expect((homePt.col - 7.0).abs(), lessThanOrEqualTo(1.0));
      }
    });
  });

  group('Ludo Board Widget Rendering Tests for Player Counts', () {
    testWidgets('2-Player Board renders with 8 tokens and no errors', (WidgetTester tester) async {
      final active = [PlayerColor.red, PlayerColor.yellow];
      final engine = LudoEngine.newGame(activePlayers: active);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: LudoBoardWidget(
                  tokens: engine.tokens,
                  activePlayers: active,
                  currentTurn: engine.currentTurn,
                  legalMoveTokenIds: const [],
                  isInteractive: true,
                  onTokenTapped: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CustomPaint board exists
      expect(find.byType(CustomPaint), findsWidgets);
      // 8 tokens for 2 players
      expect(find.byType(TokenWidget), findsNWidgets(8));
    });

    testWidgets('3-Player Board renders with 12 tokens and interactive callback', (WidgetTester tester) async {
      final active = [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
      ];
      final engine = LudoEngine.newGame(activePlayers: active);

      int? tappedTokenId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: LudoBoardWidget(
                  tokens: engine.tokens,
                  activePlayers: active,
                  currentTurn: engine.currentTurn,
                  legalMoveTokenIds: const [0],
                  isInteractive: true,
                  onTokenTapped: (id) => tappedTokenId = id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 12 tokens for 3 players
      expect(find.byType(TokenWidget), findsNWidgets(12));

      // Tap token 0
      final firstToken = find.byType(TokenWidget).first;
      await tester.tap(firstToken);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tappedTokenId, equals(0));
    });

    testWidgets('4-Player Board renders full 16 tokens across all four quadrants', (WidgetTester tester) async {
      final active = [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue,
      ];
      final engine = LudoEngine.newGame(activePlayers: active);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: LudoBoardWidget(
                  tokens: engine.tokens,
                  activePlayers: active,
                  currentTurn: engine.currentTurn,
                  legalMoveTokenIds: const [],
                  isInteractive: false,
                  onTokenTapped: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 16 tokens for 4 players
      expect(find.byType(TokenWidget), findsNWidgets(16));
    });
  });
}
