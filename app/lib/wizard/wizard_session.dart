/// Study logic on the wizard phone: drives blocks and prompts, records
/// observer events, and logs everything.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/clock_sync.dart';
import '../core/event_logger.dart';
import '../core/protocol.dart';
import '../core/route_script.dart';
import '../core/study_design.dart';
import '../net/wizard_server.dart';

/// Observer events recorded by the wizard (docs/study-design.md §7.4).
enum ObserverEvent {
  stopObserved('stop_observed', '停下 Stop'),
  wrongTurn('wrong_turn', '走錯 Wrong turn'),
  helpRequest('help_request', '求助 Help asked'),
  spotterIntervention('spotter_intervention', '介入 Intervention'),
  nearFall('near_fall', '險跌 Near-fall');

  const ObserverEvent(this.code, this.label);
  final String code;
  final String label;
}

class ActiveBlock {
  ActiveBlock(this.block, this.route, {required this.isPractice});
  final Block block;
  final RouteScript route;
  final bool isPractice;
  int nextIndex = 0;

  RoutePrompt? get nextPrompt =>
      nextIndex < route.prompts.length ? route.prompts[nextIndex] : null;
}

class _SentPrompt {
  _SentPrompt(this.prompt, this.msgId, this.sentWallMs);
  final RoutePrompt prompt;
  final int msgId;
  final int sentWallMs;
}

class WizardSession extends ChangeNotifier {
  WizardSession({
    required this.server,
    required this.logger,
    required this.participantId,
    required this.sequence,
    required this.routes,
    this.clockLogInterval = const Duration(seconds: 30),
    this.ackTimeout = const Duration(milliseconds: 1500),
  });

  final WizardServer server;
  final EventLogger logger;
  final String participantId;
  final Sequence sequence;
  final Map<String, RouteScript> routes;
  final Duration clockLogInterval;

  /// If the participant has not confirmed receipt of a prompt within this
  /// time, the wizard is warned to REPEAT. A successful socket write does not
  /// prove delivery (e.g. a half-closed connection), only an ack does.
  final Duration ackTimeout;

  StreamSubscription<Message>? _sub;
  ActiveBlock? active;
  final completedBlocks = <int>{}; // indices into sequence.blocks
  _SentPrompt? _lastSent;
  final _sentByMsgId = <int, _SentPrompt>{};
  final _undoStack = <(int seq, String code)>[];
  bool signalWaitActive = false;
  bool ended = false;

  /// Latest prompt delivery latency (wizard send → participant render), ms.
  int? lastLatencyMs;
  String? lastAckInfo;
  int _lastClockLogWall = 0;
  Timer? _ackTimer;
  final _receivedMsgIds = <int>{};

  /// The last prompt, if its receipt was not confirmed in time.
  RoutePrompt? unackedPrompt;

  String get sessionId => logger.sessionId;
  RoutePrompt? get lastSentPrompt => _lastSent?.prompt;

  void start() {
    server.onClockSample = _onClockSample;
    server.onLinkChanged = (alive) {
      logger.log(alive ? 'connection_restored' : 'connection_lost');
      notifyListeners();
    };
    _sub = server.messages.listen(_onMessage);
    logger.log('session_start', {
      'participant_id': participantId,
      'sequence': sequence.name,
      'blocks': [for (final b in sequence.blocks) b.toString()],
      'wizard_platform': Platform.operatingSystem,
      'wizard_os_version': Platform.operatingSystemVersion,
    });
    _sendSessionState();
  }

  void _onClockSample(ClockSample sample, ClockSample best) {
    logger.clockOffsetMs = best.offsetMs;
    final now = StudyClock.wallMs();
    if (now - _lastClockLogWall >= clockLogInterval.inMilliseconds) {
      _lastClockLogWall = now;
      logger.log('clock_sync', {
        'offset_ms': best.offsetMs,
        'rtt_ms': best.rttMs,
        'last_sample_offset_ms': sample.offsetMs,
        'last_sample_rtt_ms': sample.rttMs,
        'samples': server.estimator.sampleCount,
      });
    }
    notifyListeners();
  }

