// ============================================================
// Fichier: app_storage.dart
// Description: Stockage hybride sécurisé avec fallback LAN-IP
// Auteur: WIWIGA Team - Fix LAN 192.168.0.100 -> 192.168.0.109
// Date: 2026-08-29
// ============================================================
// CONTEXTE DU BUG LAN:
// - FlutterSecureStorage sur Web utilise window.crypto.subtle (Web Crypto API)
// - Cette API exige SecureContext (HTTPS ou localhost/127.0.0.1)
// - http://192.168.0.100 n'est PAS SecureContext -> crypto.subtle == null
// - Les appels _storage.write() lancent une exception silencieuse
// - Les tokens ne sont jamais sauvegardés -> login semble échouer
//
// SOLUTION:
// - Wrapper hybride: tente FlutterSecureStorage, en cas d'échec
//   bascule silencieusement vers SharedPreferences (localStorage plain)
// - SharedPreferences sur Web utilise window.localStorage sans crypto,
//   donc fonctionne sur http://192.168.x.x
// - Préfixe fallback pour éviter collisions
// - Interface 100% compatible avec l'ancien ApiService
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage hybride: SecureStorage avec fallback SharedPreferences
/// 
/// Utilisation identique à FlutterSecureStorage mais résilient
/// aux contextes non-secure (LAN http).
class AppStorage {
  final FlutterSecureStorage _secure;
  static const _fallbackPrefix = 'wiwiga_fb_';

  // Cache SharedPreferences pour éviter re-instanciation
  SharedPreferences? _prefsCache;

  AppStorage({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  Future<SharedPreferences> _prefs() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!;
  }

  // ========================================
  // LECTURE
  // ========================================

  Future<String?> read({required String key}) async {
    // 1. Tenter SecureStorage d'abord
    try {
      final val = await _secure.read(key: key);
      if (val != null) return val;
      // Si null, vérifier fallback (migration depuis fallback)
      if (kIsWeb) {
        try {
          final prefs = await _prefs();
          return prefs.getString('$_fallbackPrefix$key');
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (e) {
      // Echec SecureStorage (insecure context, crypto.subtle null)
      debugPrint('[AppStorage] Secure read failed for $key, fallback: $e');
      try {
        final prefs = await _prefs();
        return prefs.getString('$_fallbackPrefix$key');
      } catch (e2) {
        debugPrint('[AppStorage] Fallback read also failed: $e2');
        return null;
      }
    }
  }

  // ========================================
  // ECRITURE
  // ========================================

  Future<void> write({required String key, required String value}) async {
    try {
      await _secure.write(key: key, value: value);
      // Nettoyer fallback si on a réussi en secure (évite doublons)
      if (kIsWeb) {
        try {
          final prefs = await _prefs();
          if (prefs.containsKey('$_fallbackPrefix$key')) {
            await prefs.remove('$_fallbackPrefix$key');
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AppStorage] Secure write failed for $key, using fallback: $e');
      try {
        final prefs = await _prefs();
        await prefs.setString('$_fallbackPrefix$key', value);
        debugPrint('[AppStorage] Fallback write OK for $key');
      } catch (e2) {
        debugPrint('[AppStorage] Fallback write failed: $e2');
        rethrow;
      }
    }
  }

  // ========================================
  // SUPPRESSION
  // ========================================

  Future<void> delete({required String key}) async {
    // Supprimer des deux storages pour être sûr
    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('[AppStorage] Secure delete failed for $key: $e');
    }
    try {
      final prefs = await _prefs();
      await prefs.remove('$_fallbackPrefix$key');
      await prefs.remove(key); // au cas où ancien format sans prefix
    } catch (_) {}
  }

  // ========================================
  // AUTRES METHODES
  // ========================================

  Future<bool> containsKey({required String key}) async {
    try {
      final has = await _secure.containsKey(key: key);
      if (has) return true;
    } catch (_) {}
    try {
      final prefs = await _prefs();
      return prefs.containsKey('$_fallbackPrefix$key') || prefs.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _secure.readAll();
    } catch (e) {
      debugPrint('[AppStorage] readAll secure failed: $e, fallback');
      try {
        final prefs = await _prefs();
        final map = <String, String>{};
        for (final k in prefs.getKeys()) {
          if (k.startsWith(_fallbackPrefix)) {
            final v = prefs.getString(k);
            if (v != null) map[k.substring(_fallbackPrefix.length)] = v;
          }
        }
        return map;
      } catch (_) {
        return {};
      }
    }
  }

  Future<void> deleteAll() async {
    try {
      await _secure.deleteAll();
    } catch (_) {}
    try {
      final prefs = await _prefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_fallbackPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Diagnostic: teste si le stockage sécurisé fonctionne dans ce contexte
  Future<Map<String, dynamic>> diagnose() async {
    const testKey = '__wiwiga_storage_diag__';
    const testVal = 'diag_ok';
    final result = <String, dynamic>{
      'isWeb': kIsWeb,
      'platform': defaultTargetPlatform.toString(),
    };
    try {
      await _secure.write(key: testKey, value: testVal);
      final rv = await _secure.read(key: testKey);
      await _secure.delete(key: testKey);
      result['secure_storage'] = rv == testVal ? 'ok' : 'mismatch:$rv';
    } catch (e) {
      result['secure_storage'] = 'failed: $e';
      result['fallback_used'] = true;
      try {
        final prefs = await _prefs();
        await prefs.setString('$_fallbackPrefix$testKey', testVal);
        final rv = prefs.getString('$_fallbackPrefix$testKey');
        await prefs.remove('$_fallbackPrefix$testKey');
        result['fallback'] = rv == testVal ? 'ok' : 'mismatch:$rv';
      } catch (e2) {
        result['fallback'] = 'failed: $e2';
      }
    }
    return result;
  }
}
