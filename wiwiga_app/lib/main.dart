// ============================================================
// Fichier: main.dart
// Description: Point d'entrée principal de l'application WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'presentation/screens/main/main_app_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();
  
  runApp(
    const ProviderScope(
      child: WiwigaApp(),
    ),
  );
}

class WiwigaApp extends StatelessWidget {
  const WiwigaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WIWIGA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainAppScreen(),
    );
  }
}
