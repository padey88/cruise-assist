/// Car-facing UI surface and full-page car screen management.
///
/// Exports:
/// - [CarScreenPage] — full-page view with preview, USB controls, diagnostics
/// - [CarSurface] — the head-unit UI widget (clock, prayer, weather, fuel)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cruise_assist/app/dashboard_controller.dart';
import 'package:cruise_assist/projection/projection.dart';
import 'package:cruise_assist/platform/device_info.dart';
import 'package:cruise_assist/theme.dart';

// ---------------------------------------------------------------------------
// CarScreenPage
// ---------------------------------------------------------------------------

/// Full-page car screen with preview, USB controls, state chip, device info,
/// and expandable USB diagnostics.
class CarScreenPage extends StatefulWidget {
  const CarScreenPage({super.key, required this.controller});
  final DashboardController controller;

  @override
  State<CarScreenPage> createState() => _CarScreenPageState();
}

class _CarScreenPageState extends State<CarScreenPage> {
  final _projection = ProjectionController();
  DeviceCompatibility? _compat;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _projection.attach();
    _projection.addListener(_onProjection);
    widget.controller.addListener(_onData);
    _loadDeviceInfo();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onProjection() {
    if (mounted) setState(() {});
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDeviceInfo() async {
    final info = await DeviceInfo.fetch();
    if (!mounted) return;
    setState(() => _compat = DeviceCompatibility.evaluate(info));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _projection.removeListener(_onProjection);
    widget.controller.removeListener(_onData);
    _projection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // State chip
        _buildStateChip(),
        const SizedBox(height: 12),

        // Device compatibility
        if (_compat != null) _buildCompatLine(),
        const SizedBox(height: 16),

        // Preview label
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: CA.dim),
        ),
        const SizedBox(height: 8),

