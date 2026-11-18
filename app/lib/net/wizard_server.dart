/// WebSocket server run on the wizard (researcher) phone.
///
/// The wizard phone hosts a Wi-Fi hotspot; the participant phone joins it and
/// connects here. Only one participant connection is kept at a time: a new
/// connection replaces the old one (e.g. after the participant app restarts).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/clock_sync.dart';
import '../core/protocol.dart';

class WizardServer extends ChangeNotifier {
  WizardServer({
    this.pingInterval = const Duration(seconds: 1),
    this.staleAfter = const Duration(seconds: 3),
  });

  final Duration pingInterval;
  final Duration staleAfter;

  HttpServer? _http;
  WebSocket? _client;
  Timer? _pingTimer;
  final _ids = MessageIdCounter();
  final _pendingPings = <int, int>{}; // ping id → t0 (wizard wall ms)
  final estimator = ClockSyncEstimator();
  final _incoming = StreamController<Message>.broadcast();

  int? _lastPongWallMs;
  int? lastRttMs;
  bool _wasAlive = false;

  /// Called with each new clock sample (and the current best estimate).
  void Function(ClockSample sample, ClockSample best)? onClockSample;

  /// Called when the link goes up/down (based on pong freshness).
  void Function(bool alive)? onLinkChanged;

  /// Messages from the participant other than pongs.
  Stream<Message> get messages => _incoming.stream;

  bool get isRunning => _http != null;
  int? get port => _http?.port;

  /// True if a participant is connected and answered a ping recently.
  bool get linkAlive {
    final t = _lastPongWallMs;
    return _client != null &&
        t != null &&
        StudyClock.wallMs() - t <= staleAfter.inMilliseconds;
  }

  Future<void> start({int port = wizardWsPort}) async {
    if (_http != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _http = server;
    server.listen(_handleRequest, onError: (_) {});
    _pingTimer = Timer.periodic(pingInterval, (_) => _tick());
    notifyListeners();
  }

  Future<void> _handleRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write('cane_nav wizard')
        ..close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    final old = _client;
    _client = ws;
    _lastPongWallMs = null;
    estimator.reset();
    if (old != null) unawaited(old.close(WebSocketStatus.goingAway, 'replaced'));
    ws.listen(
      (raw) => _onRaw(ws, raw),
      onDone: () => _onClientGone(ws),
      onError: (_) => _onClientGone(ws),
      cancelOnError: true,
    );
    _sendPing();
    notifyListeners();
  }

  void _onRaw(WebSocket from, dynamic raw) {
    if (from != _client || raw is! String) return;
    final Message msg;
    try {
      msg = Message.decode(raw);
    } on FormatException {
      return;
    }
    if (msg.type == MsgType.pong) {
      _onPong(msg);
    } else {
      _incoming.add(msg);
    }
  }

  void _onPong(Message msg) {
    final t2 = StudyClock.wallMs();
    final refId = msg.data['ref_id'] as int?;
    final t1 = msg.data['t1'] as int?;
    final t0 = refId == null ? null : _pendingPings.remove(refId);
    _lastPongWallMs = t2;
    if (t0 == null || t1 == null) return;
    final sample = ClockSample.fromTimes(t0, t1, t2);
    lastRttMs = sample.rttMs;
    estimator.add(sample);
    final best = estimator.best;
    if (best != null) onClockSample?.call(sample, best);
    _checkLink();
    notifyListeners();
  }

  void _onClientGone(WebSocket ws) {
    if (ws != _client) return;
    _client = null;
    _checkLink();
    notifyListeners();
  }

  void _tick() {
    _sendPing();
    // Drop pings that will never be answered.
    final cutoff = StudyClock.wallMs() - 10000;
    _pendingPings.removeWhere((_, t0) => t0 < cutoff);
    _checkLink();
  }

  void _checkLink() {
    final alive = linkAlive;
    if (alive != _wasAlive) {
      _wasAlive = alive;
      onLinkChanged?.call(alive);
      notifyListeners();
    }
  }

  void _sendPing() {
    if (_client == null) return;
    final id = _ids.next();
    final t0 = StudyClock.wallMs();
    _pendingPings[id] = t0;
    _rawSend(Message(MsgType.ping, id, {
      't0': t0,
      'offset_ms': estimator.best?.offsetMs,
    }));
  }

  /// Sends a message built with a fresh id. Returns the message, or null if
  /// no participant is connected.
  Message? send(String type, [Map<String, dynamic> data = const {}]) {
    final msg = Message(type, _ids.next(), data);
    return _rawSend(msg) ? msg : null;
  }

  bool _rawSend(Message msg) {
    final c = _client;
    if (c == null || c.readyState != WebSocket.open) return false;
    try {
      c.add(msg.encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _client?.close();
    _client = null;
    await _http?.close(force: true);
    _http = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stop());
    _incoming.close();
    super.dispose();
  }
}
