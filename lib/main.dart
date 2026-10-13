import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duo_ludo/audio/sound_manager.dart';
import 'package:duo_ludo/services/firebase_service.dart';
import 'package:duo_ludo/services/settings_service.dart';
import 'package:duo_ludo/ui/screens/home_screen.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for standard mobile board game ergonomics
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set dark system navigation and status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize local services and audio
  await SettingsService().init();
  await SoundManager().init();

  // Initialize Firebase anonymous auth (graceful offline fallback if credentials pending)
  await FirebaseService().init();

  runApp(const DuoLudoApp());
}

/// Root widget for Duo Ludo application.
class DuoLudoApp extends StatelessWidget {
  const DuoLudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duo Ludo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
