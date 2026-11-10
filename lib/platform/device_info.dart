/// Device information and head-unit compatibility helper.
///
/// Uses platform channels on Android; returns safe defaults elsewhere.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Static device information snapshot.
@immutable
class DeviceInfo {
  final String model;
  final String manufacturer;
  final String sdk;
  final String abi;
  final String androidVersion;

  const DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.sdk,
    required this.abi,
    required this.androidVersion,
  });

  static const unknown = DeviceInfo(
    model: 'Unknown',
    manufacturer: 'Unknown',
    sdk: '0',
    abi: 'unknown',
    androidVersion: 'unknown',
  );

  /// Fetch device info from the Android build properties.
  static Future<DeviceInfo> fetch() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return unknown;
    }
    try {
      const channel = MethodChannel('my.kulnem.cruise_assist/device_info');
      final result = await channel.invokeMethod<Map>('getDeviceInfo');
      if (result == null) return unknown;
      final m = result.cast<String, dynamic>();
      return DeviceInfo(
        model: m['model'] as String? ?? 'Unknown',
        manufacturer: m['manufacturer'] as String? ?? 'Unknown',
        sdk: m['sdk'] as String? ?? '0',
        abi: m['abi'] as String? ?? 'unknown',
        androidVersion: m['androidVersion'] as String? ?? 'unknown',
      );
    } on PlatformException {
      return unknown;
    } on MissingPluginException {
      return unknown;
    }
  }

  String get displayName {
    final mfr =
        manufacturer.isNotEmpty ? '${manufacturer[0].toUpperCase()}${manufacturer.substring(1)}' : '';
    return '$mfr $model'.trim();
  }
}

/// USB AOA compatibility assessment.
enum CompatibilityVerdict {
  /// Device meets all known requirements.
  supported,

  /// Device works but with caveats.
  partial,

  /// Device cannot support USB AOA.
  unsupported,

  /// Not enough information to determine.
  unknown,
}

/// Evaluates whether a device can run USB AOA projection.
class DeviceCompatibility {
  final DeviceInfo device;
  final CompatibilityVerdict verdict;
  final String summary;
  final List<String> notes;

  const DeviceCompatibility({
    required this.device,
    required this.verdict,
    required this.summary,
    this.notes = const [],
  });

  /// Evaluate compatibility from device info and optional injected overrides.
  factory DeviceCompatibility.evaluate(DeviceInfo info) {
    final sdkInt = int.tryParse(info.sdk) ?? 0;
    final notes = <String>[];

    if (sdkInt == 0) {
      return DeviceCompatibility(
        device: info,
        verdict: CompatibilityVerdict.unknown,
        summary: '${info.displayName}: unknown (non-Android or missing info)',
        notes: const ['Cannot determine Android SDK version'],
      );
    }

    if (sdkInt < 26) {
      return DeviceCompatibility(
        device: info,
        verdict: CompatibilityVerdict.unsupported,
        summary: '${info.displayName}: unsupported (requires Android 8.0+)',
        notes: const ['minSdk 26 required for USB AOA and foreground service'],
      );
    }

    // API 26+ supports USB AOA natively
    if (sdkInt >= 26) {
      notes.add('USB AOA supported (API $sdkInt)');
    }
    if (sdkInt >= 29) {
      notes.add('Foreground service type connectedDevice available');
    }
    if (sdkInt >= 33) {
      notes.add('Runtime notification permission required');
    }

    // Specific known devices
    final lower = '${info.manufacturer} ${info.model}'.toLowerCase();
    if (lower.contains('sony') && lower.contains('xperia')) {
      notes.add('Sony Xperia: USB OTG host mode confirmed');
    }
    if (lower.contains('samsung')) {
      notes.add('Samsung: DeX mode may intercept USB AOA');
    }

    return DeviceCompatibility(
      device: info,
      verdict: CompatibilityVerdict.supported,
      summary: '${info.displayName}: supported',
      notes: notes,
    );
  }
}

/// What we know (and don't know) about the Ativa AV head unit's requirements.
@immutable
class SmartLinkProfile {
  final String headUnit;
  final String transport;
  final String resolution;
  final String protocol;
  final List<String> unknowns;

  const SmartLinkProfile({
    required this.headUnit,
    required this.transport,
    required this.resolution,
    required this.protocol,
    required this.unknowns,
  });

  /// The Perodua Ativa AV head unit expected profile.
  static const ativaAv = SmartLinkProfile(
    headUnit: 'Perodua Ativa AV',
    transport: 'USB AOA (accessory mode)',
    resolution: 'unknown (likely 1024×600 or 1280×480)',
    protocol: 'unknown (Carbit/DriveDeck proprietary framing)',
    unknowns: [
      'Exact USB vendor/product IDs for AOA handshake',
      'Video encoding format and frame rate',
      'Touch input event protocol (reverse direction)',
      'Authentication/pairing sequence (if any)',
      'Required AOA manufacturer/model strings',
    ],
  );
}
