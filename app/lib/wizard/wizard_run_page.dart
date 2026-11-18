/// The researcher's control screen during a session: big NEXT button for
/// prompts, observer event buttons, and link status.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/study_design.dart';
import 'wizard_session.dart';

class WizardRunPage extends StatefulWidget {
  const WizardRunPage({super.key, required this.session});
  final WizardSession session;

  @override
  State<WizardRunPage> createState() => _WizardRunPageState();
}

class _WizardRunPageState extends State<WizardRunPage> {
  WizardSession get s => widget.session;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    s.addListener(_onChange);
    s.server.addListener(_onChange);
    _lifecycle =
        AppLifecycleListener(onStateChange: (st) => s.logLifecycle(st.name));
    unawaited(WakelockPlus.enable());
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    s.removeListener(_onChange);
    s.server.removeListener(_onChange);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _tap(VoidCallback f) {
    HapticFeedback.mediumImpact();
    f();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(msg), duration: const Duration(milliseconds: 1200)));
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _note() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Note'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) {
      s.note(text.trim());
      _toast('Note saved');
    }
  }

  Future<void> _endSession() async {
    if (!await _confirm('End session?',
        'Logs will be closed. The participant phone will show "finished".')) {
      return;
    }
    await s.endSession();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = s.active;
    return PopScope(
      canPop: s.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_endSession());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${s.participantId} · Seq ${s.sequence.name}'),
          actions: [
            IconButton(
              tooltip: 'End session',
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusBar(),
              Expanded(child: a == null ? _blockPicker() : _blockControls(a)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    final alive = s.server.linkAlive;
    final off = s.server.estimator.best;
    return Container(
      color: alive ? Colors.green.shade100 : Colors.red.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12),
        child: Wrap(spacing: 12, children: [
          Text(alive ? '● CONNECTED' : '● NOT CONNECTED',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: alive ? Colors.green.shade900 : Colors.red.shade900)),
          if (s.server.lastRttMs != null) Text('RTT ${s.server.lastRttMs}ms'),
          if (off != null) Text('offset ${off.offsetMs}ms'),
          if (s.lastLatencyMs != null) Text('latency ${s.lastLatencyMs}ms'),
          if (s.lastAckInfo != null) Text('ack: ${s.lastAckInfo}'),
        ]),
      ),
    );
  }

  Widget _blockPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Practice (familiarisation)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(children: [
          for (final c in Condition.values) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => s.startBlock(practiceCondition: c),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Practice ${c.code}'),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 24),
        Text('Study blocks', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < s.sequence.blocks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    s.completedBlocks.contains(i) ? Colors.grey : null,
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () async {
                if (s.completedBlocks.contains(i) &&
                    !await _confirm('Repeat block?',
                        'Block ${i + 1} was already completed.')) {
                  return;
                }
                s.startBlock(index: i);
              },
              child: Text(
                'Block ${i + 1}: ${s.sequence.blocks[i].condition.label} '
                'on ${s.sequence.blocks[i].routeId}'
                '${s.completedBlocks.contains(i) ? '  ✓' : ''}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _tap(s.syncMarker),
          icon: const Icon(Icons.flash_on),
          label: const Text('Sync marker'),
        ),
      ],
    );
  }

  Widget _blockControls(ActiveBlock a) {
    final next = a.nextPrompt;
    final total = a.route.prompts.length;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${a.isPractice ? 'PRACTICE · ' : ''}'
            '${a.block.condition.label} · ${a.route.routeId} '
            '(${a.nextIndex}/$total sent)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (s.lastSentPrompt != null)
            Text('Last: ${s.lastSentPrompt!.id}  ${s.lastSentPrompt!.textZh}',
                style: const TextStyle(color: Colors.black54)),
          if (s.unackedPrompt != null)
            Container(
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: Text(
                'NOT RECEIVED: ${s.unackedPrompt!.id} — press REPEAT',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          const SizedBox(height: 8),
          // NEXT: the main action, made as large as possible.
          Expanded(
            flex: 3,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: next == null ? null : () => _tap(() => s.next()),
              child: next == null
                  ? const Text('Route finished — end block',
                      style: TextStyle(fontSize: 20))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('NEXT',
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold)),
                        Text('${next.id} · ${next.kind.name}',
                            style: const TextStyle(fontSize: 14)),
                        Text(next.textZh,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: s.lastSentPrompt == null
                    ? null
                    : () => _tap(s.repeatLast),
                child: const Text('REPEAT'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _tap(s.offRoute),
                child: const Text('OFF-ROUTE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _tap(s.syncMarker),
                child: const Text('SYNC'),
              ),
            ),
          ]),
          const Divider(),
          Expanded(
            flex: 2,
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final e in ObserverEvent.values)
                  _obsButton(e.label, () {
                    s.observe(e);
                    _toast('Logged: ${e.code}');
                  }),
                _obsButton(
                  s.signalWaitActive ? '綠燈 Signal END' : '等燈 Signal wait',
                  s.toggleSignalWait,
                  highlight: s.signalWaitActive,
                ),
                _obsButton('筆記 Note', _note),
                _obsButton('復原 Undo', () {
                  final code = s.undo();
                  _toast(code == null ? 'Nothing to undo' : 'Undid: $code');
                }, enabled: s.canUndo),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final finished = a.nextPrompt == null;
              if (!finished &&
                  !await _confirm('End block early?',
                      'Not all prompts were sent. It will be logged as aborted.')) {
                return;
              }
              s.endBlock(aborted: !finished);
            },
            child: const Text('End block'),
          ),
        ],
      ),
    );
  }

  Widget _obsButton(String label, VoidCallback onTap,
      {bool highlight = false, bool enabled = true}) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: highlight ? Colors.amber : null,
        padding: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: enabled ? () => _tap(onTap) : null,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
