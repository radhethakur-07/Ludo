import 'package:flutter_test/flutter_test.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/services/room_service.dart';

void main() {
  group('RoomService & Multiplayer Integration Tests', () {
    late RoomService roomService;

    setUp(() {
      roomService = RoomService();
    });

    test('Host creates room with unique 6-character code and waiting status', () async {
      final code = await roomService.createRoom(
        hostName: 'Alice',
        hostUid: 'alice_123',
      );

      expect(code.length, 6);
      expect(code, matches(r'^[A-Z0-9]{6}$'));

      final roomStream = roomService.streamRoom(code);
      final room = await roomStream.first;

      expect(room, isNotNull);
      expect(room!.roomCode, code);
      expect(room.host.displayName, 'Alice');
      expect(room.host.color, PlayerColor.red);
      expect(room.host.isHost, isTrue);
      expect(room.opponent, isNull);
      expect(room.status, GameStatus.waitingForOpponent);
    });

    test('Second player joins room successfully and starts game', () async {
      final code = await roomService.createRoom(
        hostName: 'Alice',
        hostUid: 'alice_123',
      );

      final joinedRoom = await roomService.joinRoom(
        roomCode: code,
        guestName: 'Bob',
        guestUid: 'bob_456',
      );

      expect(joinedRoom.status, GameStatus.inProgress);
      expect(joinedRoom.opponent, isNotNull);
      expect(joinedRoom.opponent!.displayName, 'Bob');
      expect(joinedRoom.opponent!.color, PlayerColor.green);
      expect(joinedRoom.isFull, isTrue);
    });

    test('Third player attempting to join full room throws error', () async {
      final code = await roomService.createRoom(
        hostName: 'Alice',
        hostUid: 'alice_123',
      );

      await roomService.joinRoom(
        roomCode: code,
        guestName: 'Bob',
        guestUid: 'bob_456',
      );

      // Third player tries to enter
      expect(
        () => roomService.joinRoom(
          roomCode: code,
          guestName: 'Charlie',
          guestUid: 'charlie_789',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Joining non-existent room code throws error', () async {
      expect(
        () => roomService.joinRoom(
          roomCode: 'INVALID',
          guestName: 'Bob',
          guestUid: 'bob_456',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Multiplayer dice rolling updates room state', () async {
      final code = await roomService.createRoom(
        hostName: 'Alice',
        hostUid: 'alice_123',
      );

      await roomService.joinRoom(
        roomCode: code,
        guestName: 'Bob',
        guestUid: 'bob_456',
      );

      // Host rolls dice
      await roomService.submitDiceRoll(
        roomCode: code,
        playerUid: 'alice_123',
      );

      final current = await roomService.streamRoom(code).first;
      expect(current!.engine.lastDiceRoll, isNotNull);
      expect(current.engine.lastDiceRoll! >= 1 && current.engine.lastDiceRoll! <= 6, isTrue);
    });

    test('Rematch request resets the game engine to beginning', () async {
      final code = await roomService.createRoom(
        hostName: 'Alice',
        hostUid: 'alice_123',
      );

      await roomService.joinRoom(
        roomCode: code,
        guestName: 'Bob',
        guestUid: 'bob_456',
      );

      await roomService.requestRematch(code);

      final room = await roomService.streamRoom(code).first;
      expect(room!.status, GameStatus.inProgress);
      expect(room.engine.getFinishedCount(PlayerColor.red), 0);
      expect(room.engine.getFinishedCount(PlayerColor.green), 0);
      expect(room.engine.tokens[PlayerColor.red]!.every((t) => t.isAtYard), isTrue);
    });
  });
}
