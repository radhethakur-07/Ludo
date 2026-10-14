import 'package:flutter/material.dart';
import 'ludo_constants.dart';

/// Supported player colors for classic Ludo.
enum PlayerColor {
  red,
  green,
  yellow,
  blue;

  int get startTile {
    switch (this) {
      case PlayerColor.red:
        return LudoConstants.redStartTile;
      case PlayerColor.green:
        return LudoConstants.greenStartTile;
      case PlayerColor.yellow:
        return LudoConstants.yellowStartTile;
      case PlayerColor.blue:
        return LudoConstants.blueStartTile;
    }
  }

  String get displayName {
    switch (this) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }

  Color get primaryColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFE53935); // Classic Vibrant Red
      case PlayerColor.green:
        return const Color(0xFF1E8E3E); // Classic Vibrant Green
      case PlayerColor.yellow:
        return const Color(0xFFF9A825); // Classic Rich Golden Yellow
      case PlayerColor.blue:
        return const Color(0xFF1976D2); // Classic Vibrant Blue
    }
  }

  Color get lightColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFFF8A80);
      case PlayerColor.green:
        return const Color(0xFFA5D6A7);
      case PlayerColor.yellow:
        return const Color(0xFFFFF59D);
      case PlayerColor.blue:
        return const Color(0xFF90CAF9);
    }
  }

  Color get darkColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFB71C1C);
      case PlayerColor.green:
        return const Color(0xFF0D5324);
      case PlayerColor.yellow:
        return const Color(0xFFF57F17);
      case PlayerColor.blue:
        return const Color(0xFF0D47A1);
    }
  }

  PlayerColor get opposite {
    switch (this) {
      case PlayerColor.red:
        return PlayerColor.yellow;
      case PlayerColor.green:
        return PlayerColor.blue;
      case PlayerColor.yellow:
        return PlayerColor.red;
      case PlayerColor.blue:
        return PlayerColor.green;
    }
  }
}

/// Token position category on the board.
enum TokenPositionType {
  yard,
  track,
  homeRunway,
  finished,
}

/// Represents one of the 4 tokens belonging to a player.
class LudoToken {
  final int id; // 0..3
  final PlayerColor owner;
  final int stepCount; // -1 = yard, 0 = start, 1..50 = track, 51..55 = runway, 56 = finished

  const LudoToken({
    required this.id,
    required this.owner,
    this.stepCount = LudoConstants.stepYard,
  });

  bool get isAtYard => stepCount == LudoConstants.stepYard;
  bool get isFinished => stepCount == LudoConstants.stepHomeFinished;
  bool get isOnTrack => stepCount >= 0 && stepCount < LudoConstants.stepEnterHomeRunway;
  bool get isOnHomeRunway =>
      stepCount >= LudoConstants.stepEnterHomeRunway &&
      stepCount < LudoConstants.stepHomeFinished;

  TokenPositionType get positionType {
    if (isAtYard) return TokenPositionType.yard;
    if (isFinished) return TokenPositionType.finished;
    if (isOnHomeRunway) return TokenPositionType.homeRunway;
    return TokenPositionType.track;
  }

  /// The common 0..51 perimeter track index, or null if in yard/runway/finished.
  int? get trackTileIndex {
    if (!isOnTrack) return null;
    return (owner.startTile + stepCount) % LudoConstants.circuitLength;
  }

  /// Runway step index (0..4) if in home runway, else null.
  int? get runwayIndex {
    if (!isOnHomeRunway) return null;
    return stepCount - LudoConstants.stepEnterHomeRunway;
  }

  LudoToken copyWith({int? stepCount}) {
    return LudoToken(
      id: id,
      owner: owner,
      stepCount: stepCount ?? this.stepCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner': owner.name,
      'stepCount': stepCount,
    };
  }

  factory LudoToken.fromMap(Map<String, dynamic> map) {
    return LudoToken(
      id: map['id'] as int,
      owner: PlayerColor.values.firstWhere((c) => c.name == map['owner']),
      stepCount: map['stepCount'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LudoToken &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          owner == other.owner &&
          stepCount == other.stepCount;

  @override
  int get hashCode => id.hashCode ^ owner.hashCode ^ stepCount.hashCode;

  @override
  String toString() =>
      'Token($owner #$id, step: $stepCount, tile: $trackTileIndex)';
}

/// Turn state within an active round.
enum TurnPhase {
  waitingForRoll,
  waitingForMove,
  turnFinished,
}

/// Reason why an extra turn was awarded.
enum ExtraTurnReason {
  rolledSix,
  capturedOpponent,
  none,
}

/// Result details of executing a token move.
class MoveResult {
  final LudoToken movedToken;
  final int fromStep;
  final int toStep;
  final LudoToken? capturedToken;
  final bool extraTurnGranted;
  final ExtraTurnReason extraTurnReason;
  final bool gameWon;

  const MoveResult({
    required this.movedToken,
    required this.fromStep,
    required this.toStep,
    this.capturedToken,
    this.extraTurnGranted = false,
    this.extraTurnReason = ExtraTurnReason.none,
    this.gameWon = false,
  });
}

/// Game overall status.
enum GameStatus {
  waitingForOpponent,
  inProgress,
  completed,
  abandoned,
}

/// Player metadata for local and online rooms.
class PlayerProfile {
  final String uid;
  final String displayName;
  final PlayerColor color;
  final bool isConnected;
  final bool isHost;

  const PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.color,
    this.isConnected = true,
    this.isHost = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'color': color.name,
      'isConnected': isConnected,
      'isHost': isHost,
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? 'Player',
      color: PlayerColor.values.firstWhere(
        (c) => c.name == map['color'],
        orElse: () => PlayerColor.red,
      ),
      isConnected: map['isConnected'] as bool? ?? true,
      isHost: map['isHost'] as bool? ?? false,
    );
  }

  PlayerProfile copyWith({
    String? displayName,
    bool? isConnected,
    bool? isHost,
  }) {
    return PlayerProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      color: color,
      isConnected: isConnected ?? this.isConnected,
      isHost: isHost ?? this.isHost,
    );
  }
}
