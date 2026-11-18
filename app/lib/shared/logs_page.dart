library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'storage.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  Directory? _dir;
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final dir = await logDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (mounted) {
      setState(() {
        _dir = dir;
        _files = files;
      });
    }
  }

  Future<void> _share(List<File> files) async {
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      files: [for (final f in files) XFile(f.path, mimeType: 'application/json')],
      subject: 'cane_nav logs',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Share all',
            onPressed: () => _share(_files),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Folder: ${_dir?.path ?? '…'}\n'
              'Copy over USB, or share. Logs are never deleted by the app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? const Center(child: Text('No logs yet'))
                : ListView(
                    children: [
                      for (final f in _files)
                        ListTile(
                          title: Text(f.uri.pathSegments.last),
                          subtitle: Text(
                              '${(f.lengthSync() / 1024).toStringAsFixed(1)} KB · '
                              '${f.lastModifiedSync()}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _share([f]),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
