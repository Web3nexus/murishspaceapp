import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/components/app_bottom_sheet.dart';

/// Regression guard for modal bottom sheets under keyboard insets.
///
/// A scroll-controlled sheet is unconstrained, so when the soft keyboard opens
/// it keeps its intrinsic height while the usable area shrinks. Without an
/// explicit `MediaQuery.viewInsets.bottom` the sheet is positioned partly
/// behind the keyboard, and tall sheets are pushed past the top of the screen,
/// which reads as the form "jumping to the top". These tests assert sheet
/// content stays inside the area that is actually visible.
void main() {
  const statusBar = 44.0;
  const keyboard = 300.0;
  const screenHeight = 800.0;

  /// The top edge of the keyboard, i.e. the lowest y a visible pixel can occupy.
  final keyboardTop = screenHeight - keyboard;

  Future<void> pumpAndOpen(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    tester.view.physicalSize = const Size(400, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: statusBar);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('showConfirmation keeps its actions above the keyboard', (tester) async {
    await pumpAndOpen(
      tester,
      (context) => AppBottomSheet.showConfirmation(
        context: context,
        title: 'Remove item',
        message: 'This cannot be undone.',
        confirmText: 'Delete',
      ),
    );

    final confirm = tester.getRect(find.text('Delete'));
    expect(confirm.bottom, lessThanOrEqualTo(keyboardTop),
        reason: 'Confirm button must sit fully above the keyboard');
  });

  testWidgets('showConfirmation stays below the status bar', (tester) async {
    await pumpAndOpen(
      tester,
      (context) => AppBottomSheet.showConfirmation(
        context: context,
        title: 'Remove item',
        message: 'This cannot be undone.',
        confirmText: 'Delete',
      ),
    );

    final sheet = tester.getRect(find.text('Remove item'));
    expect(sheet.top, greaterThanOrEqualTo(statusBar),
        reason: 'Sheet content must not render under the status bar');
  });

  testWidgets('showNotice keeps its actions above the keyboard', (tester) async {
    await pumpAndOpen(
      tester,
      (context) => AppBottomSheet.showNotice(
        context: context,
        title: 'Heads up',
        message: 'Your balance was updated.',
      ),
    );

    final ok = tester.getRect(find.text('Got It'));
    expect(ok.bottom, lessThanOrEqualTo(keyboardTop),
        reason: 'Dismiss button must sit fully above the keyboard');
  });

  testWidgets('showCustom lifts a text field above the keyboard', (tester) async {
    await pumpAndOpen(
      tester,
      (context) => AppBottomSheet.showCustom<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(),
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Say something'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );

    final send = tester.getRect(find.text('Send'));
    expect(send.bottom, lessThanOrEqualTo(keyboardTop),
        reason: 'Sheet content must not be hidden behind the keyboard');

    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(keyboardTop),
        reason: 'Focused text field must be scrolled above the keyboard');
  });
}
