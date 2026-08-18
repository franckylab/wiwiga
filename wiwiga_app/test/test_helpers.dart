// ============================================================
// Fichier: test_helpers.dart
// Description: Helpers partagés pour les tests widget WIWIGA
//              Fournit les overrides de providers nécessaires
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget with ProviderScope + MaterialApp for testing.
/// Use [overrides] to provide mock providers.
Widget buildTestWidget(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

/// Pumps and settles, ignoring transient errors from async providers.
Future<void> pumpAndSettleSafe(WidgetTester tester) async {
  await tester.pumpWidget(Container()); // reset
  await tester.pumpAndSettle();
}
