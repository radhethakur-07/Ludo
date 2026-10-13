const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Board Constants
const CIRCUIT_LENGTH = 52;
const RED_START = 0;
const GREEN_START = 26;
const STEP_RUNWAY = 51;
const STEP_FINISHED = 56;
const SAFE_TILES = new Set([0, 8, 13, 21, 26, 34, 39, 47]);

/**
 * Callable Function: rollDice
 * Server-authoritative dice roll generation with crypto randomness and anti-cheat validation.
 */
exports.rollDice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { roomCode } = data;
  if (!roomCode) {
    throw new functions.https.HttpsError('invalid-argument', 'roomCode is required');
  }

  const roomRef = db.collection('rooms').doc(roomCode.toUpperCase());

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Room not found');
    }

    const room = snap.data();
    const engine = room.engine;
    const isRedTurn = engine.currentTurn === 'red';
    const expectedUid = isRedTurn ? room.host.uid : room.opponent?.uid;

    if (context.auth.uid !== expectedUid) {
      throw new functions.https.HttpsError('permission-denied', 'Not your turn to roll!');
    }

    if (engine.turnPhase !== 'waitingForRoll') {
      throw new functions.https.HttpsError('failed-precondition', 'Not in waitingForRoll phase');
    }

    // Cryptographically secure random roll: 1..6
    const roll = crypto.randomInt(1, 7);
    engine.currentDiceRoll = roll;
    engine.lastDiceRoll = roll;

    if (roll === 6) {
      engine.consecutiveSixes = (engine.consecutiveSixes || 0) + 1;
    } else {
      engine.consecutiveSixes = 0;
    }

    // 3 consecutive 6s rule
    if (engine.consecutiveSixes >= 3) {
      engine.consecutiveSixes = 0;
      engine.currentDiceRoll = null;
      engine.currentTurn = isRedTurn ? 'green' : 'red';
      engine.turnPhase = 'waitingForRoll';
      engine.moveLog = engine.moveLog || [];
      engine.moveLog.push(`${isRedTurn ? 'Red' : 'Green'} rolled three consecutive 6s! Turn forfeited.`);
    } else {
      // Calculate legal moves
      const activeTokens = isRedTurn ? engine.redTokens : engine.greenTokens;
      const legalTokenIds = [];

      for (const token of activeTokens) {
        if (token.stepCount === STEP_FINISHED) continue;
        if (token.stepCount === -1) {
          if (roll === 6) legalTokenIds.push(token.id);
        } else {
          if (token.stepCount + roll <= STEP_FINISHED) {
            legalTokenIds.push(token.id);
          }
        }
      }

      if (legalTokenIds.length === 0) {
        // No legal moves possible, pass turn immediately
        engine.consecutiveSixes = 0;
        engine.currentDiceRoll = null;
        engine.currentTurn = isRedTurn ? 'green' : 'red';
        engine.turnPhase = 'waitingForRoll';
      } else {
        engine.turnPhase = 'waitingForMove';
      }
    }

    tx.update(roomRef, {
      engine: engine,
      lastActive: Date.now(),
    });

    return { roll, turnPhase: engine.turnPhase };
  });
});

/**
 * Callable Function: moveToken
 * Validates token move, captures, safe squares, home entries, and victory conditions.
 */
exports.moveToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { roomCode, tokenId } = data;
  if (!roomCode || tokenId === undefined) {
    throw new functions.https.HttpsError('invalid-argument', 'roomCode and tokenId required');
  }

  const roomRef = db.collection('rooms').doc(roomCode.toUpperCase());

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Room not found');
    }

    const room = snap.data();
    const engine = room.engine;
    const isRedTurn = engine.currentTurn === 'red';
    const expectedUid = isRedTurn ? room.host.uid : room.opponent?.uid;

    if (context.auth.uid !== expectedUid) {
      throw new functions.https.HttpsError('permission-denied', 'Not your turn to move!');
    }

    if (engine.turnPhase !== 'waitingForMove' || !engine.currentDiceRoll) {
      throw new functions.https.HttpsError('failed-precondition', 'Cannot move in current phase');
    }

    const roll = engine.currentDiceRoll;
    const myTokens = isRedTurn ? engine.redTokens : engine.greenTokens;
    const oppTokens = isRedTurn ? engine.greenTokens : engine.redTokens;
    const token = myTokens.find((t) => t.id === tokenId);

    if (!token) {
      throw new functions.https.HttpsError('not-found', 'Token not found');
    }

    // Validate legality
    let newStep;
    if (token.stepCount === -1) {
      if (roll !== 6) {
        throw new functions.https.HttpsError('invalid-argument', 'Must roll 6 to exit yard');
      }
      newStep = 0;
    } else {
      newStep = token.stepCount + roll;
      if (newStep > STEP_FINISHED) {
        throw new functions.https.HttpsError('invalid-argument', 'Cannot overshoot home');
      }
    }

    token.stepCount = newStep;

    // Check capture
    let captured = false;
    if (newStep >= 0 && newStep < STEP_RUNWAY) {
      const myStart = isRedTurn ? RED_START : GREEN_START;
      const targetTile = (myStart + newStep) % CIRCUIT_LENGTH;

      if (!SAFE_TILES.has(targetTile)) {
        const oppStart = isRedTurn ? GREEN_START : RED_START;
        for (const oppToken of oppTokens) {
          if (oppToken.stepCount >= 0 && oppToken.stepCount < STEP_RUNWAY) {
            const oppTile = (oppStart + oppToken.stepCount) % CIRCUIT_LENGTH;
            if (oppTile === targetTile) {
              oppToken.stepCount = -1; // Send back to yard
              captured = true;
              break;
            }
          }
        }
      }
    }

    // Check Win
    const allFinished = myTokens.every((t) => t.stepCount === STEP_FINISHED);
    if (allFinished) {
      room.status = 'completed';
      engine.status = 'completed';
      engine.winner = isRedTurn ? 'red' : 'green';
      engine.turnPhase = 'turnFinished';
      tx.update(roomRef, {
        status: 'completed',
        engine: engine,
        lastActive: Date.now(),
      });
      return { success: true, gameWon: true, winner: engine.winner };
    }

    // Extra Turn logic: captured enemy OR rolled a 6
    const extraTurn = captured || (roll === 6 && (engine.consecutiveSixes || 0) < 3);
    engine.currentDiceRoll = null;

    if (extraTurn) {
      engine.turnPhase = 'waitingForRoll';
    } else {
      engine.consecutiveSixes = 0;
      engine.currentTurn = isRedTurn ? 'green' : 'red';
      engine.turnPhase = 'waitingForRoll';
    }

    tx.update(roomRef, {
      engine: engine,
      lastActive: Date.now(),
    });

    return { success: true, gameWon: false, extraTurn };
  });
});
