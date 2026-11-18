/// WebSocket client run on the participant phone. Reconnects automatically.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/protocol.dart';

class ParticipantClient extends ChangeNotifier {
  ParticipantClient({this.retryDelay = const Duration(seconds: 2)});

  final Duration retryDelay;

  WebSocket? _ws;
  String? _host;
  int _port = wizardWsPort;
  bool _wantConnected = false;
  Timer? _retryTimer;
  final _ids = MessageIdCounter();
  final _incoming = StreamController<Message>.broadcast();

  /// Latest clock offset (participant − wizard) as estimated by the wizard.
  int? clockOffsetMs;

  /// Called on every (re)connect, before any wizard messages arrive.
  void Function()? onConnected;
  void Function()? onDisconnected;

  /// Messages from the wizard other than pings.
  Stream<Message> get messages => _incoming.stream;

  bool get isConnected => _ws?.readyState == WebSocket.open;
  String? get host => _host;

  void connect(String host, {int port = wizardWsPort}) {
    _host = host;
    _port = port;
    _wantConnected = true;
    _retryTimer?.cancel();
    unawaited(_attempt());
  }

  Future<void> _attempt() async {
    if (!_wantConnected || _ws != null) return;
    try {
      final ws = await WebSocket.connect('ws://$_host:$_port')
          .timeout(const Duration(seconds: 3));
      if (!_wantConnected) {
        await ws.close();
        return;
      }
      ws.pingInterval = const Duration(seconds: 2);
      _ws = ws;
      ws.listen(
        _onRaw,
        onDone: () => _onGone(ws),
        onError: (_) => _onGone(ws),
        cancelOnError: true,
      );
      send(MsgType.hello, {
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
      });
      onConnected?.call();
      notifyListeners();
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    final Message msg;
    try {
      msg = Message.decode(raw);
    } on FormatException {
      return;
    }
    if (msg.type == MsgType.ping) {
      // Reply first, with as little work as possible before stamping t1.
      final t1 = StudyClock.wallMs();
      send(MsgType.pong, {'ref_id': msg.id, 't1': t1});
      final off = msg.data['offset_ms'];
      if (off is int && off != clockOffsetMs) {
        clockOffsetMs = off;
        notifyListeners();
      }
      return;
    }
    _incoming.add(msg);
  }

  void _onGone(WebSocket ws) {
    if (ws != _ws) return;
    _ws = null;
    onDisconnected?.call();
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wantConnected) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () => unawaited(_attempt()));
  }

  /// Returns false if not connected.
  bool send(String type, [Map<String, dynamic> data = const {}]) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) return false;
    try {
      ws.add(Message(type, _ids.next(), data).encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _wantConnected = false;
    _retryTimer?.cancel();
    final ws = _ws;
    _ws = null;
    await ws?.close();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    _incoming.close();
    super.dispose();
  }
}
