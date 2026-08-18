import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/presentation/screens/profile/profile_screen_enhanced.dart';

void main() {
  group('ProfileScreenEnhanced', () {
    testWidgets('le widget existe', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ProfileScreenEnhanced()),
        ),
      );
      expect(find.byType(ProfileScreenEnhanced), findsOneWidget);
    });
  });
}
