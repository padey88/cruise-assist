import 'package:flutter_test/flutter_test.dart';
import 'package:cruise_assist/platform/device_info.dart';

void main() {
  group('DeviceCompatibility', () {
    test('supported device with high SDK', () {
      final info = DeviceInfo(
        model: 'Xperia 10 IV',
        manufacturer: 'Sony',
        sdk: '33',
        abi: 'arm64-v8a',
        androidVersion: '13',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.verdict, CompatibilityVerdict.supported);
      expect(c.summary, contains('Sony'));
      expect(c.summary, contains('Xperia'));
      expect(c.summary, contains('supported'));
      expect(c.notes, anyElement(contains('USB AOA supported')));
      expect(c.notes, anyElement(contains('notification permission')));
    });

    test('supported device with SDK 26', () {
      final info = DeviceInfo(
        model: 'Galaxy A10',
        manufacturer: 'Samsung',
        sdk: '26',
        abi: 'armeabi-v7a',
        androidVersion: '8.0',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.verdict, CompatibilityVerdict.supported);
      expect(c.notes, anyElement(contains('Samsung')));
    });

    test('unsupported device with low SDK', () {
      final info = DeviceInfo(
        model: 'Old Phone',
        manufacturer: 'Generic',
        sdk: '24',
        abi: 'armeabi-v7a',
        androidVersion: '7.0',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.verdict, CompatibilityVerdict.unsupported);
      expect(c.summary, contains('unsupported'));
    });

    test('unknown when SDK is 0', () {
      final info = DeviceInfo(
        model: 'Unknown',
        manufacturer: 'Unknown',
        sdk: '0',
        abi: 'unknown',
        androidVersion: 'unknown',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.verdict, CompatibilityVerdict.unknown);
    });

    test('unknown when SDK is non-numeric', () {
      final info = DeviceInfo(
        model: 'Test',
        manufacturer: 'Test',
        sdk: 'abc',
        abi: 'x86_64',
        androidVersion: 'test',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.verdict, CompatibilityVerdict.unknown);
    });

    test('DeviceInfo.unknown has safe defaults', () {
      expect(DeviceInfo.unknown.model, 'Unknown');
      expect(DeviceInfo.unknown.sdk, '0');
    });

    test('displayName capitalises manufacturer', () {
      final info = DeviceInfo(
        model: 'Pixel 8',
        manufacturer: 'google',
        sdk: '34',
        abi: 'arm64-v8a',
        androidVersion: '14',
      );
      expect(info.displayName, 'Google Pixel 8');
    });

    test('SDK 29+ notes foreground service type', () {
      final info = DeviceInfo(
        model: 'Test',
        manufacturer: 'Test',
        sdk: '29',
        abi: 'arm64-v8a',
        androidVersion: '10',
      );
      final c = DeviceCompatibility.evaluate(info);
      expect(c.notes, anyElement(contains('connectedDevice')));
    });
  });

  group('SmartLinkProfile', () {
    test('ativaAv has expected transport', () {
      expect(SmartLinkProfile.ativaAv.transport, contains('USB AOA'));
    });

    test('ativaAv lists unknowns', () {
      expect(SmartLinkProfile.ativaAv.unknowns, isNotEmpty);
      expect(SmartLinkProfile.ativaAv.resolution, contains('unknown'));
      expect(SmartLinkProfile.ativaAv.protocol, contains('unknown'));
    });
  });
}
