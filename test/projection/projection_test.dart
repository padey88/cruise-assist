import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cruise_assist/projection/projection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectionState', () {
    test('enum has all expected values', () {
      expect(ProjectionState.values, containsAll([
        ProjectionState.unavailable,
        ProjectionState.idle,
        ProjectionState.awaitingPermission,
        ProjectionState.attached,
        ProjectionState.streaming,
        ProjectionState.error,
      ]));
      expect(ProjectionState.values.length, 6);
    });

    test('unavailable is the initial default', () {
      final c = ProjectionController();
      // Before attach(), state is unavailable
      expect(c.state, ProjectionState.unavailable);
      c.dispose();
    });

    test('attach on non-Android sets unavailable with message', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      c.attach();
      expect(c.state, ProjectionState.unavailable);
      expect(c.message, contains('Android'));
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('start on non-Android is a no-op', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      await c.start(); // should not throw
      expect(c.state, ProjectionState.unavailable);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('stop on non-Android is a no-op', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      await c.stop(); // should not throw
      expect(c.state, ProjectionState.unavailable);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('accessories returns empty on non-Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      final list = await c.accessories();
      expect(list, isEmpty);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('fetchDiagnostics returns empty on non-Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      final list = await c.fetchDiagnostics();
      expect(list, isEmpty);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('status returns null on non-Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      final s = await c.status();
      expect(s, isNull);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('controller notifies listeners on attach', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final c = ProjectionController();
      var notified = false;
      c.addListener(() => notified = true);
      c.attach();
      expect(notified, isTrue);
      c.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    test('attach on Android moves to idle and starts event stream', () {
      // On Android (default in test), attach should set idle and create subscription
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = EventChannel('my.kulnem.cruise_assist/projection_events');
      // Set up a mock handler for the EventChannel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, MockStreamHandler.inline(
        onListen: (args, sink) {},
        onCancel: (args) {},
      ));
      final c = ProjectionController();
      c.attach();
      expect(c.state, ProjectionState.idle);
      c.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
