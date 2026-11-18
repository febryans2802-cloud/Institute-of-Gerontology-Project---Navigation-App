/// What the participant sees. Deliberately has no tappable controls: the
/// phone is in a pouch in the AH condition. Exiting needs a long-press in the
/// top-left corner followed by a confirmation.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/route_script.dart';
import '../core/study_design.dart';
import '../net/participant_client.dart';
import '../shared/storage.dart';
import 'outputs.dart';
import 'participant_session.dart';

class ParticipantRunPage extends StatefulWidget {
  const ParticipantRunPage({super.key, required this.host, required this.port});
  final String host;
  final int port;

  @override
  State<ParticipantRunPage> createState() => _ParticipantRunPageState();
}

class _ParticipantRunPageState extends State<ParticipantRunPage> {
  late final ParticipantClient _client;
  late final ParticipantSession _session;
  final _location = DeviceLocationSource();
  bool? _locationOk;

  @override
  void initState() {
    super.initState();
    _client = ParticipantClient();
    _session = ParticipantSession(
      client: _client,
      output: DeviceGuidanceOutput(),
      location: _location,
      logDir: logDirectory,
      waitForFrame: () => SchedulerBinding.instance.endOfFrame,
    );
    _session.addListener(_onChange);
    _session.start();
    _client.connect(widget.host, port: widget.port);
    unawaited(WakelockPlus.enable());
    unawaited(_location.ensurePermission().then((ok) {
      if (mounted) setState(() => _locationOk = ok);
    }));
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_onChange);
    unawaited(_session.stop().then((_) => _client.disconnect()));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave participant screen?'),
        content: const Text('The connection to the wizard will close.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final Widget body;
    if (s.flash) {
      body = const ColoredBox(color: Colors.white, child: SizedBox.expand());
    } else if (s.sessionEnded) {
      body = const _CenterText('完成，謝謝您！', 'Session finished');
    } else if (s.condition == null) {
      body = _CenterText(
        _client.isConnected ? '請稍候' : '連線中…',
        _client.isConnected
            ? 'Connected. Waiting for the researcher to start.'
            : 'Connecting to ${widget.host}…',
      );
    } else if (s.condition == Condition.audioHaptic) {
      body = const _CenterText('語音導航中', 'Audio guidance', dim: true);
    } else {
      body = _ScreenPrompt(prompt: s.displayPrompt);
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: s.condition == Condition.audioHaptic || s.flash
            ? Colors.black
            : Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(
                left: 0,
                top: 0,
                child: GestureDetector(
                  onLongPress: _confirmExit,
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.all(8),
                    child: _StatusDot(
                      connected: _client.isConnected,
                      locationOk: _locationOk,
                      label: s.condition?.code,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(
      {required this.connected, required this.locationOk, this.label});
  final bool connected;
  final bool? locationOk;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = !connected
        ? Colors.red
        : locationOk == false
            ? Colors.orange
            : Colors.green;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      if (label != null) ...[
        const SizedBox(width: 4),
        Text(label!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    ]);
  }
}

class _CenterText extends StatelessWidget {
  const _CenterText(this.zh, this.en, {this.dim = false});
  final String zh;
  final String en;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = dim ? Colors.grey.shade700 : Colors.black87;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(zh,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 8),
          Text(en, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ]),
      ),
    );
  }
}

/// Screen condition: one instruction, big arrow, no map (§5.3).
class _ScreenPrompt extends StatelessWidget {
  const _ScreenPrompt({required this.prompt});
  final RoutePrompt? prompt;

  static IconData _icon(Direction d) => switch (d) {
        Direction.left => Icons.turn_left,
        Direction.right => Icons.turn_right,
        Direction.straight => Icons.straight,
        Direction.arrived => Icons.flag,
        Direction.stop => Icons.front_hand,
      };

  @override
  Widget build(BuildContext context) {
    final p = prompt;
    if (p == null) {
      return const _CenterText('請準備出發', 'Get ready');
    }
    return LayoutBuilder(builder: (context, box) {
      final iconSize = box.maxHeight * 0.42;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon(p.direction),
                size: iconSize,
                color: p.direction == Direction.stop
                    ? Colors.red.shade800
                    : Colors.black),
            const SizedBox(height: 16),
            Text(
              p.textZh,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2),
            ),
            if (p.landmarkZh != null) ...[
              const SizedBox(height: 12),
              Text(
                p.landmarkZh!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, color: Colors.black87),
              ),
            ],
          ],
        ),
      );
    });
  }
}
