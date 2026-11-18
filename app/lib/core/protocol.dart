/// Wizard ↔ participant WebSocket messages (JSON text frames).
library;

import 'dart:convert';

const int wizardWsPort = 8765;
const int discoveryUdpPort = 8766;
const String discoveryMagic = 'CANE_NAV_WIZARD';

/// An iPhone's Personal Hotspot always gives itself this address.
const String iPhoneHotspotHost = '172.20.10.1';

abstract final class MsgType {
  // participant → wizard
  static const hello = 'hello';
  static const pong = 'pong';
  static const ack = 'ack';

  // wizard → participant
  static const ping = 'ping';
  static const session = 'session';
  static const conditionStart = 'condition_start';
  static const conditionEnd = 'condition_end';
  static const prompt = 'prompt';
  static const syncMarker = 'sync_marker';
  static const sessionEnd = 'session_end';
}

/// Ack stages reported by the participant for a prompt or sync marker.
abstract final class AckStage {
  static const received = 'received';
  static const rendered = 'rendered';
  static const finished = 'finished';
}

class Message {
  const Message(this.type, this.id, [this.data = const {}]);

  final String type;

  /// Unique per sender; acks refer to it via data['ref_id'].
  final int id;
  final Map<String, dynamic> data;

  String encode() => jsonEncode({'type': type, 'id': id, 'data': data});

  static Message decode(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic> || j['type'] is! String || j['id'] is! int) {
      throw const FormatException('Malformed message');
    }
    return Message(j['type'] as String, j['id'] as int,
        (j['data'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  @override
  String toString() => 'Message($type #$id $data)';
}

class MessageIdCounter {
  int _next = 1;
  int next() => _next++;
}
