import 'package:flutter_test/flutter_test.dart';
import 'package:wiwiga/presentation/screens/settings/settings_screen.dart';

void main() {
  test('SettingsScreen widget class exists', () {
    // Verify the SettingsScreen class can be instantiated
    const screen = SettingsScreen();
    expect(screen, isA<SettingsScreen>());
  });
}
