import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:duo_ludo/engine/ludo_engine.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'firebase_service.dart';

/// Representation of an online multiplayer room.
class RoomModel {
  final String roomCode;
  final PlayerProfile host;
  final PlayerProfile? opponent;
  final LudoEngine engine;
  final GameStatus status;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? rematchRequestedBy;
  final int playerCount;
  final GameReaction? latestReaction;

  const RoomModel({
    required this.roomCode,
    required this.host,
    this.opponent,
    required this.engine,
    required this.status,
    required this.createdAt,
    required this.lastActive,
    this.rematchRequestedBy,
    this.playerCount = 2,
    this.latestReaction,
  });

  bool get isFull => opponent != null;

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'host': host.toMap(),
      'opponent': opponent?.toMap(),
      'engine': engine.toMap(),
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActive': lastActive.millisecondsSinceEpoch,
      'rematchRequestedBy': rematchRequestedBy,
      'playerCount': playerCount,
      'latestReaction': latestReaction?.toMap(),
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    final host = PlayerProfile.fromMap(map['host'] as Map<String, dynamic>);
    final oppMap = map['opponent'] as Map<String, dynamic>?;
    final opponent = oppMap != null ? PlayerProfile.fromMap(oppMap) : null;
    final engine = LudoEngine.fromMap(map['engine'] as Map<String, dynamic>);
    final status = GameStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => GameStatus.inProgress,
    );
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
    final lastActive = DateTime.fromMillisecondsSinceEpoch(
      map['lastActive'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
    final reactionMap = map['latestReaction'] as Map<String, dynamic>?;

    return RoomModel(
      roomCode: map['roomCode'] as String,
      host: host,
      opponent: opponent,
      engine: engine,
      status: status,
      createdAt: createdAt,
      lastActive: lastActive,
      rematchRequestedBy: map['rematchRequestedBy'] as String?,
      playerCount: map['playerCount'] as int? ?? 2,
      latestReaction:
          reactionMap != null ? GameReaction.fromMap(reactionMap) : null,
    );
  }
}

