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

/// Computes pixel positions for tokens, perimeter track tiles, yards, and home runways for all 4 colors.
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
    GridPoint(2, 6),   // 8 (Star on Red side)
    GridPoint(1, 6),   // 9
    GridPoint(0, 6),   // 10
    GridPoint(0, 7),   // 11
    GridPoint(0, 8),   // 12
    GridPoint(1, 8),   // 13 (Green Start)
    GridPoint(2, 8),   // 14
    GridPoint(3, 8),   // 15
    GridPoint(4, 8),   // 16
    GridPoint(5, 8),   // 17
    GridPoint(6, 9),   // 18
    GridPoint(6, 10),  // 19
    GridPoint(6, 11),  // 20
    GridPoint(6, 12),  // 21 (Star on Green side)
    GridPoint(6, 13),  // 22
    GridPoint(6, 14),  // 23
    GridPoint(7, 14),  // 24
    GridPoint(8, 14),  // 25
    GridPoint(8, 13),  // 26 (Yellow Start)
    GridPoint(8, 12),  // 27
    GridPoint(8, 11),  // 28
    GridPoint(8, 10),  // 29
    GridPoint(8, 9),   // 30
    GridPoint(9, 8),   // 31
    GridPoint(10, 8),  // 32
    GridPoint(11, 8),  // 33
    GridPoint(12, 8),  // 34 (Star on Yellow side)
    GridPoint(13, 8),  // 35
    GridPoint(14, 8),  // 36
    GridPoint(14, 7),  // 37
    GridPoint(14, 6),  // 38
    GridPoint(13, 6),  // 39 (Blue Start)
    GridPoint(12, 6),  // 40
    GridPoint(11, 6),  // 41
    GridPoint(10, 6),  // 42
    GridPoint(9, 6),   // 43
    GridPoint(8, 5),   // 44
    GridPoint(8, 4),   // 45
    GridPoint(8, 3),   // 46
    GridPoint(8, 2),   // 47 (Star on Blue side)
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
    GridPoint(1, 7),
    GridPoint(2, 7),
    GridPoint(3, 7),
    GridPoint(4, 7),
    GridPoint(5, 7),
  ];

  static const List<GridPoint> yellowRunway = [
    GridPoint(7, 13),
    GridPoint(7, 12),
    GridPoint(7, 11),
    GridPoint(7, 10),
    GridPoint(7, 9),
  ];

  static const List<GridPoint> blueRunway = [
    GridPoint(13, 7),
    GridPoint(12, 7),
    GridPoint(11, 7),
    GridPoint(10, 7),
    GridPoint(9, 7),
  ];

  /// Center Home Triangle position for each color.
  static const GridPoint redCenterHome = GridPoint(7, 6.2);
  static const GridPoint greenCenterHome = GridPoint(6.2, 7);
  static const GridPoint yellowCenterHome = GridPoint(7, 7.8);
  static const GridPoint blueCenterHome = GridPoint(7.8, 7);

  /// Yard base dock coordinates (4 per player).
  static const List<GridPoint> redYardDocks = [
    GridPoint(1.8, 1.8),
    GridPoint(1.8, 3.2),
    GridPoint(3.2, 1.8),
    GridPoint(3.2, 3.2),
  ];

  static const List<GridPoint> greenYardDocks = [
    GridPoint(1.8, 10.8),
    GridPoint(1.8, 12.2),
    GridPoint(3.2, 10.8),
    GridPoint(3.2, 12.2),
  ];

  static const List<GridPoint> yellowYardDocks = [
    GridPoint(10.8, 10.8),
    GridPoint(10.8, 12.2),
    GridPoint(12.2, 10.8),
    GridPoint(12.2, 12.2),
  ];

  static const List<GridPoint> blueYardDocks = [
    GridPoint(10.8, 1.8),
    GridPoint(10.8, 3.2),
    GridPoint(12.2, 1.8),
    GridPoint(12.2, 3.2),
  ];

  /// Get the exact grid point for any token.
  static GridPoint getTokenGridPoint(LudoToken token) {
    if (token.isAtYard) {
      final docks = getYardDocks(token.owner);
      return docks[token.id % docks.length];
    }

    if (token.isFinished) {
      switch (token.owner) {
        case PlayerColor.red:
          return redCenterHome;
        case PlayerColor.green:
          return greenCenterHome;
        case PlayerColor.yellow:
          return yellowCenterHome;
        case PlayerColor.blue:
          return blueCenterHome;
      }
    }

    if (token.isOnHomeRunway) {
      final runway = getRunway(token.owner);
      final idx = token.runwayIndex!;
      return runway[idx.clamp(0, runway.length - 1)];
    }

    // On common perimeter
    final tileIdx = token.trackTileIndex!;
    return perimeterTiles[tileIdx];
  }

  /// Get the yard docks for a specific color.
  static List<GridPoint> getYardDocks(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redYardDocks;
      case PlayerColor.green:
        return greenYardDocks;
      case PlayerColor.yellow:
        return yellowYardDocks;
      case PlayerColor.blue:
        return blueYardDocks;
    }
  }

  /// Get the home runway for a specific color.
  static List<GridPoint> getRunway(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redRunway;
      case PlayerColor.green:
        return greenRunway;
      case PlayerColor.yellow:
        return yellowRunway;
      case PlayerColor.blue:
        return blueRunway;
    }
  }

  /// Get starting arrow position and direction for each color.
  /// Arrow points onto the starting cell.
  static GridPoint getStartArrowPosition(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return const GridPoint(6, 0); // Points right into (6, 1)
      case PlayerColor.green:
        return const GridPoint(0, 8); // Points down into (1, 8)
      case PlayerColor.yellow:
        return const GridPoint(8, 14); // Points left into (8, 13)
      case PlayerColor.blue:
        return const GridPoint(14, 6); // Points up into (13, 6)
    }
  }
}
