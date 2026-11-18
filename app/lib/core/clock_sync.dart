/// NTP-style clock offset estimation between wizard and participant phones.
///
/// The wizard sends a ping at its wall time t0, the participant stamps t1 with
/// its own wall clock, and the wizard receives the pong at t2.
///   offset = t1 - (t0 + t2) / 2      (participant clock minus wizard clock)
///   rtt    = t2 - t0
/// The sample with the smallest RTT in a recent window is the most accurate.
library;

class ClockSample {
  const ClockSample({required this.offsetMs, required this.rttMs});
  final int offsetMs;
  final int rttMs;

  factory ClockSample.fromTimes(int t0, int t1, int t2) => ClockSample(
        offsetMs: (t1 - (t0 + t2) / 2).round(),
        rttMs: t2 - t0,
      );
}

class ClockSyncEstimator {
  ClockSyncEstimator({this.window = 20});

  final int window;
  final List<ClockSample> _samples = [];

  void add(ClockSample s) {
    if (s.rttMs < 0) return; // clock jumped mid-exchange; discard
    _samples.add(s);
    if (_samples.length > window) _samples.removeAt(0);
  }

  /// Best current estimate, or null if no samples yet.
  ClockSample? get best {
    if (_samples.isEmpty) return null;
    return _samples.reduce((a, b) => b.rttMs < a.rttMs ? b : a);
  }

  int get sampleCount => _samples.length;

  void reset() => _samples.clear();
}
