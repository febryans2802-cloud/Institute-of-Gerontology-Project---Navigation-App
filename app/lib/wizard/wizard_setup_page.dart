library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/event_logger.dart';
import '../core/route_script.dart';
import '../core/study_design.dart';
import '../net/discovery.dart';
import '../net/wizard_server.dart';
import '../shared/storage.dart';
import 'wizard_run_page.dart';
import 'wizard_session.dart';

class WizardSetupPage extends StatefulWidget {
  const WizardSetupPage({super.key});

  @override
  State<WizardSetupPage> createState() => _WizardSetupPageState();
}

class _WizardSetupPageState extends State<WizardSetupPage> {
  final _server = WizardServer();
  final _beacon = WizardBeacon();
  final _pidCtrl = TextEditingController();
  final _enrolCtrl = TextEditingController();
  Sequence _sequence = Sequence.A;
  List<String> _ips = [];
  Map<String, RouteScript>? _routes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server.addListener(_onChange);
    _init();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    try {
      await _server.start();
      await _beacon.start(wsPort: _server.port!);
      final routes = await loadRoutes();
      final ips = await localIPv4Addresses();
      final prefs = await SharedPreferences.getInstance();
      final lastEnrol = prefs.getInt('last_enrolment') ?? 0;
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _ips = ips;
        _enrolCtrl.text = '${lastEnrol + 1}';
        _sequence = Sequence.forEnrolmentNumber(lastEnrol + 1);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _refreshIps() async {
    final ips = await localIPv4Addresses();
    if (mounted) setState(() => _ips = ips);
  }

  String _sessionId(String pid) {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${pid}_${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _startSession() async {
    final pid = _pidCtrl.text.trim();
    final routes = _routes;
    if (pid.isEmpty || routes == null) return;
    final enrol = int.tryParse(_enrolCtrl.text.trim());
    final prefs = await SharedPreferences.getInstance();
    if (enrol != null) await prefs.setInt('last_enrolment', enrol);
    final logger = await EventLogger.open(
      dir: await logDirectory(),
      sessionId: _sessionId(pid),
      participantId: pid,
      deviceRole: 'wizard',
    );
    final session = WizardSession(
      server: _server,
      logger: logger,
      participantId: pid,
      sequence: _sequence,
      routes: routes,
    );
    session.start();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WizardRunPage(session: session),
    ));
    if (!session.ended) await session.endSession();
    _pidCtrl.clear();
    if (enrol != null) {
      _enrolCtrl.text = '${enrol + 1}';
      _sequence = Sequence.forEnrolmentNumber(enrol + 1);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _server.removeListener(_onChange);
    _beacon.stop();
    _server.dispose();
    _pidCtrl.dispose();
    _enrolCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final templates = _routes?.values.where((r) => r.isTemplate).toList() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('研究人員 Wizard setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Connection', style: t.titleMedium),
                    const Spacer(),
                    IconButton(
                        onPressed: _refreshIps,
                        icon: const Icon(Icons.refresh)),
                  ]),
                  const Text('Turn ON this phone\'s Wi-Fi hotspot, then join '
                      'it from the participant phone.'),
                  const SizedBox(height: 8),
                  Text('This phone\'s IP: ${_ips.isEmpty ? '—' : _ips.join(', ')}'
                      '  port ${_server.port ?? '—'}'),
                  const SizedBox(height: 4),
                  _LinkChip(alive: _server.linkAlive, rtt: _server.lastRttMs),
                ],
              ),
            ),
          ),
          if (templates.isNotEmpty)
            Card(
              color: Colors.amber.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Warning: route(s) ${templates.map((r) => r.routeId).join(', ')} '
                  'are TEMPLATES. Replace assets/routes/*.json with the '
                  'surveyed routes before real data collection.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _pidCtrl,
            decoration: const InputDecoration(
              labelText: 'Participant code (no names)',
              hintText: 'e.g. P07',
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _enrolCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enrolment number (suggests sequence)',
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 1) {
                setState(() => _sequence = Sequence.forEnrolmentNumber(n));
              }
            },
          ),
          const SizedBox(height: 12),
          Text('Counterbalancing sequence', style: t.titleMedium),
          RadioGroup<Sequence>(
            groupValue: _sequence,
            onChanged: (v) => setState(() => _sequence = v!),
            child: Column(
              children: [
                for (final s in Sequence.values)
                  RadioListTile<Sequence>(
                    value: s,
                    dense: true,
                    title: Text('${s.name}:  1) ${s.blocks[0]}   2) ${s.blocks[1]}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pidCtrl.text.trim().isEmpty || _routes == null
                ? null
                : _startSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start session'),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.alive, this.rtt});
  final bool alive;
  final int? rtt;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(alive ? Icons.link : Icons.link_off,
          color: alive ? Colors.green.shade800 : Colors.red),
      label: Text(alive
          ? 'Participant connected${rtt != null ? ' · RTT ${rtt}ms' : ''}'
          : 'Participant not connected'),
    );
  }
}
