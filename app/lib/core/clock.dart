/// Time sources used in every log line.
library;

class StudyClock {
  static final Stopwatch _mono = Stopwatch()..start();

  /// Monotonic milliseconds since app start (immune to wall-clock changes).
  static int monoMs() => _mono.elapsedMilliseconds;

  /// Wall-clock milliseconds since epoch (used for cross-device sync).
  static int wallMs() => DateTime.now().millisecondsSinceEpoch;

  /// ISO-8601 local time with UTC offset, e.g. 2026-12-03T09:14:22.418+08:00.
  static String isoWithOffset([DateTime? t]) {
    final d = t ?? DateTime.now();
    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = d.millisecond.toString().padLeft(3, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
        'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}.$ms$sign$h:$m';
  }
}
