import 'dart:ui';
import 'package:duo_ludo/engine/ludo_models.dart';

/// Grid point (row, col) in a 15x15 board.
class GridPoint {
  final double row;
  final double col;
  const GridPoint(this.row, this.col);

  Offset toOffset(double cellSize) =>
      Offset((col + 0.5) * cellSize, (row + 0.5) * cellSize);
}

/// Computes pixel positions for tokens, perimeter track tiles, yards, and home runways.
class BoardCoordinates {
  static const int gridSize = 15;

  /// The 52 continuous perimeter path tiles (clockwise starting at Red start).
  static const List<GridPoint> perimeterTiles = [
    GridPoint(6, 1),   // 0 (Red Start)
    GridPoint(6, 2),   // 1
    GridPoint(6, 3),   // 2
    GridPoint(6, 4),   // 3
    GridPoint(6, 5),   // 4
    GridPoint(5, 6),   // 5
    GridPoint(4, 6),   // 6
    GridPoint(3, 6),   // 7
    GridPoint(2, 6),   // 8 (Star)
    GridPoint(1, 6),   // 9
    GridPoint(0, 6),   // 10
    GridPoint(0, 7),   // 11
    GridPoint(0, 8),   // 12
    GridPoint(1, 8),   // 13 (Blue Start)
    GridPoint(2, 8),   // 14
    GridPoint(3, 8),   // 15
    GridPoint(4, 8),   // 16
    GridPoint(5, 8),   // 17
    GridPoint(6, 9),   // 18
    GridPoint(6, 10),  // 19
    GridPoint(6, 11),  // 20
    GridPoint(6, 12),  // 21 (Star)
    GridPoint(6, 13),  // 22
    GridPoint(6, 14),  // 23
    GridPoint(7, 14),  // 24
    GridPoint(8, 14),  // 25
    GridPoint(8, 13),  // 26 (Green Start)
    GridPoint(8, 12),  // 27
    GridPoint(8, 11),  // 28
    GridPoint(8, 10),  // 29
    GridPoint(8, 9),   // 30
    GridPoint(9, 8),   // 31
    GridPoint(10, 8),  // 32
    GridPoint(11, 8),  // 33
    GridPoint(12, 8),  // 34 (Star)
    GridPoint(13, 8),  // 35
    GridPoint(14, 8),  // 36
    GridPoint(14, 7),  // 37
    GridPoint(14, 6),  // 38
    GridPoint(13, 6),  // 39 (Yellow Start)
    GridPoint(12, 6),  // 40
    GridPoint(11, 6),  // 41
    GridPoint(10, 6),  // 42
    GridPoint(9, 6),   // 43
    GridPoint(8, 5),   // 44
    GridPoint(8, 4),   // 45
    GridPoint(8, 3),   // 46
    GridPoint(8, 2),   // 47 (Star)
    GridPoint(8, 1),   // 48
    GridPoint(8, 0),   // 49
    GridPoint(7, 0),   // 50
    GridPoint(6, 0),   // 51
  ];

  /// Home runways (5 tiles each leading to center).
  static const List<GridPoint> redRunway = [
    GridPoint(7, 1),
    GridPoint(7, 2),
    GridPoint(7, 3),
    GridPoint(7, 4),
    GridPoint(7, 5),
  ];

  static const List<GridPoint> greenRunway = [
    GridPoint(7, 13),
    GridPoint(7, 12),
    GridPoint(7, 11),
    GridPoint(7, 10),
    GridPoint(7, 9),
  ];

  /// Center Home Triangle position.
  static const GridPoint redCenterHome = GridPoint(7, 6);
  static const GridPoint greenCenterHome = GridPoint(7, 8);

  /// Yard base dock coordinates (4 per player).
  static const List<GridPoint> redYardDocks = [
    GridPoint(1.7, 1.7),
    GridPoint(1.7, 3.7),
    GridPoint(3.7, 1.7),
    GridPoint(3.7, 3.7),
  ];

  static const List<GridPoint> greenYardDocks = [
    GridPoint(10.7, 10.7),
    GridPoint(10.7, 12.7),
    GridPoint(12.7, 10.7),
    GridPoint(12.7, 12.7),
  ];

  /// Get the exact grid point for a token.
  static GridPoint getTokenGridPoint(LudoToken token) {
    if (token.isAtYard) {
      final docks = token.owner == PlayerColor.red ? redYardDocks : greenYardDocks;
      return docks[token.id % docks.length];
    }

    if (token.isFinished) {
      return token.owner == PlayerColor.red ? redCenterHome : greenCenterHome;
    }

    if (token.isOnHomeRunway) {
      final runway = token.owner == PlayerColor.red ? redRunway : greenRunway;
      final idx = token.runwayIndex!;
      return runway[idx.clamp(0, runway.length - 1)];
    }

    // On common perimeter
    final tileIdx = token.trackTileIndex!;
    return perimeterTiles[tileIdx];
  }
}
