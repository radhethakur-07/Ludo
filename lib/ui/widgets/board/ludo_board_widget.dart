import 'dart:math';
import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'board_coordinates.dart';
import 'token_widget.dart';

/// Reusable, responsive Ludo board widget closely matching the classic international board
/// in the reference image. Supports 2-player, 3-player, and 4-player modes without black regions.
class LudoBoardWidget extends StatelessWidget {
  final Map<PlayerColor, List<LudoToken>> tokens;
  final List<PlayerColor> activePlayers;
  final PlayerColor currentTurn;
  final List<int> legalMoveTokenIds;
  final Function(int tokenId)? onTokenTapped;
  final bool isInteractive;
  final LudoToken? animatingToken; // currently stepping token

  const LudoBoardWidget({
    super.key,
    required this.tokens,
    required this.activePlayers,
    required this.currentTurn,
    required this.legalMoveTokenIds,
    this.onTokenTapped,
    this.isInteractive = true,
    this.animatingToken,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Perfectly square board constrained to available screen area
        final boardSize = min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = boardSize / BoardCoordinates.gridSize;
        final tokenSize = cellSize * 0.92;

        // Collect all tokens for active players
        final List<LudoToken> activeTokens = [];
        for (final color in activePlayers) {
          final colorTokens = tokens[color];
          if (colorTokens != null) {
            activeTokens.addAll(colorTokens);
          }
        }

        // Group tokens by their grid coordinate to calculate stacking offsets
        final Map<String, List<LudoToken>> tokensByCell = {};
        for (final t in activeTokens) {
          final effectiveToken = (animatingToken != null &&
                  animatingToken!.owner == t.owner &&
                  animatingToken!.id == t.id)
              ? animatingToken!
              : t;

          final pt = BoardCoordinates.getTokenGridPoint(effectiveToken);
          final key = '${pt.row.toStringAsFixed(1)}_${pt.col.toStringAsFixed(1)}';
          tokensByCell.putIfAbsent(key, () => []).add(effectiveToken);
        }

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: currentTurn.primaryColor.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(
                color: currentTurn.primaryColor.withOpacity(0.6),
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 1. Classic Ludo Canvas (Yards, white tracks, colored runways, arrows, stars)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ClassicLudoBoardPainter(
                        cellSize: cellSize,
                        activePlayers: activePlayers,
                      ),
                    ),
                  ),

                  // 2. Separate Interactive Game Pieces (Tokens)
                  for (final token in activeTokens)
                    _buildPositionedToken(
                      token: (animatingToken != null &&
                              animatingToken!.owner == token.owner &&
                              animatingToken!.id == token.id)
                          ? animatingToken!
                          : token,
                      cellSize: cellSize,
                      tokenSize: tokenSize,
                      tokensInSameCell: tokensByCell[
                              '${BoardCoordinates.getTokenGridPoint(token).row.toStringAsFixed(1)}_${BoardCoordinates.getTokenGridPoint(token).col.toStringAsFixed(1)}'] ??
                          [token],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionedToken({
    required LudoToken token,
    required double cellSize,
    required double tokenSize,
    required List<LudoToken> tokensInSameCell,
  }) {
    final pt = BoardCoordinates.getTokenGridPoint(token);
    final isCurrentTurnToken = token.owner == currentTurn;
    final isLegal = isInteractive &&
        isCurrentTurnToken &&
        legalMoveTokenIds.contains(token.id);
    final isMoving = animatingToken != null &&
        animatingToken!.owner == token.owner &&
        animatingToken!.id == token.id;

    // Distribute overlapping tokens in the same cell
    double dxOffset = 0;
    double dyOffset = 0;
    final count = tokensInSameCell.length;
    if (count > 1) {
      final indexInCell = tokensInSameCell.indexOf(token);
      final angle = (indexInCell * (2 * pi / count));
      final spread = cellSize * 0.22;
      dxOffset = cos(angle) * spread;
      dyOffset = sin(angle) * spread;
    }

    final targetOffset = pt.toOffset(cellSize);
    final left = targetOffset.dx - (tokenSize / 2) + dxOffset;
    final top = targetOffset.dy - (tokenSize / 2) + dyOffset;

    return AnimatedPositioned(
      duration: isMoving ? const Duration(milliseconds: 100) : const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      left: left,
      top: top,
      child: TokenWidget(
        token: token,
        size: count > 2 ? tokenSize * 0.78 : tokenSize,
        isInteractive: isLegal,
        isMoving: isMoving,
        onTap: () {
          if (isLegal && onTokenTapped != null) {
            onTokenTapped!(token.id);
          }
        },
      ),
    );
  }
}

/// Custom painter rendering the authentic classic Ludo board matching the reference image.
class _ClassicLudoBoardPainter extends CustomPainter {
  final double cellSize;
  final List<PlayerColor> activePlayers;

  _ClassicLudoBoardPainter({
    required this.cellSize,
    required this.activePlayers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBackground(canvas, size);
    _drawHomeQuadrants(canvas, size);
    _drawMovementTrack(canvas, size);
    _drawHomeRunways(canvas, size);
    _drawCenterTriangles(canvas, size);
    _drawStartArrows(canvas, size);
    _drawSafeStars(canvas, size);
  }

  void _drawBoardBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  /// Draw all 4 colored Home Quadrants (Red, Green, Yellow, Blue).
  /// Every quadrant is ALWAYS drawn correctly—never leaving black areas.
  void _drawHomeQuadrants(Canvas canvas, Size size) {
    final yardSize = cellSize * 6;

    // Top-Left: RED
    _drawQuadrant(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, yardSize, yardSize),
      color: PlayerColor.red,
      docks: BoardCoordinates.redYardDocks,
    );

    // Top-Right: GREEN
    _drawQuadrant(
      canvas: canvas,
      rect: Rect.fromLTWH(cellSize * 9, 0, yardSize, yardSize),
      color: PlayerColor.green,
      docks: BoardCoordinates.greenYardDocks,
    );

    // Bottom-Right: YELLOW
    _drawQuadrant(
      canvas: canvas,
      rect: Rect.fromLTWH(cellSize * 9, cellSize * 9, yardSize, yardSize),
      color: PlayerColor.yellow,
      docks: BoardCoordinates.yellowYardDocks,
    );

    // Bottom-Left: BLUE
    _drawQuadrant(
      canvas: canvas,
      rect: Rect.fromLTWH(0, cellSize * 9, yardSize, yardSize),
      color: PlayerColor.blue,
      docks: BoardCoordinates.blueYardDocks,
    );
  }

  void _drawQuadrant({
    required Canvas canvas,
    required Rect rect,
    required PlayerColor color,
    required List<GridPoint> docks,
  }) {
    final isActive = activePlayers.contains(color);

    // 1. Outer Solid Colored Border Area
    final quadrantPaint = Paint()
      ..color = isActive ? color.primaryColor : color.primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, quadrantPaint);

    // Subtle outer border line
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    // 2. Inner White Square Container (4x4 cells area)
    final innerMargin = cellSize * 1.0;
    final innerRect = rect.deflate(innerMargin);
    final innerWhitePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(8)),
      innerWhitePaint,
    );

