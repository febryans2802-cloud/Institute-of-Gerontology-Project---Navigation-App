library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/protocol.dart';
import '../net/discovery.dart';
import 'participant_run_page.dart';

class ParticipantSetupPage extends StatefulWidget {
  const ParticipantSetupPage({super.key});

  @override
  State<ParticipantSetupPage> createState() => _ParticipantSetupPageState();
}

class _ParticipantSetupPageState extends State<ParticipantSetupPage> {
  final _discovery = WizardDiscovery();
  final _found = <DiscoveredWizard>[];
  final _ipCtrl = TextEditingController();
  StreamSubscription<DiscoveredWizard>? _sub;
  String? _discoveryError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _ipCtrl.text = prefs.getString('wizard_ip') ?? '';
    try {
      await _discovery.start();
      _sub = _discovery.found.listen((w) {
        if (mounted) setState(() => _found.add(w));
      });
    } catch (e) {
      if (mounted) setState(() => _discoveryError = e.toString());
    }
  }

  Future<void> _connect(String host, int port) async {
    host = host.trim();
    if (host.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_ip', host);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ParticipantRunPage(host: host, port: port),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _discovery.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('受試者 Participant setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Connect this phone to the wizard phone\'s Wi-Fi hotspot.\n'
            '2. Pick the wizard below, or type its IP address.\n'
            '3. Pair the bone-conduction headset and set media volume.',
          ),
          const SizedBox(height: 16),
          Text('Wizards found on this network',
              style: Theme.of(context).textTheme.titleMedium),
          if (_discoveryError != null)
            Text('Discovery unavailable: $_discoveryError',
                style: const TextStyle(color: Colors.red)),
          if (_found.isEmpty && _discoveryError == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Searching…'),
              ]),
            ),
          for (final w in _found)
            Card(
              child: ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: Text(w.host),
                subtitle: Text('port ${w.port}'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _connect(w.host, w.port),
              ),
            ),
          const Divider(height: 32),
          Text('Manual', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _ipCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Wizard IP address',
              hintText: 'e.g. 192.168.43.1',
            ),
          ),
          Wrap(spacing: 8, children: [
            ActionChip(
              label: const Text('Wizard is an iPhone: 172.20.10.1'),
              onPressed: () => setState(() => _ipCtrl.text = iPhoneHotspotHost),
            ),
          ]),
          const Text(
            'Automatic search does not work on iPhones (Apple blocks Wi-Fi '
            'broadcast). Type the IP shown on the wizard screen.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _connect(_ipCtrl.text, wizardWsPort),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
