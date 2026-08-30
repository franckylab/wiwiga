// ============================================================
// Fichier: main.dart
// Description: Point d'entrée principal de l'application WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();

  // Global error handlers — filter benign extension errors + log real LateInit
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('runtime.lastError') || msg.contains('message port closed')) {
      return; // extension noise, not app bug
    }
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('[FlutterError] $msg');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    if (msg.contains('runtime.lastError') || msg.contains('message port closed')) {
      return true; // suppress
    }
    if (msg.contains('LateInitializationError')) {
      debugPrint('[LateInit] $error\n$stack');
    }
    return false;
  };

  // Pré-charger Noto Sans sans bloquer le premier frame
  // (await bloquant causait un spinner infini en debug web)
  GoogleFonts.pendingFonts([GoogleFonts.notoSans()]).catchError((_) => <void>[]);
  
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
