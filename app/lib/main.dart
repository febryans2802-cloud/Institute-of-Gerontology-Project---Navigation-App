import 'package:material_ui/material_ui.dart';

import 'participant/participant_setup_page.dart';
import 'shared/logs_page.dart';
import 'wizard/wizard_setup_page.dart';

void main() {
  runApp(const CaneNavApp());
}

class CaneNavApp extends StatelessWidget {
  const CaneNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cane Nav Study',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget big(String title, String subtitle, IconData icon, Widget page) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page)),
            child: Row(
              children: [
                Icon(icon, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Cane Nav Study')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          big('研究人員 Wizard', 'Researcher phone: hosts hotspot, sends prompts',
              Icons.support_agent, const WizardSetupPage()),
          big('受試者 Participant', 'Phone carried by the participant',
              Icons.directions_walk, const ParticipantSetupPage()),
          big('紀錄檔 Logs', 'View and export session logs', Icons.folder_open,
              const LogsPage()),
        ],
      ),
    );
  }
}
