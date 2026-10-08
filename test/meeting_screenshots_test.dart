import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/screens/conference_meeting_screen.dart';

/// Visual captures of the meeting green room under the On-air desk world.
///
/// Run with `flutter test --update-goldens test/meeting_screenshots_test.dart`
/// to regenerate. The connected room needs a live LiveKit session, so it is
/// not covered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The auth provider auto-logs-in on first read; there is no secure storage
  // implementation on the test binding, so answer with "no stored session".
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  secureStorage.setMockMethodCallHandler((_) async => null);
  Future<void> capture(
    WidgetTester tester, {
    required Brightness brightness,
    required Size size,
    required String golden,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: const ConferenceMeetingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ConferenceMeetingScreen), findsOneWidget);
    await expectLater(
      find.byType(ConferenceMeetingScreen),
      matchesGoldenFile(golden),
    );
  }

  testWidgets('green room — phone, dark', (tester) async {
    await capture(
      tester,
      brightness: Brightness.dark,
      size: const Size(390, 844),
      golden: 'goldens/meeting_prejoin_phone_dark.png',
    );
  });

  testWidgets('green room — phone, light', (tester) async {
    await capture(
      tester,
      brightness: Brightness.light,
      size: const Size(390, 844),
      golden: 'goldens/meeting_prejoin_phone_light.png',
    );
  });

  testWidgets('green room — tablet, dark', (tester) async {
    await capture(
      tester,
      brightness: Brightness.dark,
      size: const Size(1024, 1366),
      golden: 'goldens/meeting_prejoin_tablet_dark.png',
    );
  });
}
