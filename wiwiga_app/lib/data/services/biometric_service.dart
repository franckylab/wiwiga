import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../../core/errors/error_handler.dart';

/// Service d'authentification biométrique
///
/// Permet l'authentification par empreinte digitale ou reconnaissance faciale.
/// Les données biométriques ne sont jamais stockées, seul le résultat de
/// l'authentification est utilisé pour déverrouiller l'application.
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Vérifie si l'appareil supporte l'authentification biométrique
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      _logger.e('Erreur vérification support biométrique: $e');
      return false;
    }
  }

  /// Vérifie si l'appareil peut authentifier (biométrie disponible)
  Future<bool> canCheckBiometrics() async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      _logger.e('Erreur vérification biométrie disponible: $e');
      return false;
    }
  }

  /// Authentifie l'utilisateur avec la biométrie
  ///
  /// Retourne true si l'authentification a réussi, false sinon.
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour accéder à WIWIGA',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet le fallback vers le code de l'appareil
        ),
      );

      _logger.i('Authentification biométrique: ${authenticated ? "succès" : "échec"}');
      return authenticated;
    } catch (e) {
      _logger.e('Erreur authentification biométrique: $e');
      return false;
    }
  }

  /// Active/désactive l'authentification biométrique
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: enabled.toString(),
      );
      _logger.i('Biométrie ${enabled ? "activée" : "désactivée"}');
    } catch (e) {
      _logger.e('Erreur sauvegarde préférence biométrie: $e');
    }
  }

  /// Vérifie si l'authentification biométrique est activée
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      _logger.e('Erreur lecture préférence biométrie: $e');
      return false;
    }
  }

  /// Récupère les types de biométrie disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      _logger.e('Erreur récupération biométries disponibles: $e');
      return [];
    }
  }

  /// Authentifie et retourne un message d'erreur si échec
  Future<BiometricAuthResult> authenticateWithResult({
    String reason = 'Authentifiez-vous pour accéder à WIWIGA',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return BiometricAuthResult(
          success: false,
          error: 'Appareil non supporté',
        );
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return BiometricAuthResult(
          success: false,
          error: 'Aucune biométrie enregistrée sur cet appareil',
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        return BiometricAuthResult(success: true);
      } else {
        return BiometricAuthResult(
          success: false,
          error: 'Authentification échouée',
        );
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'BiometricService.authenticateWithResult');
      return BiometricAuthResult(
        success: false,
        error: ErrorHandler.userMessage(e),
      );
    }
  }
}

/// Résultat de l'authentification biométrique
class BiometricAuthResult {
  final bool success;
  final String? error;

  BiometricAuthResult({
    required this.success,
    this.error,
  });
}
