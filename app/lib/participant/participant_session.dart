/// Study logic on the participant phone: reacts to wizard messages, renders
/// prompts according to the active condition, acks, and logs.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/event_logger.dart';
import '../core/protocol.dart';
import '../core/route_script.dart';
import '../core/study_design.dart';
import '../core/vibration_patterns.dart';
import '../net/participant_client.dart';
import 'outputs.dart';

class ParticipantSession extends ChangeNotifier {
  ParticipantSession({
    required this.client,
    required this.output,
    required this.location,
    required this.logDir,
    Future<void> Function()? waitForFrame,
  }) : _waitForFrame = waitForFrame ?? (() async {});

  final ParticipantClient client;
  final GuidanceOutput output;
  final LocationSource location;
  final Future<Directory> Function() logDir;
  final Future<void> Function() _waitForFrame;

  StreamSubscription<Message>? _sub;
  EventLogger? logger;

  Condition? condition;
  String? routeId;
  bool isPractice = false;

  /// Prompt shown on screen (Screen condition only).
  RoutePrompt? displayPrompt;

  /// True while the sync-marker flash is showing.
  bool flash = false;
  bool sessionEnded = false;
  int _renderToken = 0;
  Future<void> _queue = Future.value();

  void start() {
    // Handle messages strictly in order; long-running rendering (audio) is
    // started from the handler but not awaited, so it never blocks the queue.
    _sub = client.messages.listen((m) {
      _queue = _queue.then((_) => _onMessage(m)).catchError((Object e) {
        logger?.log('error', {'where': 'on_message', 'error': e.toString()});
      });
    });
    client.onConnected = () {
      logger?.log('connection_restored');
      notifyListeners();
    };
    client.onDisconnected = () {
      logger?.log('connection_lost');
      notifyListeners();
    };
    client.addListener(_syncOffset);
  }

  void _syncOffset() {
    logger?.clockOffsetMs = client.clockOffsetMs;
    notifyListeners();
  }

  void _ack(Message m, String stage,
      {String? channel, String? promptId, Map<String, dynamic>? extra}) {
    client.send(MsgType.ack, {
      'ref_id': m.id,
      'stage': stage,
      'channel': ?channel,
      'prompt_id': ?promptId,
      't_wall_ms': StudyClock.wallMs(),
      ...?extra,
    });
  }

  Future<void> _onMessage(Message m) async {
    switch (m.type) {
      case MsgType.session:
        await _onSession(m);
      case MsgType.conditionStart:
        _onConditionStart(m);
      case MsgType.conditionEnd:
        _onConditionEnd(m);
      case MsgType.prompt:
        await _onPrompt(m);
      case MsgType.syncMarker:
        await _onSync(m);
      case MsgType.sessionEnd:
        await _onSessionEnd(m);
      default:
        logger?.log('unexpected_message', {'type': m.type});
    }
  }

  Future<void> _onSession(Message m) async {
    final sid = m.data['session_id'] as String;
    final pid = m.data['participant_id'] as String;
    if (logger?.sessionId == sid && logger!.isOpen) return; // reconnect
    await logger?.close();
    logger = await EventLogger.open(
      dir: await logDir(),
      sessionId: sid,
      participantId: pid,
      deviceRole: 'participant',
    );
    logger!.clockOffsetMs = client.clockOffsetMs;
    sessionEnded = false;
    logger!.log('session_joined', {'wizard_host': client.host});
    notifyListeners();
  }

  void _onConditionStart(Message m) {
    final c = Condition.fromCode(m.data['condition'] as String);
    final r = m.data['route_id'] as String;
    if (condition == c && routeId == r) return; // resent after reconnect
    condition = c;
    routeId = r;
    isPractice = m.data['practice'] as bool? ?? false;
    displayPrompt = null;
    _renderToken++;
    unawaited(output.stopSpeaking());
    logger?.condition = c.code;
    logger?.routeId = r;
    logger?.log('condition_start', {'practice': isPractice});
    location.start((fix) => logger?.log('gps_fix', fix.data));
    notifyListeners();
  }

  void _onConditionEnd(Message m) {
    location.stop();
    _renderToken++;
    unawaited(output.stopSpeaking());
    logger?.log('condition_end');
    condition = null;
    routeId = null;
    displayPrompt = null;
    logger?.condition = null;
    logger?.routeId = null;
    notifyListeners();
  }