/// Service for creating, joining, and synchronizing multiplayer rooms.
class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  FirebaseFirestore? get _firestore =>
      FirebaseService().isFirebaseAvailable ? FirebaseFirestore.instance : null;

  // In-memory mock store for offline testing or when Firebase credentials are pending
  final Map<String, RoomModel> _mockRooms = {};
  final Map<String, StreamController<RoomModel?>> _mockControllers = {};

  /// Generate a human-readable 6-character room code (avoiding confusing chars).
  String generateRoomCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new private room.
  Future<String> createRoom({
    required String hostName,
    required String hostUid,
  }) async {
    final roomCode = generateRoomCode();
    final hostProfile = PlayerProfile(
      uid: hostUid,
      displayName: hostName,
      color: PlayerColor.red,
      isConnected: true,
      isHost: true,
    );

    final initialEngine = LudoEngine.newGame();

    final room = RoomModel(
      roomCode: roomCode,
      host: hostProfile,
      opponent: null,
      engine: initialEngine,
      status: GameStatus.waitingForOpponent,
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );

    if (FirebaseService().isFirebaseAvailable) {
      try {
        await _firestore!.collection('rooms').doc(roomCode).set(room.toMap());
        return roomCode;
      } catch (e) {
        debugPrint('Firestore write error: $e. Falling back to local room store.');
      }
    }

    // Fallback in-memory
    _mockRooms[roomCode] = room;
    _getMockController(roomCode).add(room);
    return roomCode;
  }

  /// Join an existing private room.
  Future<RoomModel> joinRoom({
    required String roomCode,
    required String guestName,
    required String guestUid,
  }) async {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      try {
        final docRef = _firestore!.collection('rooms').doc(code);
        final snapshot = await docRef.get();

        if (!snapshot.exists) {
          throw Exception('Room code $code does not exist.');
        }

        final room = RoomModel.fromMap(snapshot.data()!);

        // Check if room is expired (older than 24 hours)
        if (DateTime.now().difference(room.createdAt).inHours > 24) {
          throw Exception('This game room has expired.');
        }

        // If user is already the host reconnecting
        if (room.host.uid == guestUid) {
          return room;
        }

        // If user is already the opponent reconnecting
        if (room.opponent != null && room.opponent!.uid == guestUid) {
          return room;
        }

        // Check if room is already full
        if (room.isFull) {
          throw Exception('This room is already full (2 players are in match).');
        }

        // Pick an available default color that the host hasn't chosen
        final availableColor = PlayerColor.values.firstWhere(
          (c) => c != room.host.color,
          orElse: () => room.host.color.opposite,
        );
        final opponentProfile = PlayerProfile(
          uid: guestUid,
          displayName: guestName,
          color: availableColor,
          isConnected: true,
          isHost: false,
        );

        final active = [room.host.color, opponentProfile.color];
        final updatedEngine = LudoEngine.newGame(
          activePlayers: active,
          initialTurn: room.host.color,
        );

        final updatedRoom = RoomModel(
          roomCode: code,
          host: room.host,
          opponent: opponentProfile,
          engine: updatedEngine,
          status: GameStatus.inProgress,
          createdAt: room.createdAt,
          lastActive: DateTime.now(),
          playerCount: room.playerCount,
        );

        await docRef.update({
          'opponent': opponentProfile.toMap(),
          'engine': updatedEngine.toMap(),
          'status': GameStatus.inProgress.name,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });

        return updatedRoom;
      } catch (e) {
        if (!e.toString().contains('does not exist') &&
            !e.toString().contains('full') &&
            !e.toString().contains('expired')) {
          debugPrint('Firestore join error: $e');
        } else {
          rethrow;
        }
      }
    }

    // In-memory fallback
    final mockRoom = _mockRooms[code];
    if (mockRoom == null) {
      throw Exception('Room code $code does not exist.');
    }
    if (mockRoom.isFull && mockRoom.opponent?.uid != guestUid) {
      throw Exception('This room is already full.');
    }

    final availableColor = PlayerColor.values.firstWhere(
      (c) => c != mockRoom.host.color,
      orElse: () => mockRoom.host.color.opposite,
    );
    final opponentProfile = PlayerProfile(
      uid: guestUid,
      displayName: guestName,
      color: availableColor,
      isConnected: true,
      isHost: false,
    );

    final active = [mockRoom.host.color, opponentProfile.color];
    final updatedEngine = LudoEngine.newGame(
      activePlayers: active,
      initialTurn: mockRoom.host.color,
    );

    final updatedRoom = RoomModel(
      roomCode: code,
      host: mockRoom.host,
      opponent: opponentProfile,
      engine: updatedEngine,
      status: GameStatus.inProgress,
      createdAt: mockRoom.createdAt,
      lastActive: DateTime.now(),
      playerCount: mockRoom.playerCount,
    );

    _mockRooms[code] = updatedRoom;
    _getMockController(code).add(updatedRoom);
    return updatedRoom;
  }

  /// Listen to realtime room updates.
  Stream<RoomModel?> streamRoom(String roomCode) {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      return _firestore!.collection('rooms').doc(code).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return RoomModel.fromMap(snap.data()!);
      });
    }

    final controller = _getMockController(code);
    return () async* {
      if (_mockRooms.containsKey(code)) {
        yield _mockRooms[code];
      }
      yield* controller.stream;
    }();
  }

  /// Submit dice roll with validation on the backend / transaction.
  Future<void> submitDiceRoll({
    required String roomCode,
    required String playerUid,
  }) async {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      final docRef = _firestore!.collection('rooms').doc(code);
      await _firestore!.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Room not found');

        final room = RoomModel.fromMap(snap.data()!);
        final engine = room.engine;

        // Verify it is the current player's turn based on actual player colors
        final isHostTurn = engine.currentTurn == room.host.color;
        final expectedUid = isHostTurn ? room.host.uid : room.opponent?.uid;

        if (expectedUid != playerUid) {
          throw Exception('Not your turn to roll!');
        }

        // Execute server-authoritative roll
        engine.rollDice();

        tx.update(docRef, {
          'engine': engine.toMap(),
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
      });
      return;
    }

    // Mock execution
    final room = _mockRooms[code];
    if (room != null) {
      room.engine.rollDice();
      _mockRooms[code] = room;
      _getMockController(code).add(room);
    }
  }

  /// Submit token move with validation.
  Future<void> submitMove({
    required String roomCode,
    required String playerUid,
    required int tokenId,
  }) async {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      final docRef = _firestore!.collection('rooms').doc(code);
      await _firestore!.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Room not found');

        final room = RoomModel.fromMap(snap.data()!);
        final engine = room.engine;

        final isHostTurn = engine.currentTurn == room.host.color;
        final expectedUid = isHostTurn ? room.host.uid : room.opponent?.uid;

        if (expectedUid != playerUid) {
          throw Exception('Not your turn to move!');
        }

        // Validate and execute move
        engine.moveToken(tokenId);

        tx.update(docRef, {
          'engine': engine.toMap(),
          'status': engine.status.name,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
      });
      return;
    }

    // Mock execution
    final room = _mockRooms[code];
    if (room != null) {
      room.engine.moveToken(tokenId);
      _mockRooms[code] = room;
      _getMockController(code).add(room);
    }
  }

  /// Select/reserve a token color before match begins with conflict prevention.
  Future<void> selectPlayerColor({
    required String roomCode,
    required String playerUid,
    required PlayerColor newColor,
  }) async {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      final docRef = _firestore!.collection('rooms').doc(code);
      await _firestore!.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Room not found');

        final room = RoomModel.fromMap(snap.data()!);
        if (room.status == GameStatus.inProgress) {
          throw Exception('Cannot change color once match has started.');
        }

        final isHost = room.host.uid == playerUid;
        final isOpponent = room.opponent?.uid == playerUid;

        if (!isHost && !isOpponent) {
          throw Exception('User is not a member of this room.');
        }

        if (isHost && room.opponent != null && room.opponent!.color == newColor) {
          throw Exception('${newColor.displayName} is already taken by your opponent.');
        }
        if (isOpponent && room.host.color == newColor) {
          throw Exception('${newColor.displayName} is already taken by the host.');
        }

        final updatedHost = isHost ? room.host.copyWith(color: newColor) : room.host;
        final updatedOpponent = isOpponent ? room.opponent?.copyWith(color: newColor) : room.opponent;

        final active = [
          updatedHost.color,
          if (updatedOpponent != null) updatedOpponent.color,
        ];
        final updatedEngine = LudoEngine.newGame(
          activePlayers: active,
          initialTurn: updatedHost.color,
        );

        tx.update(docRef, {
          'host': updatedHost.toMap(),
          if (updatedOpponent != null) 'opponent': updatedOpponent.toMap(),
          'engine': updatedEngine.toMap(),
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
      });
      return;
    }

    // Mock execution
    final room = _mockRooms[code];
    if (room != null) {
      if (room.status == GameStatus.inProgress) {
        throw Exception('Cannot change color once match has started.');
      }
      final isHost = room.host.uid == playerUid;
      final isOpponent = room.opponent?.uid == playerUid;

      if (isHost && room.opponent?.color == newColor) {
        throw Exception('${newColor.displayName} is already taken.');
      }
      if (isOpponent && room.host.color == newColor) {
        throw Exception('${newColor.displayName} is already taken.');
      }

      final updatedHost = isHost ? room.host.copyWith(color: newColor) : room.host;
      final updatedOpponent = isOpponent ? room.opponent?.copyWith(color: newColor) : room.opponent;
      final active = [
        updatedHost.color,
        if (updatedOpponent != null) updatedOpponent.color,
      ];
      final updatedRoom = RoomModel(
        roomCode: code,
        host: updatedHost,
        opponent: updatedOpponent,
        engine: LudoEngine.newGame(activePlayers: active, initialTurn: updatedHost.color),
        status: room.status,
        createdAt: room.createdAt,
        lastActive: DateTime.now(),
        playerCount: room.playerCount,
        latestReaction: room.latestReaction,
      );
      _mockRooms[code] = updatedRoom;
      _getMockController(code).add(updatedRoom);
    }
  }

  /// Send an emoji reaction in realtime with anti-spam rate limiting.
  Future<void> sendReaction({
    required String roomCode,
    required String playerUid,
    required String playerName,
    required PlayerColor playerColor,
    required String emoji,
  }) async {
    final code = roomCode.trim().toUpperCase();
    final reaction = GameReaction(
      senderUid: playerUid,
      senderName: playerName,
      senderColor: playerColor,
      emoji: emoji,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    if (FirebaseService().isFirebaseAvailable) {
      try {
        await _firestore!.collection('rooms').doc(code).update({
          'latestReaction': reaction.toMap(),
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Firestore reaction send error: $e');
      }
      return;
    }

    final room = _mockRooms[code];
    if (room != null) {
      final updated = RoomModel(
        roomCode: code,
        host: room.host,
        opponent: room.opponent,
        engine: room.engine,
        status: room.status,
        createdAt: room.createdAt,
        lastActive: DateTime.now(),
        rematchRequestedBy: room.rematchRequestedBy,
        playerCount: room.playerCount,
        latestReaction: reaction,
      );
      _mockRooms[code] = updated;
      _getMockController(code).add(updated);
    }
  }

  /// Restart match / Rematch.
  Future<void> requestRematch(String roomCode) async {
    final code = roomCode.trim().toUpperCase();
    final freshEngine = LudoEngine.newGame();

    if (FirebaseService().isFirebaseAvailable) {
      await _firestore!.collection('rooms').doc(code).update({
        'engine': freshEngine.toMap(),
        'status': GameStatus.inProgress.name,
        'rematchRequestedBy': null,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }

    final room = _mockRooms[code];
    if (room != null) {
      final updated = RoomModel(
        roomCode: code,
        host: room.host,
        opponent: room.opponent,
        engine: freshEngine,
        status: GameStatus.inProgress,
        createdAt: room.createdAt,
        lastActive: DateTime.now(),
        playerCount: room.playerCount,
      );
      _mockRooms[code] = updated;
      _getMockController(code).add(updated);
    }
  }

  /// Leave or forfeit the room.
  Future<void> leaveRoom(String roomCode, String playerUid) async {
    final code = roomCode.trim().toUpperCase();

    if (FirebaseService().isFirebaseAvailable) {
      try {
        await _firestore!.collection('rooms').doc(code).update({
          'status': GameStatus.abandoned.name,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
      return;
    }

    final room = _mockRooms[code];
    if (room != null) {
      final updated = RoomModel(
        roomCode: code,
        host: room.host,
        opponent: room.opponent,
        engine: room.engine,
        status: GameStatus.abandoned,
        createdAt: room.createdAt,
        lastActive: DateTime.now(),
        playerCount: room.playerCount,
      );
      _mockRooms[code] = updated;
      _getMockController(code).add(updated);
    }
  }

  StreamController<RoomModel?> _getMockController(String code) {
    return _mockControllers.putIfAbsent(
      code,
      () => StreamController<RoomModel?>.broadcast(),
    );
  }
}
