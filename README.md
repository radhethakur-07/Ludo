# 🎲 Duo Ludo - Premium Android Multiplayer Board Game

**Duo Ludo** is a high-polish, 2-player online multiplayer mobile board game built with Flutter and Firebase. It features classic Ludo board rules, turn synchronization over the internet, instant zero-friction anonymous authentication, and an automated cloud build pipeline that compiles an installable Android APK without needing Android Studio installed on your computer.

---

## 🌟 Key Features

1. **True Mobile-First Architecture**: Built natively with Flutter for Android smartphones.
2. **Online 2-Player Multiplayer**:
   - Host generates a unique 6-character room code (e.g. `K9X2B4`).
   - Opponent joins by entering the code or opening a shareable invite link.
   - Realtime turns, dice rolls, and token positions synchronized via Firestore.
3. **Pass & Play (Local 2-Player)**:
   - Play side-by-side on a single device completely offline without internet or setup.
4. **Anonymous Authentication**:
   - Zero-friction guest login—players never need to enter an email, password, or phone number.
5. **Authentic Classic Ludo Engine**:
   - Pure Dart deterministic game engine with 100% test coverage.
   - Roll 6 to release token from base yard to track.
   - Safe squares (spawn tiles & golden stars) protect tokens from being captured.
   - Capturing opponent tokens sends them back to the yard and awards a bonus roll.
   - Rolling a 6 awards an extra turn (max 3 consecutive 6s anti-monopoly rule).
   - Exact roll required to reach the center Home triangle.
6. **Polished Arcade UI**:
   - 3D-styled dice with roll animation and pip faces.
   - Pulsating halo guides the player on legal moves.
   - Turn countdown timer with automatic forfeit protection.
   - Haptic vibration feedback and crisp audio cues.
   - Rematch, leave confirmation, and victory fanfare modals.
7. **Anti-Cheat Trusted Backend**:
   - Firebase Firestore Security Rules (`firestore.rules`).
   - Server-authoritative Cloud Functions (`functions/index.js`).
8. **Cloud-Based APK Build (Zero Android Studio Needed)**:
   - Pre-configured GitHub Actions CI/CD workflow (`.github/workflows/build_apk.yml`).

---

## 🚀 Quick Setup for Beginners

### Step 1: Recommend Workspace Directory
If you haven't opened the project workspace yet, set your active workspace in Antigravity to:
`C:\Users\Asus\.gemini\antigravity\scratch\duo_ludo`

### Step 2: Running Unit & Integration Tests Locally
You can run all tests directly from the terminal:
```bash
flutter test
```
All 17 tests verify board math, token moves, captures, safe stars, 3-sixes rules, and room joining.

---

## ☁️ How to Build Your Android APK in the Cloud (No Android Studio!)

You don't need Android Studio or heavy local SDKs installed. We've set up a **GitHub Actions Cloud Build Pipeline**:

