/// Ludo board constants and coordinate definitions.
class LudoConstants {
  /// Total squares on the outer perimeter circuit.
  static const int circuitLength = 52;

  /// Number of tokens per player.
  static const int tokensPerPlayer = 4;

  /// Starting tile indices on the common perimeter for each player color.
  /// Red starts at 0, Green starts at 26 (directly opposite).
  static const int redStartTile = 0;
  static const int greenStartTile = 26;

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
  /// - Starting spawn squares: 0 (Red), 26 (Green)
  /// - Classic Star squares: 8, 21, 34, 47 (or 0, 8, 13, 21, 26, 34, 39, 47)
  static const Set<int> safeTiles = {
    0,   // Red start
    8,   // Star 1
    13,  // Blue start / Star
    21,  // Star 2
    26,  // Green start
    34,  // Star 3
    39,  // Yellow start / Star
    47,  // Star 4
  };

  /// Maximum consecutive sixes allowed before turn is forfeited.
  static const int maxConsecutiveSixes = 3;

  /// Turn time limit in seconds for multiplayer timer.
  static const int turnTimeoutSeconds = 25;
}
