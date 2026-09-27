import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/components/live_stream_top_header.dart';

/// Regression guard for the live stream top header overflow.
///
/// The brand logo added to the header is wide, and the viewer count / wallet
/// balance grow with content, so a naive Row could push the share and close
/// controls off-screen on narrow devices. These tests assert the header lays out
/// without a RenderFlex overflow at a range of widths, and that the two controls
/// that must always stay reachable remain on-screen and hittable.
void main() {
  Widget harness({required double width, int viewerCount = 12, num coins = 250}) {    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: LiveStreamTopHeader(
              // The real widget loads a PNG asset; a transparent 1x1 keeps the
              // test focused on layout rather than asset loading.
              logoAsset: 'assets/images/murihspace-live-logo.png',
              viewerCount: viewerCount,
              coinBalance: coins,
              onShare: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
  }

  const widths = <double>[240, 280, 300, 320, 330, 360, 390, 414, 768];

  testWidgets('header never overflows across every device width', (
    tester,
  ) async {
    // Every 5px step across the realistic width range, so a threshold mistake in
    // either direction shows up as a failure rather than a lucky pass.
    for (var width = 120.0; width <= 820.0; width += 5) {
      await tester.pumpWidget(harness(width: width));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'header overflowed at width $width',
      );
    }
  });

  testWidgets('header never overflows with large content', (tester) async {
    for (var width = 120.0; width <= 820.0; width += 5) {
      await tester.pumpWidget(
        harness(width: width, viewerCount: 9876543, coins: 98765432),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'header overflowed at width $width with large counts',
      );
    }
  });

  testWidgets('share and close stay within the visible width', (
    tester,
  ) async {
    for (var width = 120.0; width <= 820.0; width += 5) {
      await tester.pumpWidget(
        harness(width: width, viewerCount: 9876543, coins: 98765432),
      );
      await tester.pump();

      for (final icon in <IconData>[
        Icons.share_rounded,
        Icons.close_rounded,
      ]) {
        final finder = find.byIcon(icon);
        expect(finder, findsOneWidget, reason: '$icon missing at width $width');

        final box = tester.getRect(finder);
        expect(
          box.right,
          lessThanOrEqualTo(width),
          reason: '$icon overflows past the right edge at width $width',
        );
        expect(
          box.left,
          greaterThanOrEqualTo(0),
          reason: '$icon starts before the left edge at width $width',
        );
      }
    }
  });

  testWidgets('elements are dropped in priority order as width shrinks', (
    tester,
  ) async {
    Future<void> pumpAt(double width) async {
      await tester.pumpWidget(
        harness(width: width, viewerCount: 42, coins: 250),
      );
      await tester.pump();
    }

    // Full layout: logo, LIVE, viewer count and wallet balance.
    await pumpAt(430);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('250 MSH'), findsOneWidget);

    // Logo drops first.
    await pumpAt(400);
    expect(find.byType(Image), findsNothing);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('250 MSH'), findsOneWidget);

    // Viewer count drops next.
    await pumpAt(330);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('42'), findsNothing);
    expect(find.text('250'), findsOneWidget);

    // Wallet drops before the controls.
    await pumpAt(260);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // The controls always survive.
    await pumpAt(120);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('share and close are tappable on the narrowest width', (
    tester,
  ) async {
    var shareTapped = 0;
    var closeTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: LiveStreamTopHeader(
                logoAsset: 'assets/images/murihspace-live-logo.png',
                viewerCount: 5,
                coinBalance: 10,
                onShare: () => shareTapped++,
                onClose: () => closeTapped++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.share_rounded));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(shareTapped, 1);
    expect(closeTapped, 1);
  });
}