  /// (Re)sends session and current block, e.g. after the participant app
  /// reconnects or restarts.
  void _sendSessionState() {
    server.send(MsgType.session, {
      'session_id': sessionId,
      'participant_id': participantId,
    });
    final a = active;
    if (a != null) {
      server.send(MsgType.conditionStart, _blockData(a));
    }
  }

  Map<String, dynamic> _blockData(ActiveBlock a) => {
        'condition': a.block.condition.code,
        'route_id': a.block.routeId,
        'practice': a.isPractice,
      };

  void _onMessage(Message msg) {
    switch (msg.type) {
      case MsgType.hello:
        logger.log('participant_hello', msg.data);
        _sendSessionState();
      case MsgType.ack:
        _onAck(msg);
      default:
        logger.log('unexpected_message', {'type': msg.type, 'data': msg.data});
    }
    notifyListeners();
  }

  void _onAck(Message msg) {
    final refId = msg.data['ref_id'] as int?;
    final stage = msg.data['stage'] as String?;
    final channel = msg.data['channel'] as String?;
    final pWall = msg.data['t_wall_ms'] as int?;
    final sent = refId == null ? null : _sentByMsgId[refId];
    final offset = server.estimator.best?.offsetMs;
    int? latency;
    if (sent != null && pWall != null && offset != null) {
      latency = pWall - offset - sent.sentWallMs;
    }
    logger.log('prompt_ack', {
      'ref_msg_id': refId,
      'prompt_id': msg.data['prompt_id'],
      'stage': stage,
      'channel': channel,
      'participant_t_wall_ms': pWall,
      'latency_ms': latency,
    });
    if (refId != null && stage == AckStage.received) {
      _receivedMsgIds.add(refId);
      if (refId == _lastSent?.msgId) unackedPrompt = null;
    }
    if (stage == AckStage.rendered && latency != null) {
      lastLatencyMs = latency;
    }
    lastAckInfo = '${msg.data['prompt_id'] ?? '?'} $stage'
        '${channel != null ? ' ($channel)' : ''}';
  }

  // ---- Blocks ----

  /// Starts block [index] of the sequence, or a practice block if
  /// [practiceCondition] is given.
  void startBlock({int? index, Condition? practiceCondition}) {
    assert((index == null) != (practiceCondition == null));
    if (active != null) endBlock();
    final block = index != null
        ? sequence.blocks[index]
        : Block(practiceCondition!, practiceRouteId);
    final route = routes[block.routeId];
    if (route == null) {
      throw StateError('Route ${block.routeId} not loaded');
    }
    final a = ActiveBlock(block, route, isPractice: index == null);
    active = a;
    _lastSent = null;
    signalWaitActive = false;
    logger.condition = block.condition.code;
    logger.routeId = block.routeId;
    final transmitted = server.send(MsgType.conditionStart, _blockData(a)) != null;
    logger.log('condition_start', {
      ..._blockData(a),
      'block_index': index,
      'route_template': route.isTemplate,
      'transmitted': transmitted,
    });
    notifyListeners();
  }

  void endBlock({bool aborted = false}) {
    final a = active;
    if (a == null) return;
    if (signalWaitActive) toggleSignalWait();
    final transmitted = server.send(MsgType.conditionEnd, _blockData(a)) != null;
    logger.log('condition_end', {
      ..._blockData(a),
      'prompts_sent': a.nextIndex,
      'prompts_total': a.route.prompts.length,
      'aborted': aborted,
      'transmitted': transmitted,
    });
    final idx = a.isPractice ? -1 : sequence.blocks.indexOf(a.block);
    if (idx >= 0 && !aborted) completedBlocks.add(idx);
    active = null;
    _ackTimer?.cancel();
    unackedPrompt = null;
    logger.condition = null;
    logger.routeId = null;
    notifyListeners();
  }

  // ---- Prompts ----

  /// Sends the next scripted prompt. Returns false if the route is finished.
  bool next() {
    final a = active;
    final p = a?.nextPrompt;
    if (a == null || p == null) return false;
    a.nextIndex++;
    _sendPrompt(p, reason: 'next');
    return true;
  }

