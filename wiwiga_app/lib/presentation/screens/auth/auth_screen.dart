// ============================================================
// Fichier: auth_screen.dart
// Description: Écran d'authentification OTP avec design responsive
// Auteur: WIWIGA Team
// Date: 2026-06-23
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/responsive_builder.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/responsive_button.dart';
import '../widgets/responsive_input.dart';

/// Écran d'authentification OTP
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  /// Envoie le code OTP
  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }
    
    await ref.read(authProvider.notifier).sendOtp(_phoneController.text);
    
    final error = ref.read(authProvider).error;
    if (error == null) {
      setState(() => _otpSent = true);
      _showSuccess('Code OTP envoyé !');
    }
  }
  
  /// Vérifie le code OTP
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showError('Veuillez entrer le code OTP');
      return;
    }
    
    await ref.read(authProvider.notifier).verifyOtp(
      phoneNumber: _phoneController.text,
      otpCode: _otpController.text,
    );
    
    final error = ref.read(authProvider).error;
    if (error == null) {
      // Navigation vers l'écran principal (à implémenter)
      _showSuccess('Connexion réussie !');
    }
  }
  
  /// Affiche un message d'erreur
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
  
  /// Affiche un message de succès
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    return ResponsiveBuilder(
      builder: (context, config) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(config.padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    _buildLogo(config)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: -0.3, end: 0),
                    
                    SizedBox(height: config.spacingLarge),
                    
                    // Titre
                    Text(
                      'Bienvenue sur WIWIGA',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: config.fontSizeLarge,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                    
                    SizedBox(height: config.spacing),
                    
                    Text(
                      _otpSent
                          ? 'Entrez le code OTP reçu par SMS'
                          : 'Connectez-vous avec votre numéro de téléphone',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: config.fontSize,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms),
                    
                    SizedBox(height: config.spacingLarge * 2),
                    
                    // Formulaire
                    _buildForm(config, authState.isLoading),
                    
                    SizedBox(height: config.spacing),
                    
                    // Bouton d'action
                    _buildActionButton(config, authState.isLoading),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Construit le logo
  Widget _buildLogo(ResponsiveConfig config) {
    return Container(
      width: config.iconSize * 4,
      height: config.iconSize * 4,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: Icon(
        Icons.casino,
        size: config.iconSize * 2,
        color: Colors.white,
      ),
    );
  }
  
  /// Construit le formulaire
  Widget _buildForm(ResponsiveConfig config, bool isLoading) {
    return Column(
      children: [
        // Champ téléphone
        if (!_otpSent)
          ResponsiveInput(
            controller: _phoneController,
            label: 'Numéro de téléphone',
            hint: '+237 6XX XXX XXX',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
        
        if (_otpSent) ...[
          SizedBox(height: config.spacing),
          
          // Champ OTP
          ResponsiveInput(
            controller: _otpController,
            label: 'Code OTP',
            hint: '123456',
            icon: Icons.lock,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
        ],
      ],
    );
  }
  
  /// Construit le bouton d'action
  Widget _buildActionButton(ResponsiveConfig config, bool isLoading) {
    return ResponsiveButton(
      onPressed: isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
      height: config.buttonHeight,
      child: isLoading
          ? SizedBox(
              width: config.iconSize,
              height: config.iconSize,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _otpSent ? 'Vérifier' : 'Envoyer le code',
              style: TextStyle(
                fontSize: config.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
