import 'dart:math';
import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_constants.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';
import 'board_coordinates.dart';
import 'token_widget.dart';

/// Interactive and responsive Ludo board widget with custom painter board canvas and animated tokens.
class LudoBoardWidget extends StatelessWidget {
  final List<LudoToken> redTokens;
  final List<LudoToken> greenTokens;
  final PlayerColor currentTurn;
  final List<int> legalMoveTokenIds;
  final Function(int tokenId)? onTokenTapped;
  final bool isInteractive;

  const LudoBoardWidget({
    super.key,
    required this.redTokens,
    required this.greenTokens,
    required this.currentTurn,
    required this.legalMoveTokenIds,
    this.onTokenTapped,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = boardSize / BoardCoordinates.gridSize;
        final tokenSize = cellSize * 0.88;

        // Group tokens by their grid coordinate to calculate offsets for stacking
        final allTokens = [...redTokens, ...greenTokens];
        final Map<String, List<LudoToken>> tokensByPos = {};
        for (final t in allTokens) {
          final pt = BoardCoordinates.getTokenGridPoint(t);
          final key = '${pt.row.toStringAsFixed(1)}_${pt.col.toStringAsFixed(1)}';
          tokensByPos.putIfAbsent(key, () => []).add(t);
        }

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1424),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (currentTurn == PlayerColor.red
                          ? AppTheme.redPrimary
                          : AppTheme.greenPrimary)
                      .withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: (currentTurn == PlayerColor.red
                        ? AppTheme.redPrimary
                        : AppTheme.greenPrimary)
                    .withOpacity(0.5),
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // 1. Board Background and Grid Canvas
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LudoBoardPainter(cellSize: cellSize),
                    ),
                  ),

                  // 2. Render Tokens at their exact pixel positions
                  for (final token in allTokens)
                    _buildPositionedToken(
                      token: token,
                      cellSize: cellSize,
                      tokenSize: tokenSize,
                      tokensInSameCell: tokensByPos[
                          '${BoardCoordinates.getTokenGridPoint(token).row.toStringAsFixed(1)}_${BoardCoordinates.getTokenGridPoint(token).col.toStringAsFixed(1)}']!,
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

    // Compute offset if multiple tokens share the same cell
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
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      left: left,
      top: top,
      child: TokenWidget(
        token: token,
        size: count > 2 ? tokenSize * 0.8 : tokenSize,
        isInteractive: isLegal,
        onTap: () {
          if (isLegal && onTokenTapped != null) {
            onTokenTapped!(token.id);
          }
        },
      ),
    );
  }
}

/// Custom painter for drawing classic Ludo track, safe star tiles, runways, and yards.
class _LudoBoardPainter extends CustomPainter {
  final double cellSize;

  _LudoBoardPainter({required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    _drawYards(canvas, size);
    _drawPerimeterAndTracks(canvas, size);
    _drawHomeTriangles(canvas, size);
    _drawStars(canvas, size);
  }

  void _drawYards(Canvas canvas, Size size) {
    final yardSize = cellSize * 6;

    // Red Yard (Top Left: 0..5, 0..5)
    _drawYardBox(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, yardSize, yardSize),
      gradientColors: [AppTheme.redSecondary, AppTheme.redPrimary],
      accentColor: AppTheme.redPrimary,
      docks: BoardCoordinates.redYardDocks,
    );

    // Green Yard (Bottom Right: 9..14, 9..14)
    _drawYardBox(
      canvas: canvas,
      rect: Rect.fromLTWH(cellSize * 9, cellSize * 9, yardSize, yardSize),
      gradientColors: [AppTheme.greenSecondary, AppTheme.greenPrimary],
      accentColor: AppTheme.greenPrimary,
      docks: BoardCoordinates.greenYardDocks,
    );

    // Top Right Decorative Yard
    _drawDecorativeYard(
      canvas: canvas,
      rect: Rect.fromLTWH(cellSize * 9, 0, yardSize, yardSize),
      color: const Color(0xFF1E293B),
    );

    // Bottom Left Decorative Yard
    _drawDecorativeYard(
      canvas: canvas,
      rect: Rect.fromLTWH(0, cellSize * 9, yardSize, yardSize),
      color: const Color(0xFF1E293B),
    );
  }

