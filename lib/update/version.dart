/// An immutable application version with SemVer-compatible ordering.
///
/// A leading `v` or `V`, whitespace, and a build number such as `+42` are
/// accepted. Missing minor/patch components are treated as zero. Build
/// metadata does not affect precedence; prerelease identifiers sort before
/// the corresponding stable release.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  const AppVersion(this.major, this.minor, this.patch,
      [this.prerelease = const <String>[]]);

  static final RegExp _pattern = RegExp(
    r'^[vV]?(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:\.(0|[1-9]\d*))?'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static AppVersion parse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) {
      throw FormatException('Invalid application version: $input');
    }
    final prerelease = match.group(4)?.split('.') ?? const <String>[];
    for (final identifier in prerelease) {
      if (int.tryParse(identifier) != null &&
          identifier.length > 1 &&
          identifier.startsWith('0')) {
        throw FormatException('Numeric prerelease identifiers cannot have '
            'leading zeroes: $input');
      }
    }
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2) ?? '0'),
      int.parse(match.group(3) ?? '0'),
      List.unmodifiable(prerelease),
    );
  }

  static AppVersion? tryParse(String input) {
    try {
      return parse(input);
    } on FormatException {
      return null;
    }
  }

  bool get isPrerelease => prerelease.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      [major, other.major],
      [minor, other.minor],
      [patch, other.patch],
    ]) {
      final comparison = pair[0].compareTo(pair[1]);
      if (comparison != 0) return comparison;
    }

    if (isPrerelease != other.isPrerelease) return isPrerelease ? -1 : 1;
    final length =
        prerelease.length < other.prerelease.length
            ? prerelease.length
            : other.prerelease.length;
    for (var i = 0; i < length; i++) {
      final left = prerelease[i];
      final right = other.prerelease[i];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final comparison = switch ((leftNumber, rightNumber)) {
        (final int a, final int b) => a.compareTo(b),
        (final int _, null) => -1,
        (null, final int _) => 1,
        _ => left.compareTo(right),
      };
      if (comparison != 0) return comparison;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(
        major,
        minor,
        patch,
        isPrerelease,
        Object.hashAll(prerelease.map((id) {
          final number = int.tryParse(id);
          return number == null ? id : 'numeric:$number';
        })),
      );

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    if (prerelease.isEmpty) return base;
    return '$base-${prerelease.join('.')}';
  }
}

/// Returns a negative value when [installed] is older than [candidate].
int compareVersions(String installed, String candidate) =>
    AppVersion.parse(installed).compareTo(AppVersion.parse(candidate));
