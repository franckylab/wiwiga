import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';

/// Provider du service biométrique
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// Provider de l'état de la biométrie (disponible et activée)
final biometricStateProvider = FutureProvider<BiometricState>((ref) async {
  final service = ref.watch(biometricServiceProvider);
  final isSupported = await service.isDeviceSupported();
  final canCheck = await service.canCheckBiometrics();
  final isEnabled = await service.isBiometricEnabled();
  final availableBiometrics = await service.getAvailableBiometrics();

  return BiometricState(
    isSupported: isSupported,
    canCheck: canCheck,
    isEnabled: isEnabled,
    availableBiometrics: availableBiometrics,
  );
});

/// État de la biométrie
class BiometricState {
  final bool isSupported;
  final bool canCheck;
  final bool isEnabled;
  final List<dynamic> availableBiometrics;

  BiometricState({
    required this.isSupported,
    required this.canCheck,
    required this.isEnabled,
    required this.availableBiometrics,
  });

  /// Si la biométrie est utilisable (supportée, disponible et activée)
  bool get isAvailable => isSupported && canCheck && isEnabled;
}