  void _drawYardBox({
    required Canvas canvas,
    required Rect rect,
    required List<Color> gradientColors,
    required Color accentColor,
    required List<GridPoint> docks,
  }) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );

    // Inner White/Glass Container
    final innerMargin = cellSize * 0.9;
    final innerRect = rect.deflate(innerMargin);
    final innerPaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(14)),
      innerPaint,
    );

    // Inner dock sockets
    final dockBorder = Paint()
      ..color = accentColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dockFill = Paint()..color = accentColor.withOpacity(0.15);

    for (final dock in docks) {
      final center = dock.toOffset(cellSize);
      final radius = cellSize * 0.65;
      canvas.drawCircle(center, radius, dockFill);
      canvas.drawCircle(center, radius, dockBorder);
    }
  }

  void _drawDecorativeYard({
    required Canvas canvas,
    required Rect rect,
    required Color color,
  }) {
    final paint = Paint()..color = color.withOpacity(0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
    final border = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(cellSize * 0.9), const Radius.circular(14)),
      border,
    );
  }

  void _drawPerimeterAndTracks(Canvas canvas, Size size) {
    final cellBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cellFillPaint = Paint()..color = const Color(0xFF1B2436);

    // Draw standard perimeter squares
    for (int i = 0; i < BoardCoordinates.perimeterTiles.length; i++) {
      final pt = BoardCoordinates.perimeterTiles[i];
      final rect = Rect.fromLTWH(
        pt.col * cellSize + 1,
        pt.row * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );

      // Start squares have special tint
      if (i == 0) {
        // Red start
        final redStartPaint = Paint()..color = AppTheme.redPrimary.withOpacity(0.45);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          redStartPaint,
        );
      } else if (i == 26) {
        // Green start
        final greenStartPaint = Paint()..color = AppTheme.greenPrimary.withOpacity(0.45);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          greenStartPaint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          cellFillPaint,
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        cellBorderPaint,
      );
    }

    // Red Runway (Row 7, Cols 1..5)
    final redRunwayPaint = Paint()..color = AppTheme.redPrimary.withOpacity(0.85);
    for (final pt in BoardCoordinates.redRunway) {
      final rect = Rect.fromLTWH(
        pt.col * cellSize + 1,
        pt.row * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        redRunwayPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        cellBorderPaint,
      );
    }

    // Green Runway (Row 7, Cols 9..13)
    final greenRunwayPaint = Paint()..color = AppTheme.greenPrimary.withOpacity(0.85);
    for (final pt in BoardCoordinates.greenRunway) {
      final rect = Rect.fromLTWH(
        pt.col * cellSize + 1,
        pt.row * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        greenRunwayPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        cellBorderPaint,
      );
    }
  }

  void _drawHomeTriangles(Canvas canvas, Size size) {
    final center = Offset(cellSize * 7.5, cellSize * 7.5);

    // Left triangle -> Red Home
    final redPath = Path()
      ..moveTo(cellSize * 6, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 6, cellSize * 9)
      ..close();
    final redPaint = Paint()..color = AppTheme.redPrimary;
    canvas.drawPath(redPath, redPaint);

    // Right triangle -> Green Home
    final greenPath = Path()
      ..moveTo(cellSize * 9, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 9)
      ..close();
    final greenPaint = Paint()..color = AppTheme.greenPrimary;
    canvas.drawPath(greenPath, greenPaint);

    // Top triangle
    final topPath = Path()
      ..moveTo(cellSize * 6, cellSize * 6)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 6)
      ..close();
    final topPaint = Paint()..color = const Color(0xFF2563EB);
    canvas.drawPath(topPath, topPaint);

    // Bottom triangle
    final bottomPath = Path()
      ..moveTo(cellSize * 6, cellSize * 9)
      ..lineTo(center.dx, center.dy)
      ..lineTo(cellSize * 9, cellSize * 9)
      ..close();
    final bottomPaint = Paint()..color = const Color(0xFFEAB308);
    canvas.drawPath(bottomPath, bottomPaint);

    // Golden center star / circle
    final centerStar = Paint()..color = AppTheme.gold;
    canvas.drawCircle(center, cellSize * 0.45, centerStar);
  }

  void _drawStars(Canvas canvas, Size size) {
    for (final safeIdx in LudoConstants.safeTiles) {
      if (safeIdx < BoardCoordinates.perimeterTiles.length) {
        final pt = BoardCoordinates.perimeterTiles[safeIdx];
        final center = pt.toOffset(cellSize);
        _drawStarIcon(canvas, center, cellSize * 0.3, AppTheme.safeStar);
      }
    }
  }

  void _drawStarIcon(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const int points = 5;
    const double step = pi / points;
    final double innerRadius = radius * 0.48;

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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
