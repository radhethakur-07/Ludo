/// Ludo board constants and coordinate definitions for classic 4-color board.
class LudoConstants {
  /// Total squares on the outer perimeter circuit.
  static const int circuitLength = 52;

  /// Number of tokens per player.
  static const int tokensPerPlayer = 4;

  /// Starting tile indices on the common perimeter for each player color.
  /// Standard classic layout:
  /// - Red (Top-Left): 0
  /// - Green (Top-Right): 13
  /// - Yellow (Bottom-Right): 26
  /// - Blue (Bottom-Left): 39
  static const int redStartTile = 0;
  static const int greenStartTile = 13;
  static const int yellowStartTile = 26;
  static const int blueStartTile = 39;

  /// Steps from yard:
  /// step -1: in yard
  /// step 0: at entry tile
  /// step 1..50: traveling common perimeter (total 51 tiles on perimeter)
  /// step 51..55: 5 colored home runway tiles
  /// step 56: Home center triangle (Completed!)
  static const int stepYard = -1;
  static const int stepStart = 0;
  static const int stepEnterHomeRunway = 51;
  static const int stepHomeFinished = 56;

  /// Safe perimeter tiles where tokens cannot be captured:
  /// - 4 Starting spawn squares: 0 (Red), 13 (Green), 26 (Yellow), 39 (Blue)
  /// - 4 Classic Star squares: 8, 21, 34, 47
  static const Set<int> safeTiles = {
    0,   // Red start
    8,   // Star 1 (Red side)
    13,  // Green start
    21,  // Star 2 (Green side)
    26,  // Yellow start
    34,  // Star 3 (Yellow side)
    39,  // Blue start
    47,  // Star 4 (Blue side)
  };

  /// Maximum consecutive sixes allowed before turn is forfeited.
  static const int maxConsecutiveSixes = 3;

  /// Turn time limit in seconds for multiplayer timer.
  static const int turnTimeoutSeconds = 25;
}
