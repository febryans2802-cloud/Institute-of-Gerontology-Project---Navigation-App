/// Vibration patterns (docs/study-design.md §5.4).
///
/// [timings] follows the Android convention: [wait, on, off, on, ...] in ms.
/// [intensities] has the same length; 0 for waits/offs, 255 for "on".
library;

import 'route_script.dart';

class VibrationPattern {
  VibrationPattern(this.name, List<int> onOff)
      : timings = [0, ...onOff],
        intensities = [
          0,
          for (var i = 0; i < onOff.length; i++) i.isEven ? 255 : 0,
        ];

  final String name;
  final List<int> timings;
  final List<int> intensities;

  int get totalMs => timings.fold(0, (a, b) => a + b);
}

class VibrationPatterns {
  static final left = VibrationPattern('left', [400, 200, 400]);
  static final right =
      VibrationPattern('right', [100, 100, 100, 100, 100, 100, 100]);
  static final straight = VibrationPattern('straight', [150]);
  static final arrived = VibrationPattern('arrived', [1000]);
  static final stop = VibrationPattern('stop', [400, 200, 400, 200, 400]);

  /// Screen condition: attention cue with no direction information.
  static final generic = VibrationPattern('generic', [150]);

  /// Clock-sync marker (also visible as a screen flash).
  static final sync = VibrationPattern('sync', [500]);

  static VibrationPattern forDirection(Direction d) => switch (d) {
        Direction.left => left,
        Direction.right => right,
        Direction.straight => straight,
        Direction.arrived => arrived,
        Direction.stop => stop,
      };
}
