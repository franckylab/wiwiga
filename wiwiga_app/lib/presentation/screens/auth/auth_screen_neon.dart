// ============================================================
// Fichier: auth_screen_neon.dart
// Description: Écran d'authentification connecté à l'API réelle
//              OTP SMS + gestion état via authProvider
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran d'authentification redesigné avec style néon gaming
/// 
/// Flux :
/// 1. L'utilisateur entre son numéro de téléphone
/// 2. Un OTP est envoyé par SMS (POST /api/auth/send-otp)
/// 3. L'utilisateur entre le code reçu
/// 4. Vérification (POST /api/auth/verify-otp) → tokens + session
/// 5. Navigation vers /home (ou redirectTo si intent)
class AuthScreenNeon extends ConsumerStatefulWidget {
  const AuthScreenNeon({super.key});

  @override
  ConsumerState<AuthScreenNeon> createState() => _AuthScreenNeonState();
}

class _AuthScreenNeonState extends ConsumerState<AuthScreenNeon>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isOtpSent = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: NeonAnimations.transition,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),);
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Envoie l'OTP au numéro fourni
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        _showError(authState.error!);
        return;
      }
      
      setState(() {
        _isOtpSent = true;
        _countdown = 60;
      });
      
      _startCountdown();
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Vérifie l'OTP saisi
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Le code OTP doit contenir 6 chiffres');
      return;
    }

    try {
      await ref.read(authProvider.notifier).verifyOtp(
        phoneNumber: _phoneController.text.trim(),
        otpCode: otp,
      );
      
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        _navigateAfterAuth();
      } else if (authState.error != null) {
        _showError(authState.error!);
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Navigation après auth réussie : redirectTo ou /home
  void _navigateAfterAuth() {
    if (!mounted) return;
    
    final authState = ref.read(authProvider);
    final redirectTo = authState.redirectTo;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connexion réussie !', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: NeonColors.success,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Naviguer vers l'intent original ou /home
    Future.microtask(() {
      if (mounted) {
        context.go(redirectTo ?? '/home');
      }
    });
  }

  /// Affiche un message d'erreur
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: NeonColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Démarre le countdown de 60s pour renvoyer l'OTP
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Si déjà authentifié (retour depuis un autre écran), naviguer
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateAfterAuth();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo
                  const _LogoSection(),
                  
                  const SizedBox(height: 48),
                  
                  // Titre
                  Text(
                    _isOtpSent ? 'VÉRIFICATION' : 'BIENVENUE',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.primary,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isOtpSent
                        ? 'Entrez le code reçu par SMS'
                        : 'Connectez-vous pour commencer à jouer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: NeonColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Formulaire
                  if (!_isOtpSent) ...[
                    _PhoneForm(
                      controller: _phoneController,
                      isLoading: isLoading,
                      onSubmit: _sendOtp,
                    ),
                  ] else ...[
                    _OtpForm(
                      controller: _otpController,
                      isLoading: isLoading,
                      countdown: _countdown,
                      onVerify: _verifyOtp,
                      onResend: _sendOtp,
                      onBack: () => setState(() => _isOtpSent = false),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Footer
                  const _FooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: NeonGradients.cta,
          boxShadow: [
            BoxShadow(
              color: NeonColors.primary.withValues(alpha: NeonGlow.opacityMedium),
              blurRadius: NeonGlow.blurMedium,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.gamepad,
          size: 64,
          color: NeonColors.background,
        ),
      ),
    );
  }
}

class _PhoneForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _PhoneForm({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NeonInput(
          label: 'Numéro de téléphone',
          hint: '+237 6XX XXX XXX',
          controller: controller,
          keyboardType: TextInputType.phone,
          icon: Icons.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre numéro';
            }
            if (value.length < 9) {
              return 'Numéro invalide';
            }
            return null;
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        
        const SizedBox(height: 32),
        
        NeonButton(
          text: 'RECEVOIR LE CODE',
          onPressed: isLoading ? () {} : onSubmit,
          isLoading: isLoading,
          icon: Icons.send,
          width: double.infinity,
        ),
      ],
    );
  }
}

class _OtpForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final int countdown;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _OtpForm({
    required this.controller,
    required this.isLoading,
    required this.countdown,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bouton retour
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16, color: NeonColors.textSecondary),
            label: const Text(
              'Changer de numéro',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
        
        NeonInput(
          label: 'Code de vérification',
          hint: '000000',
          controller: controller,
          keyboardType: TextInputType.number,
          icon: Icons.lock_outline,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        
        const SizedBox(height: 24),
        
        NeonButton(
          text: 'VÉRIFIER',
          onPressed: isLoading ? () {} : onVerify,
          isLoading: isLoading,
          icon: Icons.check_circle,
          width: double.infinity,
        ),
        
        const SizedBox(height: 24),
        
        if (countdown > 0)
          Text(
            'Renvoyer le code dans $countdown s',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          )
        else
          TextButton(
            onPressed: onResend,
            child: const Text(
              'Renvoyer le code',
              style: TextStyle(
                color: NeonColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: NeonColors.border),
        const SizedBox(height: 16),
        const Text(
          'En continuant, vous acceptez nos',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: const Text(
                'Conditions d\'utilisation',
                style: TextStyle(
                  color: NeonColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const Text(
              'et',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Politique de confidentialité',
                style: TextStyle(
                  color: NeonColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