        // Car surface preview at forced aspect
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CA.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1280 / 480,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1280,
                height: 480,
                child: CarSurface(
                  payloads: widget.controller.payloads,
                  now: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // USB connect / disconnect button
        _buildUsbButton(),
        const SizedBox(height: 16),

        // Expandable diagnostics
        _buildDiagnostics(),
      ],
    );
  }

  Widget _buildStateChip() {
    final (label, color) = switch (_projection.state) {
      ProjectionState.unavailable => ('Unavailable', Colors.grey),
      ProjectionState.idle => ('Idle', CA.dim),
      ProjectionState.awaitingPermission => (
        'Awaiting permission',
        Colors.amber,
      ),
      ProjectionState.attached => ('Attached', CA.good),
      ProjectionState.streaming => ('Streaming', CA.accent),
      ProjectionState.error => ('Error', CA.danger),
    };
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        if (_projection.message != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _projection.message!,
              style: TextStyle(color: CA.dim, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompatLine() {
    final c = _compat!;
    final icon = switch (c.verdict) {
      CompatibilityVerdict.supported => Icons.check_circle_outline,
      CompatibilityVerdict.partial => Icons.warning_amber_rounded,
      CompatibilityVerdict.unsupported => Icons.cancel_outlined,
      CompatibilityVerdict.unknown => Icons.help_outline,
    };
    final color = switch (c.verdict) {
      CompatibilityVerdict.supported => CA.good,
      CompatibilityVerdict.partial => Colors.amber,
      CompatibilityVerdict.unsupported => CA.danger,
      CompatibilityVerdict.unknown => CA.dim,
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(c.summary, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildUsbButton() {
    final connected =
        _projection.state == ProjectionState.attached ||
        _projection.state == ProjectionState.streaming;
    return FilledButton.icon(
      onPressed: connected ? _projection.stop : _projection.start,
      icon: Icon(connected ? Icons.usb_off : Icons.usb),
      label: Text(connected ? 'Disconnect' : 'Connect to head unit'),
      style: FilledButton.styleFrom(
        backgroundColor: connected
            ? CA.danger.withValues(alpha: 0.2)
            : CA.accent.withValues(alpha: 0.15),
        foregroundColor: connected ? CA.danger : CA.accent,
      ),
    );
  }

  Widget _buildDiagnostics() {
    final diags = _projection.diagnostics;
    final accessory = _projection.lastAccessory;

    return ExpansionTile(
      title: const Text('USB diagnostics'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      children: [
        if (accessory != null) ...[
          _diagCard('Accessory descriptor', _formatAccessory(accessory)),
          const SizedBox(height: 8),
        ],
        if (diags.isEmpty && accessory == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No USB accessory detected. Connect a head unit to see diagnostics.',
              style: TextStyle(color: CA.dim, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        for (final d in diags.reversed.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _diagCard(
              d['kind'] == 'packet'
                  ? '${d['direction']?.toString().toUpperCase() ?? '?'} ${d['length']} bytes'
                  : d['kind']?.toString() ?? 'event',
              _formatDiag(d),
            ),
          ),
      ],
    );
  }

  Widget _diagCard(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CA.glass,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: CA.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: CA.dim,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAccessory(Map<String, dynamic> a) {
    final lines = <String>[];
    for (final key in [
      'manufacturer',
      'model',
      'description',
      'version',
      'serial',
      'uri',
      'hasPermission',
    ]) {
      final v = a[key];
      if (v != null) lines.add('$key: $v');
    }
    return lines.isEmpty ? '(empty descriptor)' : lines.join('\n');
  }

  String _formatDiag(Map<String, dynamic> d) {
    if (d['kind'] == 'packet') {
      final hex = d['first64Hex'] ?? '';
      final ascii = d['first64Ascii'] ?? '';
      final sig = d['signature'] ?? '';
      return 'hex: $hex\nascii: $ascii\nsignature: $sig';
    }
    return d.entries
        .where((e) => e.key != 'type' && e.key != 'kind')
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }
}

// ---------------------------------------------------------------------------
// CarSurface
// ---------------------------------------------------------------------------

/// The widget that would be mirrored to the head unit.
///
/// Renders large clock, next prayer + countdown, weather temperature, fuel
/// RON 95 price, and a status strip. Reads from the raw JSON [payloads] map.
class CarSurface extends StatelessWidget {
  const CarSurface({
    super.key,
    required this.payloads,
    required this.now,
    this.scale = 1.0,
  });

  final Map<String, dynamic> payloads;
  final DateTime now;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CA.canvas,
      padding: EdgeInsets.all(24 * scale),
      child: Row(
        children: [
          // Left: clock + prayer
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _clock(),
                SizedBox(height: 8 * scale),
                _prayer(),
              ],
            ),
          ),
          SizedBox(width: 24 * scale),
          // Right: weather + fuel + status
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _weather(),
                SizedBox(height: 12 * scale),
                _fuel(),
                const Spacer(),
                _statusStrip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clock() {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return Text(
      '$h:$m',
      style: TextStyle(
        fontSize: 96 * scale,
        fontWeight: FontWeight.w300,
        color: CA.ink,
        letterSpacing: 2,
        height: 1.0,
      ),
    );
  }

  Widget _prayer() {
    final raw = payloads['prayerNext'];
    if (raw == null || raw is! Map) {
      return _placeholder('Next prayer', scale: scale);
    }
    final map = (raw is Map<String, dynamic>)
        ? raw
        : raw.cast<String, dynamic>();
    final name = map['name'] as String? ?? '—';
    final atStr = map['at'] as String?;
    String countdown = '';
    if (atStr != null) {
      final at = DateTime.tryParse(atStr);
      if (at != null) {
        final diff = at.difference(now);
        if (diff.isNegative) {
          countdown = 'now';
        } else {
          final h = diff.inHours;
          final m = diff.inMinutes.remainder(60);
          countdown = h > 0 ? '${h}h ${m}m' : '${m}m';
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 28 * scale,
            color: CA.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (countdown.isNotEmpty)
          Text(
            'in $countdown',
            style: TextStyle(fontSize: 18 * scale, color: CA.dim),
          ),
      ],
    );
  }

  Widget _weather() {
    final raw = payloads['weather'];
    if (raw == null || raw is! Map) {
      return _placeholder('Weather', scale: scale);
    }
    final map = (raw is Map<String, dynamic>)
        ? raw
        : raw.cast<String, dynamic>();
    final temp = map['tempC'];
    final tempStr = temp != null ? '${(temp as num).round()}°' : '—';
    return Text(
      tempStr,
      style: TextStyle(
        fontSize: 56 * scale,
        fontWeight: FontWeight.w400,
        color: CA.ink,
      ),
    );
  }

  Widget _fuel() {
    final raw = payloads['fuel'];
    if (raw == null || raw is! Map) {
      return _placeholder('RON 95', scale: scale);
    }
    final map = (raw is Map<String, dynamic>)
        ? raw
        : raw.cast<String, dynamic>();
    final ron95 = map['ron95'];
    final priceStr = ron95 != null
        ? 'RM ${(ron95 as num).toStringAsFixed(2)}'
        : '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RON 95 ',
          style: TextStyle(fontSize: 16 * scale, color: CA.dim),
        ),
        Text(
          priceStr,
          style: TextStyle(
            fontSize: 22 * scale,
            color: CA.good,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statusStrip() {
    final alerts = payloads['alerts'];
    final alertCount = (alerts is List) ? alerts.length : 0;
    final fx = payloads['fx'];
    String usdStr = '—';
    if (fx is List && fx.isNotEmpty) {
      for (final rate in fx) {
        if (rate is Map && (rate['code'] ?? '') == 'USD') {
          usdStr = 'USD ${(rate['myr'] as num?)?.toStringAsFixed(2) ?? '—'}';
          break;
        }
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (alertCount > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * scale,
              vertical: 2 * scale,
            ),
            decoration: BoxDecoration(
              color: CA.danger.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4 * scale),
            ),
            child: Text(
              '$alertCount alert${alertCount == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12 * scale, color: CA.danger),
            ),
          ),
        SizedBox(width: 12 * scale),
        Text(
          usdStr,
          style: TextStyle(fontSize: 13 * scale, color: CA.dim),
        ),
      ],
    );
  }
}

Widget _placeholder(String label, {double scale = 1.0}) {
  return Text(
    '$label —',
    style: TextStyle(fontSize: 18 * scale, color: CA.dim),
  );
}