  Future<void> _onPrompt(Message m) async {
    final p = RoutePrompt.fromJson(
        (m.data['prompt'] as Map).cast<String, dynamic>());
    // The condition in the message wins (robust to a missed condition_start).
    final c = Condition.fromCode(
        m.data['condition'] as String? ?? condition?.code ?? 'S');
    logger?.log('prompt_received', {
      'msg_id': m.id,
      'prompt_id': p.id,
      'reason': m.data['reason'],
    });
    _ack(m, AckStage.received, promptId: p.id);

    final token = ++_renderToken; // a newer prompt cancels this one
    if (c == Condition.screen) {
      unawaited(_renderScreen(m, p));
    } else {
      unawaited(_renderAudioHaptic(m, p, token));
    }
  }

  Future<void> _renderScreen(Message m, RoutePrompt p) async {
    displayPrompt = p;
    notifyListeners();
    final vib = VibrationPatterns.generic;
    unawaited(output.vibrate(vib));
    logger?.log('prompt_rendered',
        {'msg_id': m.id, 'prompt_id': p.id, 'channel': 'vibration', 'pattern': vib.name});
    await _waitForFrame();
    logger?.log('prompt_rendered',
        {'msg_id': m.id, 'prompt_id': p.id, 'channel': 'screen'});
    _ack(m, AckStage.rendered, channel: 'screen', promptId: p.id);
  }

  Future<void> _renderAudioHaptic(Message m, RoutePrompt p, int token) async {
    // No direction info on screen in AH: if the participant looks at the
    // phone, they must not get the screen condition's information.
    displayPrompt = null;
    notifyListeners();
    await output.stopSpeaking();
    final vib = VibrationPatterns.forDirection(p.direction);
    unawaited(output.vibrate(vib));
    logger?.log('prompt_rendered',
        {'msg_id': m.id, 'prompt_id': p.id, 'channel': 'vibration', 'pattern': vib.name});
    _ack(m, AckStage.rendered, channel: 'vibration', promptId: p.id);

    // Vibration first, then the voice (avoids masking the onset of speech).
    await Future<void>.delayed(Duration(milliseconds: vib.totalMs + 150));
    if (token != _renderToken) {
      logger?.log('prompt_superseded', {'msg_id': m.id, 'prompt_id': p.id});
      return;
    }
    logger?.log('prompt_rendered',
        {'msg_id': m.id, 'prompt_id': p.id, 'channel': 'audio'});
    final startMono = StudyClock.monoMs();
    String channel;
    try {
      channel = await output.speak(p);
    } catch (e) {
      logger?.log('error', {'where': 'speak', 'error': e.toString()});
      return;
    }
    final interrupted = token != _renderToken;
    logger?.log('prompt_finished', {
      'msg_id': m.id,
      'prompt_id': p.id,
      'channel': 'audio',
      'source': channel,
      'duration_ms': StudyClock.monoMs() - startMono,
      'interrupted': interrupted,
    });
    _ack(m, AckStage.finished, channel: 'audio', promptId: p.id,
        extra: {'source': channel, 'interrupted': interrupted});
  }

  Future<void> _onSync(Message m) async {
    flash = true;
    notifyListeners();
    unawaited(output.vibrate(VibrationPatterns.sync));
    await _waitForFrame();
    logger?.log('sync_marker', {'msg_id': m.id});
    _ack(m, AckStage.rendered, channel: 'sync');
    unawaited(Future<void>.delayed(const Duration(milliseconds: 500), () {
      flash = false;
      notifyListeners();
    }));
  }

  Future<void> _onSessionEnd(Message m) async {
    location.stop();
    await output.stopSpeaking();
    logger?.log('session_end');
    await logger?.close();
    logger = null;
    condition = null;
    routeId = null;
    displayPrompt = null;
    sessionEnded = true;
    notifyListeners();
  }

  /// App moved to background/foreground. On iOS a backgrounded app is
  /// suspended within seconds (no prompts, no GPS), so this must be visible
  /// in the data.
  void logLifecycle(String state) => logger?.log('app_lifecycle', {'state': state});

  /// Completes when all queued messages have been handled (for tests).
  Future<void> get idle => _queue;

  Future<void> stop() async {
    await _sub?.cancel();
    client.removeListener(_syncOffset);
    location.stop();
    await output.stopSpeaking();
    logger?.log('participant_app_closed');
    await logger?.close();
  }
}
