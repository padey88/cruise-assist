/// Result wrapper for every network-backed read.
///
/// Contract: services never throw to the UI. A failure returns a [Fetch]
/// carrying the last good [value] (if any) plus a human-readable [message].
/// [stale] is true whenever [value] is older than the refresh interval, so the
/// UI can never present cached data as if it were current.
class Fetch<T> {
  final T? value;
  final DateTime? at;
  final bool stale;
  final String? message;

  const Fetch({this.value, this.at, this.stale = false, this.message});

  const Fetch.idle()
      : value = null,
        at = null,
        stale = false,
        message = null;

  static Fetch<T> ok<T>(T value, DateTime at) =>
      Fetch<T>(value: value, at: at);

  static Fetch<T> failed<T>(String message, {T? value, DateTime? at}) => Fetch<T>(
        value: value,
        at: at,
        stale: value != null,
        message: message,
      );

  bool get ok => message == null;
  bool get hasValue => value != null;

  Fetch<T> asStale(String message) =>
      Fetch<T>(value: value, at: at, stale: true, message: message);

  Fetch<R> map<R>(R? Function(T) f) => Fetch<R>(
        value: value == null ? null : f(value as T),
        at: at,
        stale: stale,
        message: message,
      );

  @override
  String toString() =>
      'Fetch(value: $value, at: $at, stale: $stale, message: $message)';
}
