import 'package:cruise_assist/update/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.parse', () {
    test('parses a bare semver triple', () {
      final v = AppVersion.parse('0.2.0');
      expect(v.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 0);
      expect(v.prerelease, isEmpty);
    });

    test('parses a v-prefixed tag', () {
      final v = AppVersion.parse('v1.4.2');
      expect(v.major, 1);
      expect(v.minor, 4);
      expect(v.patch, 2);
    });

    test('parses an uppercase V prefix', () {
      expect(AppVersion.parse('V2.0.0').major, 2);
    });

    test('treats missing minor and patch as zero', () {
      final v = AppVersion.parse('3');
      expect(v.major, 3);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('treats a missing patch as zero', () {
      final v = AppVersion.parse('v1.2');
      expect(v.minor, 2);
      expect(v.patch, 0);
    });

    test('ignores build metadata', () {
      final v = AppVersion.parse('0.1.0+7');
      expect(v.major, 0);
      expect(v.minor, 1);
      expect(v.patch, 0);
      expect(v.prerelease, isEmpty);
    });

    test('parses a prerelease identifier', () {
      final v = AppVersion.parse('v0.2.0-beta.1');
      expect(v.prerelease, ['beta', '1']);
      expect(v.isPrerelease, isTrue);
    });

    test('parses a prerelease with a hyphenated identifier', () {
      final v = AppVersion.parse('1.0.0-rc-1');
      expect(v.prerelease, ['rc-1']);
    });

    test('trims surrounding whitespace', () {
      expect(AppVersion.parse('  v0.5.0  ').minor, 5);
    });

    test('rejects a non-numeric version', () {
      expect(() => AppVersion.parse('latest'), throwsFormatException);
    });

    test('rejects leading zeroes in a numeric component', () {
      expect(() => AppVersion.parse('01.2.3'), throwsFormatException);
    });

    test('rejects a numeric prerelease identifier with leading zeroes', () {
      expect(() => AppVersion.parse('1.0.0-beta.01'), throwsFormatException);
    });

    test('rejects an empty string', () {
      expect(() => AppVersion.parse(''), throwsFormatException);
    });

    test('tryParse returns null for invalid input', () {
      expect(AppVersion.tryParse('not-a-version'), isNull);
      expect(AppVersion.tryParse('v0.1.0'), isNotNull);
    });
  });

  group('version ordering', () {
    test('a newer patch is greater', () {
      expect(compareVersions('0.1.0', '0.1.1'), lessThan(0));
    });

    test('a newer minor is greater', () {
      expect(compareVersions('0.1.9', '0.2.0'), lessThan(0));
    });

    test('a newer major is greater', () {
      expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
    });

    test('equal versions compare to zero', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('a v prefix does not change precedence', () {
      expect(compareVersions('v1.2.3', '1.2.3'), 0);
    });

    test('build metadata does not change precedence', () {
      expect(compareVersions('1.2.3+1', '1.2.3+99'), 0);
    });

    test('a prerelease sorts below its stable release', () {
      expect(compareVersions('v0.2.0-beta.1', 'v0.2.0'), lessThan(0));
    });

    test('a prerelease sorts below a newer stable release', () {
      expect(compareVersions('v0.2.0-beta.1', 'v0.3.0'), lessThan(0));
    });

    test('a stable release sorts above its prerelease', () {
      expect(compareVersions('v0.2.0', 'v0.2.0-beta.1'), greaterThan(0));
    });

    test('numeric prerelease identifiers compare numerically', () {
      expect(compareVersions('v1.0.0-beta.2', 'v1.0.0-beta.10'), lessThan(0));
    });

    test('numeric prerelease identifiers sort below alphanumeric ones', () {
      // SemVer §11.4.4: numeric identifiers always have lower precedence
      // than alphanumeric identifiers.
      expect(compareVersions('v1.0.0-1', 'v1.0.0-alpha'), lessThan(0));
    });

    test('alphanumeric prerelease identifiers compare lexically', () {
      expect(compareVersions('v1.0.0-alpha', 'v1.0.0-beta'), lessThan(0));
    });

    test('a longer prerelease chain sorts above a shorter prefix', () {
      expect(compareVersions('v1.0.0-beta', 'v1.0.0-beta.1'), lessThan(0));
    });

    test('two versions differing only in major compare by major', () {
      expect(compareVersions('2.0.0', '10.0.0'), lessThan(0));
    });

    test('equality ignores a leading v', () {
      expect(AppVersion.parse('v1.2.3'), AppVersion.parse('1.2.3'));
    });

    test('hashCode matches for equal versions', () {
      expect(
        AppVersion.parse('v1.2.3').hashCode,
        AppVersion.parse('1.2.3+9').hashCode,
      );
    });

    test('toString omits a prerelease when there is none', () {
      expect(AppVersion.parse('v1.2.3').toString(), '1.2.3');
    });

    test('toString includes the prerelease chain', () {
      expect(AppVersion.parse('v1.2.3-beta.1').toString(), '1.2.3-beta.1');
    });
  });
}
