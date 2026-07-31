// ============================================================
// Fichier: main.dart
// Description: Point d'entrée principal de l'application WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();
  
  runApp(
    const ProviderScope(
      child: WiwigaApp(),
    ),
  );
}

class WiwigaApp extends ConsumerWidget {
  const WiwigaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'WIWIGA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
