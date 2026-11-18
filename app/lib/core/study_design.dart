/// Experimental conditions and counterbalancing (see docs/study-design.md §2).
library;

enum Condition {
  /// Screen: direction info on screen, generic vibration as attention cue.
  screen('S', 'Screen'),

  /// Audio + Haptic: voice prompt + direction-specific vibration; screen blank.
  audioHaptic('AH', 'Audio + Haptic');

  const Condition(this.code, this.label);
  final String code;
  final String label;

  static Condition fromCode(String code) =>
      Condition.values.firstWhere((c) => c.code == code,
          orElse: () => throw FormatException('Unknown condition: $code'));
}

/// One walk of one route under one condition.
class Block {
  const Block(this.condition, this.routeId);
  final Condition condition;
  final String routeId;

  @override
  String toString() => '${condition.code} on $routeId';

  @override
  bool operator ==(Object other) =>
      other is Block && other.condition == condition && other.routeId == routeId;

  @override
  int get hashCode => Object.hash(condition, routeId);
}

/// The four counterbalanced sequences (condition order × route assignment).
enum Sequence {
  A([Block(Condition.screen, 'R1'), Block(Condition.audioHaptic, 'R2')]),
  B([Block(Condition.audioHaptic, 'R1'), Block(Condition.screen, 'R2')]),
  C([Block(Condition.screen, 'R2'), Block(Condition.audioHaptic, 'R1')]),
  D([Block(Condition.audioHaptic, 'R2'), Block(Condition.screen, 'R1')]);

  const Sequence(this.blocks);
  final List<Block> blocks;

  /// Suggested sequence for the n-th enrolled participant (1-based),
  /// cycling A, B, C, D so every block of 4 is balanced.
  static Sequence forEnrolmentNumber(int n) {
    if (n < 1) throw ArgumentError.value(n, 'n', 'must be >= 1');
    return Sequence.values[(n - 1) % Sequence.values.length];
  }
}

const String practiceRouteId = 'PRACTICE';
