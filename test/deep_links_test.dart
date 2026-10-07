import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config/deep_links.dart';

/// Guards the deep-link contract shared by the app, the web SPA and the Laravel
/// link resolver.
///
/// The failure this protects against is silent: if the parser stops recognising
/// a shape the app still claims in its association files, the OS happily opens
/// the app and the user lands on a dead screen instead of the web page. So every
/// claimed prefix has to resolve to something routable.
void main() {
  group('canonical builders', () {
    test('build the documented paths', () {
      expect(DeepLinks.live('abc-123'), '/live/abc-123');
      expect(DeepLinks.meeting('abc-def12-ghi'), '/m/abc-def12-ghi');
      expect(DeepLinks.event(42), '/e/42');
      expect(DeepLinks.product('d_7'), '/p/d_7');
      expect(DeepLinks.chat(9), '/chat/9');
      expect(DeepLinks.profile('ada'), '/u/ada');
      expect(DeepLinks.community('builders'), '/c/builders');
      expect(DeepLinks.linkInBio('ada'), '/l/ada');
      expect(DeepLinks.storefront('ada'), '/store/ada');
    });

    test('percent-encode hostile segments', () {
      expect(DeepLinks.profile('a/b'), '/u/a%2Fb');
      expect(DeepLinks.live('../etc'), contains('%2F'));
    });
  });

  group('normalise', () {
    test('accepts https, custom scheme and relative forms', () {
      for (final raw in [
        'https://web.murihspace.com/live/abc?x=1',
        'murihspace://live/abc',
        'murihspace:///live/abc',
        'murihspace:live/abc',
        '/live/abc',
        'web.murihspace.com/live/abc',
      ]) {
        expect(
          DeepLinks.normalise(raw).path,
          '/live/abc',
          reason: 'failed for "$raw"',
        );
      }
    });

    test('preserves the query string', () {
      expect(
        DeepLinks.normalise('https://web.murihspace.com/p/7?ref=abc').query,
        'ref=abc',
      );
    });

    test('accepts every MurihSpace host, including subdomains', () {
      for (final host in [
        'murihspace.com',
        'web.murihspace.com',
        'staging.murihspace.com',
        'live.murihspace.com',
      ]) {
        expect(
          DeepLinks.normalise('https://$host/live/abc').path,
          '/live/abc',
          reason: 'failed for $host',
        );
      }
    });

    test('rejects a foreign host that merely shares a path shape', () {
      // An outbound URL like this must not resolve as our content, or a
      // crafted link could drive the user into a MurihSpace screen for
      // something they never opened from us.
      for (final host in [
        'example.com',
        'evil.example',
        'notmurihspace.com',
        'murihspace.com.evil.example',
      ]) {
        expect(
          DeepLinks.resolve('https://$host/live/abc').isUnknown,
          isTrue,
          reason: 'should have been rejected: $host',
        );
      }
    });
  });

  group('resolve', () {
    test('canonical paths resolve to themselves', () {
      final cases = <String, DeepLinkType>{
        '/live/abc': DeepLinkType.live,
        '/m/abc-def12-ghi': DeepLinkType.meeting,
        '/e/42': DeepLinkType.event,
        '/p/7': DeepLinkType.product,
        '/u/ada': DeepLinkType.profile,
        '/c/builders': DeepLinkType.community,
        '/l/ada': DeepLinkType.linkInBio,
        '/store/ada': DeepLinkType.storefront,
      };
      cases.forEach((path, type) {
        final target = DeepLinks.resolve(path);
        expect(target.type, type, reason: 'wrong type for $path');
        expect(
          target.appRoute,
          path,
          reason: '$path should round-trip unchanged',
        );
      });
    });

    test('/chat is the share path for the in-app conversation route', () {
      // The link that gets shared is /chat/{id}; the in-app destination it
      // normalises to is /app/conversation/{id}. Both are claimed by the OS, so
      // the hand-off has to resolve rather than fall through.
      expect(DeepLinks.resolve('/chat/9').type, DeepLinkType.chat);
      expect(DeepLinks.resolve('/chat/9').appRoute, '/app/conversation/9');
      expect(
        DeepLinks.resolve('/app/conversation/9').appRoute,
        '/app/conversation/9',
      );
    });

    test('legacy aliases normalise to the canonical route', () {
      // Each of these is claimed in AndroidManifest.xml and the AASA, so if the
      // parser forgot one, the app would open a link it cannot route.
      final cases = <String, String>{
        '/meeting/abc-def12-ghi': '/m/abc-def12-ghi',
        '/meetings/abc-def12-ghi': '/m/abc-def12-ghi',
        '/events/42': '/e/42',
        '/products/7': '/p/7',
        '/conversation/9': '/app/conversation/9',
        '/communities/builders': '/c/builders',
        '/bio/ada': '/l/ada',
        '/app/meeting/abc-def12-ghi': '/m/abc-def12-ghi',
        '/app/conversation/9': '/app/conversation/9',
      };
      cases.forEach((alias, canonical) {
        expect(
          DeepLinks.resolve(alias).appRoute,
          canonical,
          reason: 'wrong canonical form for $alias',
        );
      });
    });

    test('unknown paths are not silently mapped to content', () {
      for (final path in ['/', '/settings', '/legal/privacy', '/dashboard']) {
        expect(
          DeepLinks.resolve(path).isUnknown,
          isTrue,
          reason: '$path must not resolve to a content route',
        );
      }
    });

    test('meeting route "instant" is not treated as a room code', () {
      expect(DeepLinks.resolve('/m/instant').isUnknown, isTrue);
    });
  });

  group('every claimed prefix is routable', () {
    test('each OS-claimed first segment resolves or is a shell route', () {
      // Mirrors appClaimedPrefixes, which must stay aligned with
      // AndroidManifest.xml and apple-app-site-association.
      const claimed = [
        '/live/abc',
        '/m/abc-def12-ghi',
        '/e/1',
        '/p/1',
        '/chat/1',
        '/u/ada',
        '/c/builders',
        '/l/ada',
        '/store/ada',
      ];
      for (final path in claimed) {
        expect(
          DeepLinks.resolve(path).isUnknown,
          isFalse,
          reason: 'claimed path $path does not resolve',
        );
      }
    });
  });

  group('sanitiseReturnTo', () {
    test('accepts canonical in-app destinations', () {
      for (final path in [
        '/live/abc',
        '/m/abc-def12-ghi',
        '/e/42',
        '/p/d_7',
        '/u/ada',
        '/c/builders',
        '/store/ada',
        '/app/home',
      ]) {
        expect(
          DeepLinks.sanitiseReturnTo(path),
          path,
          reason: 'should be returnable: $path',
        );
      }
    });

    test('rejects off-origin and malformed targets', () {
      for (final hostile in [
        'https://evil.example/steal',
        '//evil.example/steal',
        '/\\evil.example',
        'javascript:alert(1)',
        'app/home',
        '',
        '   ',
      ]) {
        expect(
          DeepLinks.sanitiseReturnTo(hostile),
          isNull,
          reason: 'should be rejected: "$hostile"',
        );
      }
    });

    test('caps length', () {
      expect(DeepLinks.sanitiseReturnTo('/u/${'a' * 4000}'), isNull);
    });

    test('null in, null out', () {
      expect(DeepLinks.sanitiseReturnTo(null), isNull);
    });
  });

  group('live token codec', () {
    // Tokens are resolved server-side via /live/resolve/{token}, so the client's
    // only job is to emit a value that is URL safe and opaque. What it must not
    // do is leak raw ids, which is the whole point of the encoding.
    test('tokens are URL safe — no padding or reserved characters', () {
      for (final token in [
        DeepLinks.encodeLiveToken(1),
        DeepLinks.encodeLiveToken(123, hostUserId: 45),
        DeepLinks.encodeLiveToken(999999),
      ]) {
        expect(token, isNot(contains('=')));
        expect(token, isNot(contains('+')));
        expect(token, isNot(contains('/')));
      }
    });

    test('encodes the stream and host id rather than leaking them', () {
      final token = DeepLinks.encodeLiveToken(123, hostUserId: 45);
      expect(token, isNot(contains('123')));
      expect(token, isNot(contains('45')));
    });

    test('distinct id pairs produce distinct tokens', () {
      expect(
        DeepLinks.encodeLiveToken(1, hostUserId: 2),
        isNot(DeepLinks.encodeLiveToken(2, hostUserId: 1)),
      );
    });

    test('is deterministic, so the same share always yields the same link', () {
      expect(
        DeepLinks.encodeLiveToken(7, hostUserId: 8),
        DeepLinks.encodeLiveToken(7, hostUserId: 8),
      );
    });
  });
}