  void repeatLast() {
    final p = _lastSent?.prompt;
    if (active == null || p == null) return;
    _sendPrompt(p, reason: 'repeat');
  }

  void offRoute() {
    if (active == null) return;
    _sendPrompt(offRoutePrompt, reason: 'off_route');
  }

  void _sendPrompt(RoutePrompt p, {required String reason}) {
    final a = active!;
    final sentWall = StudyClock.wallMs();
    final msg = server.send(MsgType.prompt, {
      'prompt': p.toJson(),
      'condition': a.block.condition.code,
      'reason': reason,
    });
    logger.log('prompt_sent', {
      'prompt_id': p.id,
      'msg_id': msg?.id,
      'reason': reason,
      'kind': p.kind.name,
      'direction': p.direction.name,
      'index': a.nextIndex - 1,
      'transmitted': msg != null,
    });
    final sent = _SentPrompt(p, msg?.id ?? -1, sentWall);
    if (msg != null) _sentByMsgId[msg.id] = sent;
    // Remembered even if not transmitted, so REPEAT can resend it.
    _lastSent = sent;
    unackedPrompt = null;
    _ackTimer?.cancel();
    _ackTimer = Timer(ackTimeout, () {
      if (ended || _lastSent != sent || _receivedMsgIds.contains(sent.msgId)) {
        return;
      }
      unackedPrompt = p;
      logger.log('prompt_unacked', {
        'prompt_id': p.id,
        'msg_id': msg?.id,
        'timeout_ms': ackTimeout.inMilliseconds,
      });
      notifyListeners();
    });
    notifyListeners();
  }

  /// Visible + vibration marker for aligning video and IMU streams.
  void syncMarker() {
    final msg = server.send(MsgType.syncMarker);
    logger.log('sync_marker', {'msg_id': msg?.id, 'transmitted': msg != null});
    if (msg != null) {
      _sentByMsgId[msg.id] =
          _SentPrompt(const RoutePrompt(
            id: 'SYNC',
            kind: PromptKind.reassure,
            direction: Direction.straight,
            textZh: '',
          ), msg.id, StudyClock.wallMs());
    }
    notifyListeners();
  }

  // ---- Observer events ----

  void observe(ObserverEvent e) {
    final seq = logger.log('observer_event', {
      'code': e.code,
      'next_prompt_index': active?.nextIndex,
      'last_prompt_id': _lastSent?.prompt.id,
    });
    _undoStack.add((seq, e.code));
    notifyListeners();
  }

  void toggleSignalWait() {
    signalWaitActive = !signalWaitActive;
    final seq = logger.log('observer_event', {
      'code': signalWaitActive ? 'signal_wait_start' : 'signal_wait_end',
    });
    _undoStack.add(
        (seq, signalWaitActive ? 'signal_wait_start' : 'signal_wait_end'));
    notifyListeners();
  }

  void note(String text) {
    final seq = logger.log('observer_event', {'code': 'note', 'text': text});
    _undoStack.add((seq, 'note'));
    notifyListeners();
  }

  /// Marks the most recent observer event as retracted (never deletes).
  String? undo() {
    if (_undoStack.isEmpty) return null;
    final (seq, code) = _undoStack.removeLast();
    logger.log('observer_undo', {'ref_seq': seq, 'code': code});
    if (code == 'signal_wait_start' || code == 'signal_wait_end') {
      signalWaitActive = !signalWaitActive;
    }
    notifyListeners();
    return code;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void logLifecycle(String state) {
    if (!ended) logger.log('app_lifecycle', {'state': state});
  }

  // ---- End ----

  Future<void> endSession() async {
    if (ended) return;
    if (active != null) endBlock(aborted: true);
    server.send(MsgType.sessionEnd, {'session_id': sessionId});
    logger.log('session_end', {'completed_blocks': completedBlocks.toList()});
    ended = true;
    _ackTimer?.cancel();
    await _sub?.cancel();
    server.onClockSample = null;
    server.onLinkChanged = null;
    await logger.close();
    notifyListeners();
  }
}
