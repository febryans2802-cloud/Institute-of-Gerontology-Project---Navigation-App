/// UDP broadcast so the participant phone can find the wizard's IP address
/// without typing it. Manual IP entry remains available as a fallback, since
/// some Android devices filter broadcast packets.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/protocol.dart';

/// Non-loopback IPv4 addresses of this device (shown on the wizard screen).
Future<List<String>> localIPv4Addresses() async {
  final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  return [
    for (final i in ifaces)
      for (final a in i.addresses)
        if (!a.isLoopback) a.address,
  ];
}

/// Broadcasts `CANE_NAV_WIZARD:<port>` every [interval] on all interfaces.
class WizardBeacon {
  WizardBeacon({this.interval = const Duration(seconds: 2)});
  final Duration interval;

  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start({int wsPort = wizardWsPort}) async {
    if (_socket != null) return;
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    s.broadcastEnabled = true;
    _socket = s;
    final payload = utf8.encode('$discoveryMagic:$wsPort');
    Future<void> send() async {
      final targets = <String>{'255.255.255.255'};
      // Directed /24 broadcasts: needed when the hotspot is not the default
      // route (e.g. mobile data is on).
      for (final ip in await localIPv4Addresses()) {
        final p = ip.split('.');
        if (p.length == 4) targets.add('${p[0]}.${p[1]}.${p[2]}.255');
      }
      for (final t in targets) {
        try {
          s.send(payload, InternetAddress(t), discoveryUdpPort);
        } catch (_) {}
      }
    }

    await send();
    _timer = Timer.periodic(interval, (_) => send());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

class DiscoveredWizard {
  const DiscoveredWizard(this.host, this.port);
  final String host;
  final int port;
}

/// Listens for wizard beacons. Emits each distinct host once.
class WizardDiscovery {
  RawDatagramSocket? _socket;
  final _controller = StreamController<DiscoveredWizard>.broadcast();
  final _seen = <String>{};

  Stream<DiscoveredWizard> get found => _controller.stream;

  Future<void> start() async {
    if (_socket != null) return;
    final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, discoveryUdpPort,
        reuseAddress: true);
    _socket = s;
    s.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final dg = s.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true);
      if (!text.startsWith('$discoveryMagic:')) return;
      final port = int.tryParse(text.substring(discoveryMagic.length + 1));
      if (port == null) return;
      final host = dg.address.address;
      if (_seen.add('$host:$port')) {
        _controller.add(DiscoveredWizard(host, port));
      }
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
