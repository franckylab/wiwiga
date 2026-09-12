// ============================================================
// Fichier: main.dart
// Description: Point d'entrée principal de l'application WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/errors/error_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/neon_theme.dart';
import 'core/widgets/wiwiga_error_view.dart';
import 'data/providers/app_providers.dart';
import 'data/providers/notification_provider.dart';
import 'presentation/widgets/neon/neon_widgets.dart';

void main() async {
  // Zoneguarded pour capter les erreurs hors Flutter callbacks (ex: Timer, Future)
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppConfig.initialize();

    // Global error handlers — séparation user copy / telemetry (best practice)
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('runtime.lastError') ||
          msg.contains('message port closed')) {
        return; // bruit extension Chrome, pas app
      }
      // Telemetry (jamais exposée telle quelle à l'utilisateur)
      ErrorHandler.logError(
        details.exception,
        details.stack,
        context: 'FlutterError',
        force: kDebugMode,
      );
      if (kDebugMode) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      final msg = error.toString();
      if (msg.contains('runtime.lastError') ||
          msg.contains('message port closed')) {
        return true;
      }
      ErrorHandler.logError(error, stack, context: 'PlatformDispatcher');
      return false;
    };

    // Widget d'erreur global — jamais de stacktrace, jamais de rouge agressif en prod
    ErrorWidget.builder = (details) {
      final msg = ErrorHandler.userMessage(details.exception);
      // En debug on garde le détail, en release on montre un fallback humain
      if (kDebugMode) {
        return Material(
          color: const Color(0xFF0F172A),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur d\'affichage (debug): $msg',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      return Material(
        color: const Color(0xFF0F172A),
        child: WiwigaErrorView(
          error: details.exception,
          stackTrace: details.stack,
          title: 'Affichage indisponible',
        ),
      );
    };

    // Pré-charger Noto Sans sans bloquer le premier frame
    GoogleFonts.pendingFonts([GoogleFonts.notoSans()])
        .catchError((_) => <void>[]);

    runApp(
      const ProviderScope(
        child: WiwigaApp(),
      ),
    );
  }, (error, stack) {
    ErrorHandler.logError(
      error,
      stack,
      context: 'runZonedGuarded',
      force: true,
    );
  });
}

class WiwigaApp extends ConsumerWidget {
  const WiwigaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Push FCM : init unique (permissions + token + tap → inbox).
    // Silencieux si Firebase non configuré (inbox in_app en repli).
    ref.watch(pushInitProvider);

