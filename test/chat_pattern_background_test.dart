import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/components/chat_pattern_background.dart';

/// Verifies the chat doodle backdrop behaves in both themes.
///
/// The artwork is light-blue ink, so the widget recolours it per theme. These
/// tests assert the pattern is present, sits behind the message content, and
/// never fades the content itself.
void main() {
  Widget harness({required Brightness brightness}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: ChatPatternBackground(
          child: Center(
            child: Text('message content', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the pattern behind the child', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.light));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('message content'), findsOneWidget);
  });

  testWidgets('child renders above the pattern', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.light));
    await tester.pump();

    final stack = tester.widget<Stack>(find.byType(Stack).first);
    final types = stack.children
        .whereType<Widget>()
        .map((w) => w.runtimeType)
        .toList();
    expect(types.indexOf(Image), lessThan(types.indexOf(Center)),
        reason: 'Pattern must be painted underneath the message content');
  });

  testWidgets('message content is not faded by the pattern', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.light));
    await tester.pump();

    // Walk the real ancestor chain of the content. Anything that dims it would
    // show up here as an Opacity ancestor below 1.
    final dimming = <double>[];
    tester.element(find.text('message content')).visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Opacity && widget.opacity < 1.0) {
        dimming.add(widget.opacity);
      }
      return true;
    });

    expect(dimming, isEmpty,
        reason: 'Opacity must be applied to the pattern, not the message list');
  });

  testWidgets('pattern ink is light in dark mode', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.dark));
    await tester.pump();

    final ink = tester.widget<Image>(find.byType(Image)).color!;
    expect(ink.computeLuminance(), greaterThan(0.5),
        reason: 'Light ink is needed to show against a dark chat background');
  });

  testWidgets('pattern ink is dark in light mode', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.light));
    await tester.pump();

    final ink = tester.widget<Image>(find.byType(Image)).color!;
    expect(ink.computeLuminance(), lessThan(0.3),
        reason: 'Dark ink is needed to show against a light chat background');
  });

  testWidgets('layout is not driven by the pattern image', (tester) async {
    await tester.pumpWidget(harness(brightness: Brightness.light));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(ChatPatternBackground));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
  });
}
