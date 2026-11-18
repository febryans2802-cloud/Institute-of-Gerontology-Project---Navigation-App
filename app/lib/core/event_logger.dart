/// Append-only JSONL event log (schema: docs/study-design.md §7.5).
///
/// Each line is flushed to disk immediately so a crash loses at most the
/// line being written.
library;

import 'dart:convert';
import 'dart:io';

import 'clock.dart';

class EventLogger {
  EventLogger._(this.file, this._raf, this.sessionId, this.participantId,
      this.deviceRole);

  final File file;
  final RandomAccessFile _raf;
  final String sessionId;
  final String participantId;
  final String deviceRole;

  int _seq = 0;
  bool _closed = false;

  /// Current context, attached to every subsequent line.
  String? condition;
  String? routeId;

  /// Latest estimate of (participant clock − wizard clock), if known.
  int? clockOffsetMs;

  int get lastSeq => _seq;
  bool get isOpen => !_closed;

  static Future<EventLogger> open({
    required Directory dir,
    required String sessionId,
    required String participantId,
    required String deviceRole,
  }) async {
    await dir.create(recursive: true);
    final safe = '${sessionId}_$deviceRole'.replaceAll(RegExp(r'[^\w\-]'), '_');
    var file = File('${dir.path}/$safe.jsonl');
    // Never overwrite: if the app restarts mid-session, start a new part.
    var part = 2;
    while (await file.exists()) {
      file = File('${dir.path}/${safe}_part$part.jsonl');
      part++;
    }
    final raf = await file.open(mode: FileMode.append);
    return EventLogger._(file, raf, sessionId, participantId, deviceRole);
  }

  /// Writes one event and returns its sequence number.
  int log(String event, [Map<String, dynamic> data = const {}]) {
    if (_closed) return -1;
    _seq++;
    final line = jsonEncode({
      'session_id': sessionId,
      'participant_id': participantId,
      'device_role': deviceRole,
      'condition': condition,
      'route_id': routeId,
      'seq': _seq,
      't_mono_ms': StudyClock.monoMs(),
      't_wall_ms': StudyClock.wallMs(),
      't_wall': StudyClock.isoWithOffset(),
      'clock_offset_ms': clockOffsetMs,
      'event': event,
      'data': data,
    });
    _raf.writeStringSync('$line\n');
    _raf.flushSync();
    return _seq;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _raf.close();
  }
}