    // Écoute session expirée → feedback humain immédiat (pas de technique exposée)
    ref.listen<AuthStatus>(
      authProvider.select((s) => s.status),
      (prev, next) {
        // Login : explicatif push (une seule fois) puis enregistrement token
        if (prev != AuthStatus.authenticated &&
            next == AuthStatus.authenticated) {
          Future.microtask(() => _maybeAskPushOptIn(ref));
        }
        // prev/next sont AuthStatus, on veut détecter authenticated -> guest
        if (prev == AuthStatus.authenticated && next == AuthStatus.guest) {
          Future.microtask(() => unregisterPushToken(ref));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              WiwigaSnack.showError(
                ctx,
                'Session expirée. Reconnectez-vous pour continuer.',
              );
              // Redirection immédiate si pas déjà sur /auth
              final current = router.routeInformationProvider.value.uri.path;
              if (current != '/auth' && current != '/splash') {
                router.go('/auth');
              }
            }
          });
        }
      },
    );

    return MaterialApp.router(
      title: 'WIWIGA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Fallback global pour erreurs de build (jamais de stacktrace)
      builder: (context, child) {
        // Permet d'afficher une bannière offline si besoin (future: connectivity_plus)
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Opt-in push au premier login : explique le bénéfice AVANT le prompt OS
/// (bonne pratique store), une seule fois (flag SharedPreferences).
/// Sans Firebase configuré : silencieux, inbox in_app en repli.
Future<void> _maybeAskPushOptIn(WidgetRef ref) async {
  try {
    await ref.read(pushInitProvider.future);
    final service = ref.read(pushNotificationServiceProvider);
    if (!service.isAvailable) {
      await _registerQuietly(ref);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_optin_asked') == true) {
      await _registerQuietly(ref);
      return;
    }

    await prefs.setBool('push_optin_asked', true);

    // Laisser go_router terminer la transition post-login : afficher la
    // modale pendant la navigation l'avale silencieusement (catch global)
    // ALORS que le flag est déjà posé → plus jamais de modale ensuite.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      await _registerQuietly(ref);
      return;
    }

    // Permission déjà bloquée côté OS/navigateur : le prompt OS ne
    // s'afficherait pas (silence garanti) → guidance de déblocage.
    final blocked =
        await service.permissionStatus() == AuthorizationStatus.denied;
    if (blocked) {
      if (!context.mounted) {
        await registerPushToken(ref);
        return;
      }
      final retry = await _showPushBlockedModal(context);
      if (retry == true) {
        final result = await ensurePushEnabled(ref);
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          if (result.ok) {
            WiwigaSnack.showSuccess(ctx, result.message);
          } else {
            WiwigaSnack.showError(ctx, result.message);
          }
        }
      }
      return;
    }

    if (!context.mounted) {
      await registerPushToken(ref);
      return;
    }
    final accepted = await _showPushOptInModal(context);

    if (accepted == true) {
      // Chemin unifié avec feedback : succès confirmé, échec expliqué
      // (au lieu du silence de registerPushToken).
      final result = await ensurePushEnabled(ref);
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        if (result.ok) {
          WiwigaSnack.showSuccess(ctx, result.message);
        } else {
          WiwigaSnack.showError(ctx, result.message);
        }
      }
    } else {
      // Opt-in reporté : tentative silencieuse quand même (sans prompt OS).
      // Enregistre le token si la permission est déjà accordée, sinon
      // réessaiera au prochain login (flag push_optin_asked déjà posé).
      await registerPushToken(ref, requestPermission: false);
    }
  } catch (_) {
    // Push optionnel : jamais bloquant pour le login
  }
}

/// Enregistrement "silencieux" (service indisponible, opt-in déjà demandé,
/// pas de contexte pour la modale) : en debug, un échec affiche quand même
/// sa raison en SnackBar. Sans cela, un build sans FCM_VAPID_KEY reste
/// totalement muet et device_tokens reste vide sans aucune explication.
/// En release : silence conservé (inbox in_app en repli).
Future<void> _registerQuietly(WidgetRef ref) async {
  final result = await ensurePushEnabled(ref);
  if (!result.ok && kDebugMode) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      WiwigaSnack.showError(ctx, result.message);
    }
  }
}

/// Modale d'opt-in standard : bénéfice AVANT le prompt OS.
Future<bool?> _showPushOptInModal(BuildContext context) {
  return NeonModal.show<bool>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                color: NeonColors.primary, size: 28,),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rester informé',
                style: TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Recevez vos gains, résultats de matchs et alertes de sécurité '
          'même quand l\u2019application est fermée. Modifiable à tout moment '
          'dans Notifications > Préférences.',
          style: TextStyle(color: NeonColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'Plus tard',
                onPressed: () => Navigator.pop(context, false),
                variant: NeonButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'Activer',
                onPressed: () => Navigator.pop(context, true),
                variant: NeonButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Modale de guidance quand la permission est bloquée : le prompt OS ne
/// s'afficherait pas, on explique le déblocage manuel puis on réessaie.
/// Retourne true si l'utilisateur a débloqué et veut réessayer.
Future<bool?> _showPushBlockedModal(BuildContext context) {
  final steps = pushBlockedHint;
  return NeonModal.show<bool>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_off_rounded,
                color: NeonColors.warning, size: 28,),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifications bloquées',
                style: TextStyle(
                    color: NeonColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          steps,
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                text: 'Plus tard',
                onPressed: () => Navigator.pop(context, false),
                variant: NeonButtonVariant.outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                text: 'J\u2019ai autorisé',
                onPressed: () => Navigator.pop(context, true),
                variant: NeonButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
