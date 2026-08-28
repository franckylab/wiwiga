import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/wiwiga_logo.dart';
import '../../widgets/loading/wiwiga_progress.dart';
import '../../../data/providers/app_providers.dart';

/// Ecran de demarrage anime WIWIGA
/// 
/// Affiche le logo WIWIGA avec animation de glow,
/// une barre de progression neon, et des particules flottantes.
/// Transition automatique vers auth ou home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Animation logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Animation progression
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Listener: quand l'animation se termine, naviguer automatiquement
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _navigate();
      }
    });

    // Lancer les animations
    _logoController.forward();
    _progressController.forward();

    // Timer pour mise a jour progressive
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _progress = (_progressController.value * 0.8).clamp(0.0, 1.0);
        });
      }
    });
  }

  void _navigate() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _progress = 1.0);

    // Restaurer la session avant de naviguer
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        // Lancer la restauration de session
        await ref.read(authProvider.notifier).restoreSession();
        
        if (!mounted) return;
        
        // Navigation conditionnelle selon le statut auth
        final authState = ref.read(authProvider);
        if (authState.isAuthenticated) {
          context.go('/home');
        } else {
          // Guest ou erreur → aller vers l'écran d'auth
          context.go('/auth');
        }
      } catch (e) {
        if (!mounted) return;
        // En cas d'erreur, aller vers l'écran d'auth
        context.go('/auth');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: NeonGradients.splash,
        ),
        child: Stack(
          children: [
            // Particules flottantes
            const FloatingParticles(particleCount: 15),

            // Contenu principal
            Center(
              child: AnimatedBuilder(
                animation: _logoScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoFade.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo WIWIGA — Q sans cadre (contexte splash 100, W plein fin)
                    const WiwigaLogo(
                      variant: LogoVariant.icon,
                      size: 100,
                      animated: true,
                      withFrame: false,
                    ),
                    const SizedBox(height: 16),
                    // Texte WIWIGA
                    Text(
                      'WIWIGA',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: NeonColors.primary,
                        fontFamily: 'Orbitron',
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: NeonColors.primary.withValues(alpha: 0.6),
                            blurRadius: 16,
                          ),
                          Shadow(
                            color: NeonColors.tokenGold.withValues(alpha: 0.3),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tagline
                    const Text(
                      'Joue. Gagne. Triomphe.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Barre de progression
                    SizedBox(
                      width: 200,
                      child: WiwigaProgressBar(
                        progress: _progress,
                        height: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Texte de statut
                    Text(
                      _getLoadingText(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: NeonColors.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Version en bas
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: NeonColors.textMuted.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLoadingText() {
    if (_progress < 0.3) return 'Initialisation...';
    if (_progress < 0.6) return 'Connexion au serveur...';
    if (_progress < 0.9) return 'Preparation de l\'arene...';
    return 'Bientot pret !';
  }
}
