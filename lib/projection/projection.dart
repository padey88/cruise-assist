/// Projection state machine and platform channel controller.
///
/// Degrades gracefully on non-Android: state stays [ProjectionState.unavailable]
/// and start/stop are no-ops.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lifecycle states the USB/AOA projection can be in.
enum ProjectionState {
  /// Platform does not support USB AOA (iOS, web, desktop).
  unavailable,

  /// Android is ready but no accessory is attached.
  idle,

  /// Permission dialog is showing for the USB accessory.
  awaitingPermission,

  /// Accessory opened and bulk endpoints are active.
  attached,

  /// Video frames are being sent (future — not implemented).
  streaming,

  /// An error interrupted the connection.
  error,
}

/// Dart facade for the native ProjectionService.
class ProjectionController extends ChangeNotifier {
  static const _method = MethodChannel('my.kulnem.cruise_assist/projection');
  static const _events = EventChannel(
    'my.kulnem.cruise_assist/projection_events',
  );

  ProjectionState _state = ProjectionState.unavailable;
  String? _message;
  Map<String, dynamic>? _lastAccessory;
  final List<Map<String, dynamic>> _diagnostics = [];
  StreamSubscription<dynamic>? _sub;

  ProjectionState get state => _state;
  String? get message => _message;
  Map<String, dynamic>? get lastAccessory => _lastAccessory;
  List<Map<String, dynamic>> get diagnostics => List.unmodifiable(_diagnostics);

  /// Begin listening to native events. Safe to call multiple times.
  void attach() {
    if (!_isAndroid) {
      _state = ProjectionState.unavailable;
      _message = 'USB AOA requires Android';
      notifyListeners();
      return;
    }
    _state = ProjectionState.idle;
    notifyListeners();
    _sub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  /// Start the foreground projection service.
  Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _method.invokeMethod<void>('start');
    } on PlatformException catch (e) {
      _state = ProjectionState.error;
      _message = e.message;
      notifyListeners();
    }
  }

  /// Stop the foreground projection service.
  Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _method.invokeMethod<void>('stop');
      _state = ProjectionState.idle;
      _message = null;
      notifyListeners();
    } on PlatformException catch (e) {
      _state = ProjectionState.error;
      _message = e.message;
      notifyListeners();
    }
  }

  /// Query current service status.
  Future<Map<String, dynamic>?> status() async {
    if (!_isAndroid) return null;
    try {
      final result = await _method.invokeMethod<Map>('status');
      return result?.cast<String, dynamic>();
    } on PlatformException {
      return null;
    }
  }

  /// Enumerate currently attached accessories.
  Future<List<Map<String, dynamic>>> accessories() async {
    if (!_isAndroid) return const [];
    try {
      final result = await _method.invokeMethod<List>('accessories');
      return result?.map((e) => (e as Map).cast<String, dynamic>()).toList() ??
          const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Fetch the diagnostics snapshot from the native ring buffer.
  Future<List<Map<String, dynamic>>> fetchDiagnostics() async {
    if (!_isAndroid) return const [];
    try {
      final result = await _method.invokeMethod<List>('diagnostics');
      return result?.map((e) => (e as Map).cast<String, dynamic>()).toList() ??
          const [];
    } on PlatformException {
      return const [];
    }
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = raw.cast<String, dynamic>();
    final type = event['type'] as String?;

    switch (type) {
      case 'state':
        final name = event['state'] as String? ?? '';
        _state = _parseState(name);
        _message = event['message'] as String?;
        final acc = event['accessory'];
        if (acc is Map) _lastAccessory = acc.cast<String, dynamic>();
        break;
      case 'accessories':
        final items = event['items'];
        if (items is List && items.isNotEmpty) {
          final first = items.first;
          if (first is Map) _lastAccessory = first.cast<String, dynamic>();
        }
        break;
      case 'diagnostic':
        _diagnostics.add(event);
        if (_diagnostics.length > 64) _diagnostics.removeAt(0);
        break;
    }
    notifyListeners();
  }

  static ProjectionState _parseState(String name) => switch (name) {
    'idle' => ProjectionState.idle,
    'awaitingPermission' => ProjectionState.awaitingPermission,
    'attached' => ProjectionState.attached,
    'streaming' => ProjectionState.streaming,
    'error' => ProjectionState.error,
    _ => ProjectionState.idle,
  };

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
