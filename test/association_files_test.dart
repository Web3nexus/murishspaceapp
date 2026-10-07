import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config/deep_links.dart';

/// Cross-checks what the app *claims* against what it can actually *route*.
///
/// The OS trusts these files completely. Android silently falls back to the
/// browser on an `autoVerify` mismatch, and iOS opens the app for any matching
/// path — so a claimed prefix that the parser does not understand is a dead
/// screen for the user, not a graceful fallback to the web page. That failure
/// is invisible in review and only shows up on a real device, which is exactly
/// why it is asserted here.
///
/// These files live outside the Flutter package because they are served by the
/// web deploy, but they describe this app, so they are asserted from its tests.
void main() {
  final repoRoot = _findRepoRoot();
  final manifestPath =
      '$repoRoot/mobile/android/app/src/main/'
      'AndroidManifest.xml';
  final aasaPath =
      '$repoRoot/web/frontend/public/.well-known/'
      'apple-app-site-association';
  // Apple serves `/.well-known/apple-app-site-association` and also probes the
  // root of the host, so `public/apple-app-site-association` ships too. A stale
  // copy of that one silently reinstates the catch-all this suite exists to
  // forbid, so both files are asserted.
  final legacyAasaPath =
      '$repoRoot/web/frontend/public/apple-app-site-association';

  late String manifestXml;
  late Map<String, dynamic> aasa;
  late String aasaRaw;
  late String legacyAasaRaw;

  setUpAll(() {
    manifestXml = File(manifestPath).readAsStringSync();
    aasaRaw = File(aasaPath).readAsStringSync();
    legacyAasaRaw = File(legacyAasaPath).readAsStringSync();
    aasa = jsonDecode(aasaRaw) as Map<String, dynamic>;
  });

  /// A `pathPrefix` and an AASA component spell the same path shape
  /// differently — `/m/` versus `/m/*` — so both are reduced to their bare
  /// first segment before being compared.
  String bare(String path) {
    var value = path;
    if (value.endsWith('/*')) value = value.substring(0, value.length - 2);
    if (value.endsWith('/')) value = value.substring(0, value.length - 1);
    return value;
  }

  List<String> androidPrefixes() => RegExp(
    r'android:pathPrefix="([^"]+)"',
  ).allMatches(manifestXml).map((m) => m.group(1)!).toList();

  /// The `"/"` pattern of every AASA component. Components are objects
  /// (`{"/": "/live/*", "comment": "..."}`), so the pattern is read off each.
  List<String> aasaComponents() {
    final details =
        (aasa['applinks'] as Map<String, dynamic>)['details'] as List;
    final components =
        (details.first as Map<String, dynamic>)['components'] as List;
    return components
        .map((component) => (component as Map<String, dynamic>)['/'] as String)
        .toList();
  }

  group('association files are well formed', () {
    test('the AASA must not claim every path', () {
      // A `{"/": "*"}` component defeats all path scoping below it: the app
      // would swallow every URL on the host, including marketing pages it
      // cannot route.
      expect(
        aasaComponents(),
        isNot(contains('*')),
        reason: 'catch-all component would claim every URL on the host',
      );
    });

    test('components omit the unreliable query wildcard', () {
      // Omitting `query` matches any query string, which is what share links
      // need. `{"?*": "?*"}` is not a reliable Apple wildcard.
      for (final entry
          in (aasa['applinks'] as Map<String, dynamic>)['details'] as List) {
        final components =
            (entry as Map<String, dynamic>)['components'] as List;
        for (final component in components) {
          expect(
            (component as Map<String, dynamic>).containsKey('query'),
            isFalse,
            reason: 'component $component should omit "query"',
          );
        }
      }
    });

    test('both shipped AASA copies are identical', () {
      // Apple probes the host root as well as /.well-known/. One stale copy
      // reinstating a catch-all would undo every rule below.
      expect(
        legacyAasaRaw.replaceAll('\r\n', '\n').trim(),
        aasaRaw.replaceAll('\r\n', '\n').trim(),
        reason:
            'public/apple-app-site-association is out of date with '
            'public/.well-known/apple-app-site-association',
      );
    });

    test('both platforms are declared with autoVerify', () {
      expect(
        RegExp(r'android:autoVerify="true"').allMatches(manifestXml).length,
        greaterThanOrEqualTo(1),
      );
    });
  });

  group('platform parity', () {
    test('every Android-claimed prefix is also claimed on iOS', () {
      final components = aasaComponents();
      final uncovered = <String>[];
      final ios = components.map(bare).toSet();
      for (final prefix in androidPrefixes()) {
        if (!ios.contains(bare(prefix))) uncovered.add(prefix);
      }
      expect(
        uncovered,
        isEmpty,
        reason: 'claimed on Android but not iOS: $uncovered',
      );
    });

    test('every iOS component is also claimed on Android', () {
      final prefixes = androidPrefixes().map(bare).toSet();
      final uncovered = <String>[];
      for (final component in aasaComponents()) {
        if (!prefixes.contains(bare(component))) uncovered.add(component);
      }
      expect(
        uncovered,
        isEmpty,
        reason: 'claimed on iOS but not Android: $uncovered',
      );
    });
  });

  group('claimed paths are routable', () {
    test('every claimed prefix resolves to a real in-app destination', () {
      // A representative id/slug/code stands in for the real value; only the
      // shape matters here, because a wrong first segment is what produces a
      // dead screen.
      const samples = <String, String>{
        '/live': '/live/abc123',
        '/m': '/m/abc-def12-ghi',
        '/meeting': '/meeting/abc-def12-ghi',
        '/meetings': '/meetings/abc-def12-ghi',
        '/e': '/e/42',
        '/events': '/events/42',
        '/p': '/p/7',
        '/products': '/products/7',
        '/chat': '/chat/9',
        '/conversation': '/conversation/9',
        '/u': '/u/ada',
        '/c': '/c/builders',
        '/community': '/community/builders',
        '/communities': '/communities/builders',
        '/l': '/l/ada',
        '/bio': '/bio/ada',
        '/store': '/store/ada',
        '/app/meeting': '/app/meeting/abc-def12-ghi',
        '/app/meetings': '/app/meetings/abc-def12-ghi',
        '/app/conversation': '/app/conversation/9',
        '/app/community': '/app/community/builders',
        '/app/events': '/app/events/42',
      };

      final unroutable = <String>[];
      for (final prefix in androidPrefixes().map(bare).toSet()) {
        final sample = samples[prefix];
        if (sample == null) {
          unroutable.add('$prefix (no known sample)');
          continue;
        }
        if (DeepLinks.resolve(sample).isUnknown) {
          unroutable.add('$prefix -> $sample');
        }
      }
      expect(
        unroutable,
        isEmpty,
        reason:
            'OS claims these paths but the app cannot route them: '
            '$unroutable',
      );
    });
  });
}

/// Walks up from the package directory until the repo root is found.
String _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/web/frontend').existsSync() &&
        Directory('${dir.path}/mobile').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError(
    'Could not locate the repository root from '
    '${Directory.current.path}',
  );
}