1. **Create a new repository on GitHub**:
   - Go to [github.com/new](https://github.com/new) and name it `duo_ludo` (select Private or Public).
2. **Push your code to GitHub**:
   In your terminal, run:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/duo_ludo.git
   git branch -M main
   git push -u origin main
   ```
3. **Download Your APK**:
   - Open your GitHub repository in your browser.
   - Click the **Actions** tab at the top.
   - You will see the **Duo Ludo Android APK Cloud Build** running automatically!
   - Once it finishes (approx. 2-3 minutes), click on the run and download the **`DuoLudo-Release-APK`** artifact zip file.
   - Extract `app-release.apk` and transfer it to your phone to install and play!

---

## 🔥 Simple Firebase Setup (For Online Multiplayer)

> **Note**: Local Pass & Play mode works 100% offline out-of-the-box without Firebase! When you are ready to play online with friends between two different phones over the internet, follow these simple steps:

### 1. Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add Project** and name it `Duo-Ludo` (you can disable Google Analytics).
3. Click **Create Project**.

### 2. Enable Anonymous Authentication
1. In your Firebase project dashboard, click **Build > Authentication** from the left menu.
2. Click **Get Started**, then click on the **Sign-in method** tab.
3. Select **Anonymous**, toggle the switch to **Enable**, and click **Save**.
*(Now players can log in instantly without passwords or emails!)*

### 3. Create Cloud Firestore Database
1. In the left menu, click **Build > Firestore Database**.
2. Click **Create database**.
3. Choose a location closest to you and click **Next**.
4. Start in **Production mode** and click **Create**.

### 4. Deploy Security Rules
1. In the Firestore Database tab, click on **Rules**.
2. Copy and paste the contents of `firestore.rules` (located in the root of this project) into the editor.
3. Click **Publish**.

### 5. Add Android App to Firebase
1. Click the **Project Overview gear icon ⚙️ > Project settings**.
2. Under "Your apps", click the **Android icon**.
3. In **Android package name**, enter:
   `com.duoludo.app.duo_ludo`
4. In App nickname, enter: `Duo Ludo`.
5. Click **Register app**.
6. Download the generated `google-services.json` file.
7. Place this `google-services.json` file into:
   `android/app/google-services.json`

### 6. (Optional) Deploy Trusted Cloud Functions
If you want server-authoritative backend dice generation and move verification:
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Run `firebase login`
3. Run `firebase deploy --only functions`

---

## 📁 Project Architecture & Structure

```
duo_ludo/
├── .github/workflows/
│   └── build_apk.yml            # Automated GitHub Actions Cloud APK Build
├── android/
│   └── app/
│       ├── build.gradle.kts     # Android Gradle build configuration
│       └── src/main/AndroidManifest.xml # Permissions & metadata
├── functions/
│   ├── package.json             # Cloud Functions dependencies
│   └── index.js                 # Server-authoritative anti-cheat validation
├── lib/
│   ├── audio/
│   │   └── sound_manager.dart   # Haptic feedback & audio triggers
│   ├── engine/
│   │   ├── ludo_constants.dart  # Track coordinates, safe tiles, constants
│   │   ├── ludo_models.dart     # Tokens, players, moves, serialized models
│   │   └── ludo_engine.dart     # Pure Dart deterministic rule engine
│   ├── services/
│   │   ├── firebase_service.dart# Anonymous Auth & core setup
│   │   ├── room_service.dart    # Room codes, joining, Firestore sync
│   │   └── settings_service.dart# Nickname & audio preference storage
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── home_screen.dart # Main dashboard & mode selector
│   │   │   ├── game_screen.dart # Interactive gameplay screen
│   │   │   ├── lobby_screen.dart# Private room code & share invite
│   │   │   └── settings_screen.dart # Profile & sound settings
│   │   ├── theme/
│   │   │   └── app_theme.dart   # Dark arcade design system
│   │   └── widgets/
│   │       ├── board/           # LudoBoardWidget, tokens, coordinates
│   │       ├── dice/            # 3D animated DiceWidget
│   │       ├── dialogs/         # Victory, leave, & join modals
│   │       └── player_card_widget.dart # Player status & turn timer
│   └── main.dart                # App entry point
├── test/
│   ├── ludo_engine_test.dart    # 10 comprehensive Ludo rules unit tests
│   ├── room_multiplayer_test.dart# 6 integration tests for multiplayer rooms
│   └── widget_test.dart         # Home UI smoke test
├── firestore.rules              # Production Firestore Security Rules
└── pubspec.yaml                 # Flutter dependencies
```

---

## 🏆 Game Rules Overview

- **Safe Squares (⭐)**: Stars and starting squares protect tokens. Opponents cannot capture on safe squares.
- **Bonus Turns**: Rolling a `6` or capturing an enemy token awards an immediate bonus turn.
- **Three 6s Penalty**: Rolling three consecutive sixes forfeits the turn to prevent camping.
- **Victory**: The first player to navigate all 4 tokens into the central Home triangle wins!
