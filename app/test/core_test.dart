import 'dart:convert';
import 'dart:io';

import 'package:cane_nav/core/clock.dart';
import 'package:cane_nav/core/clock_sync.dart';
import 'package:cane_nav/core/event_logger.dart';
import 'package:cane_nav/core/protocol.dart';
import 'package:cane_nav/core/route_script.dart';
import 'package:cane_nav/core/study_design.dart';
import 'package:cane_nav/core/vibration_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('counterbalancing', () {
    test('every block of 4 sequences covers each condition×route once per position', () {
      for (final pos in [0, 1]) {
        final blocks = {for (final s in Sequence.values) s.blocks[pos]};
        expect(blocks, hasLength(4), reason: 'position $pos');
      }
    });

    test('each sequence has both conditions and both routes', () {
      for (final s in Sequence.values) {
        expect({for (final b in s.blocks) b.condition}, Condition.values.toSet());
        expect({for (final b in s.blocks) b.routeId}, {'R1', 'R2'});
      }
    });

    test('enrolment number cycles A–D', () {
      expect([for (var n = 1; n <= 9; n++) Sequence.forEnrolmentNumber(n).name].join(),
          'ABCDABCDA');
      expect(() => Sequence.forEnrolmentNumber(0), throwsArgumentError);
    });

    test('condition codes round-trip', () {
      for (final c in Condition.values) {
        expect(Condition.fromCode(c.code), c);
      }
      expect(() => Condition.fromCode('X'), throwsFormatException);
    });
  });

  group('vibration patterns', () {
    test('timings and intensities align, on-segments at full amplitude', () {
      final all = [
        VibrationPatterns.left,
        VibrationPatterns.right,
        VibrationPatterns.straight,
        VibrationPatterns.arrived,
        VibrationPatterns.stop,
        VibrationPatterns.generic,
        VibrationPatterns.sync,
      ];
      for (final p in all) {
        expect(p.timings.length, p.intensities.length, reason: p.name);
        expect(p.timings.first, 0);
        for (var i = 1; i < p.timings.length; i++) {
          expect(p.intensities[i], i.isOdd ? 255 : 0, reason: '${p.name}[$i]');
        }
      }
    });

    test('left and right are distinguishable (count and rhythm differ)', () {
      int pulses(VibrationPattern p) => p.intensities.where((x) => x > 0).length;
      expect(pulses(VibrationPatterns.left), 2);
      expect(pulses(VibrationPatterns.right), 4);
      expect(VibrationPatterns.left.totalMs, 1000);
    });

    test('every direction has a pattern', () {
      for (final d in Direction.values) {
        expect(VibrationPatterns.forDirection(d).name, isNotEmpty);
      }
    });
  });

  group('clock sync', () {
    test('symmetric delay gives exact offset', () {
      // wizard sends at 1000, participant clock is +250 ahead, 20 ms each way.
      final s = ClockSample.fromTimes(1000, 1000 + 20 + 250, 1040);
      expect(s.offsetMs, 250);
      expect(s.rttMs, 40);
    });

    test('estimator picks the min-RTT sample in the window', () {
      final e = ClockSyncEstimator(window: 3);
      e.add(const ClockSample(offsetMs: 100, rttMs: 80));
      e.add(const ClockSample(offsetMs: 252, rttMs: 10));
      e.add(const ClockSample(offsetMs: 300, rttMs: 60));
      expect(e.best!.offsetMs, 252);
      e.add(const ClockSample(offsetMs: 400, rttMs: 50)); // evicts 1st
      e.add(const ClockSample(offsetMs: 410, rttMs: 55)); // evicts best
      expect(e.best!.offsetMs, 400);
      e.add(const ClockSample(offsetMs: 0, rttMs: -5)); // ignored
      expect(e.sampleCount, 3);
    });
  });

  group('protocol', () {
    test('round-trip', () {
      final m = Message(MsgType.prompt, 7, {'a': 1, 'b': 'x'});
      final d = Message.decode(m.encode());
      expect(d.type, MsgType.prompt);
      expect(d.id, 7);
      expect(d.data, {'a': 1, 'b': 'x'});
    });

    test('rejects malformed input', () {
      expect(() => Message.decode('[]'), throwsFormatException);
      expect(() => Message.decode('{"type":"x"}'), throwsFormatException);
      expect(() => Message.decode('not json'), throwsFormatException);
    });
  });

  group('route scripts', () {
    for (final id in ['PRACTICE', 'R1', 'R2']) {
      test('$id asset parses and ends with arrived', () {
        final r = RouteScript.parse(File('assets/routes/$id.json').readAsStringSync());
        expect(r.routeId, id);
        expect(r.prompts.last.kind, PromptKind.arrived);
        for (final p in r.prompts) {
          expect(p.textZh, isNotEmpty);
          // prompt JSON round-trips (it is sent over the wire)
          expect(RoutePrompt.fromJson(p.toJson()).toJson(), p.toJson());
        }
      });
    }

    test('R1 and R2 are matched on turn counts', () {
      Map<Direction, int> turns(String id) {
        final r = RouteScript.parse(File('assets/routes/$id.json').readAsStringSync());
        final out = <Direction, int>{};
        for (final p in r.prompts.where((p) => p.kind == PromptKind.execute)) {
          out[p.direction] = (out[p.direction] ?? 0) + 1;
        }
        return out;
      }

      expect(turns('R1'), turns('R2'));
    });

    test('rejects duplicate ids and missing arrival', () {
      Map<String, dynamic> p(String id, String kind, String dir) =>
          {'id': id, 'kind': kind, 'direction': dir, 'text_zh': 't'};
      expect(
          () => RouteScript.fromJson({
                'route_id': 'X',
                'name': 'x',
                'prompts': [p('a', 'advance', 'left'), p('a', 'arrived', 'arrived')],
              }),
          throwsFormatException);
      expect(
          () => RouteScript.fromJson({
                'route_id': 'X',
                'name': 'x',
                'prompts': [p('a', 'advance', 'left')],
              }),
          throwsFormatException);
    });
  });

  group('event logger', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cane_nav_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes schema fields as JSONL with increasing seq', () async {
      final l = await EventLogger.open(
          dir: tmp, sessionId: 'S1', participantId: 'P01', deviceRole: 'wizard');
      l.condition = 'AH';
      l.routeId = 'R2';
      l.clockOffsetMs = -37;
      expect(l.log('a', {'x': 1}), 1);
      expect(l.log('b'), 2);
      await l.close();
      expect(l.log('after_close'), -1);

      final lines = l.file.readAsLinesSync().map(jsonDecode).toList();
      expect(lines, hasLength(2));
      final first = lines.first as Map<String, dynamic>;
      for (final k in [
        'session_id', 'participant_id', 'device_role', 'condition', 'route_id',
        'seq', 't_mono_ms', 't_wall_ms', 't_wall', 'clock_offset_ms', 'event', 'data',
      ]) {
        expect(first.containsKey(k), isTrue, reason: k);
      }
      expect(first['condition'], 'AH');
      expect(first['clock_offset_ms'], -37);
      expect(first['data'], {'x': 1});
    });

    test('never overwrites an existing log', () async {
      final a = await EventLogger.open(
          dir: tmp, sessionId: 'S1', participantId: 'P01', deviceRole: 'participant');
      a.log('first');
      await a.close();
      final b = await EventLogger.open(
          dir: tmp, sessionId: 'S1', participantId: 'P01', deviceRole: 'participant');
      b.log('second');
      await b.close();
      expect(a.file.path, isNot(b.file.path));
      expect(b.file.path, endsWith('_part2.jsonl'));
      expect(a.file.readAsLinesSync(), hasLength(1));
    });
  });

  test('ISO timestamp includes UTC offset', () {
    expect(StudyClock.isoWithOffset(),
        matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}[+-]\d\d:\d\d$')));
  });
}