    // Inner White Container Border
    final innerBorder = Paint()
      ..color = color.primaryColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(8)),
      innerBorder,
    );

    // 3. Four Circular Token Dock Sockets
    final dockOuter = Paint()
      ..color = color.darkColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final dockFill = Paint()..color = color.primaryColor.withOpacity(0.18);

    for (final dock in docks) {
      final center = dock.toOffset(cellSize);
      final radius = cellSize * 0.68;
      canvas.drawCircle(center, radius, dockFill);
      canvas.drawCircle(center, radius, dockOuter);

      // Inner colored ring center
      final innerRing = Paint()
        ..color = color.primaryColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.45, innerRing);
    }
  }

  /// Draw the 52 white movement path cells with crisp grid borders.
  void _drawMovementTrack(Canvas canvas, Size size) {
    final cellBorderPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final whiteCellPaint = Paint()..color = Colors.white;

    for (int i = 0; i < BoardCoordinates.perimeterTiles.length; i++) {
      final pt = BoardCoordinates.perimeterTiles[i];
      final rect = Rect.fromLTWH(
        pt.col * cellSize,
        pt.row * cellSize,
        cellSize,
        cellSize,
      );

      // Starting squares are highlighted with player's color
      if (i == 0) {
        // Red start (6, 1)
        canvas.drawRect(rect, Paint()..color = PlayerColor.red.primaryColor);
      } else if (i == 13) {
        // Green start (1, 8)
        canvas.drawRect(rect, Paint()..color = PlayerColor.green.primaryColor);
      } else if (i == 26) {
        // Yellow start (8, 13)
        canvas.drawRect(rect, Paint()..color = PlayerColor.yellow.primaryColor);
      } else if (i == 39) {
        // Blue start (13, 6)
        canvas.drawRect(rect, Paint()..color = PlayerColor.blue.primaryColor);
      } else {
        canvas.drawRect(rect, whiteCellPaint);
      }

      // Thin crisp cell border
      canvas.drawRect(rect, cellBorderPaint);
    }
  }

  /// Draw the 4 colored home runways (5 colored cells leading to center).
  void _drawHomeRunways(Canvas canvas, Size size) {
    final cellBorderPaint = Paint()
      ..color = const Color(0xFF757575)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Red Runway (Row 7, Cols 1..5)
    final redPaint = Paint()..color = PlayerColor.red.primaryColor;
    for (final pt in BoardCoordinates.redRunway) {
      final rect = Rect.fromLTWH(pt.col * cellSize, pt.row * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, redPaint);
      canvas.drawRect(rect, cellBorderPaint);
    }

    // Green Runway (Col 7, Rows 1..5)
    final greenPaint = Paint()..color = PlayerColor.green.primaryColor;
    for (final pt in BoardCoordinates.greenRunway) {
      final rect = Rect.fromLTWH(pt.col * cellSize, pt.row * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, greenPaint);
      canvas.drawRect(rect, cellBorderPaint);
    }

    // Yellow Runway (Row 7, Cols 9..13)
    final yellowPaint = Paint()..color = PlayerColor.yellow.primaryColor;
    for (final pt in BoardCoordinates.yellowRunway) {
      final rect = Rect.fromLTWH(pt.col * cellSize, pt.row * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, yellowPaint);
      canvas.drawRect(rect, cellBorderPaint);
    }

    // Blue Runway (Col 7, Rows 9..13)
    final bluePaint = Paint()..color = PlayerColor.blue.primaryColor;
    for (final pt in BoardCoordinates.blueRunway) {
      final rect = Rect.fromLTWH(pt.col * cellSize, pt.row * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, bluePaint);
      canvas.drawRect(rect, cellBorderPaint);
    }
  }

  /// Draw the central 4-color triangle (meeting point for all 4 colors).
  void _drawCenterTriangles(Canvas canvas, Size size) {
    final center = Offset(cellSize * 7.5, cellSize * 7.5);
    final borderPaint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Left Triangle: RED
    final redPath = Path()
      ..moveTo(cellSize * 6, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 6, cellSize * 9)
      ..close();
    canvas.drawPath(redPath, Paint()..color = PlayerColor.red.primaryColor);
    canvas.drawPath(redPath, borderPaint);

    // Top Triangle: GREEN
    final greenPath = Path()
      ..moveTo(cellSize * 6, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 6)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = PlayerColor.green.primaryColor);
    canvas.drawPath(greenPath, borderPaint);

    // Right Triangle: YELLOW
    final yellowPath = Path()
      ..moveTo(cellSize * 9, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 9)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = PlayerColor.yellow.primaryColor);
    canvas.drawPath(yellowPath, borderPaint);

    // Bottom Triangle: BLUE
    final bluePath = Path()
      ..moveTo(cellSize * 6, cellSize * 9)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 9)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = PlayerColor.blue.primaryColor);
    canvas.drawPath(bluePath, borderPaint);
  }

  /// Draw the 4 starting arrows pointing into each player's starting cell.
  void _drawStartArrows(Canvas canvas, Size size) {
    _drawArrow(canvas, PlayerColor.red, BoardCoordinates.getStartArrowPosition(PlayerColor.red), 0); // pointing right
    _drawArrow(canvas, PlayerColor.green, BoardCoordinates.getStartArrowPosition(PlayerColor.green), pi / 2); // pointing down
    _drawArrow(canvas, PlayerColor.yellow, BoardCoordinates.getStartArrowPosition(PlayerColor.yellow), pi); // pointing left
    _drawArrow(canvas, PlayerColor.blue, BoardCoordinates.getStartArrowPosition(PlayerColor.blue), -pi / 2); // pointing up
  }

  void _drawArrow(Canvas canvas, PlayerColor color, GridPoint pt, double rotationAngle) {
    final center = pt.toOffset(cellSize);
    final arrowPaint = Paint()
      ..color = color.primaryColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final path = Path();
    final s = cellSize * 0.32;
    path.moveTo(-s * 0.6, -s * 0.25);
    path.lineTo(0, -s * 0.25);
    path.lineTo(0, -s * 0.6);
    path.lineTo(s * 0.7, 0);
    path.lineTo(0, s * 0.6);
    path.lineTo(0, s * 0.25);
    path.lineTo(-s * 0.6, s * 0.25);
    path.close();

    canvas.drawPath(path, arrowPaint);
    canvas.restore();
  }

  /// Draw the 4 classic safe star symbols at (8, 2), (2, 6), (6, 12), (12, 8).
  void _drawSafeStars(Canvas canvas, Size size) {
    const starIndices = [8, 21, 34, 47];
    for (final idx in starIndices) {
      final pt = BoardCoordinates.perimeterTiles[idx];
      final center = pt.toOffset(cellSize);
      _drawOutlinedStar(canvas, center, cellSize * 0.36);
    }
  }

  void _drawOutlinedStar(Canvas canvas, Offset center, double radius) {
    final strokePaint = Paint()
      ..color = const Color(0xFF616161)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    const int points = 5;
    const double step = pi / points;
    final double innerRadius = radius * 0.45;

    for (int i = 0; i < 2 * points; i++) {
      final r = (i % 2 == 0) ? radius : innerRadius;
      final angle = i * step - (pi / 2);
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ClassicLudoBoardPainter oldDelegate) =>
      oldDelegate.cellSize != cellSize ||
      oldDelegate.activePlayers != activePlayers;
}
