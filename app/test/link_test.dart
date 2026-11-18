/// End-to-end test: real WizardServer and ParticipantClient over a loopback
/// socket, with real WizardSession/ParticipantSession and fake hardware.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cane_nav/core/event_logger.dart';
import 'package:cane_nav/core/route_script.dart';
import 'package:cane_nav/core/study_design.dart';
import 'package:cane_nav/core/vibration_patterns.dart';
import 'package:cane_nav/net/participant_client.dart';
import 'package:cane_nav/net/wizard_server.dart';
import 'package:cane_nav/participant/outputs.dart';
import 'package:cane_nav/participant/participant_session.dart';
import 'package:cane_nav/wizard/wizard_session.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOutput implements GuidanceOutput {
  final vibrations = <String>[];
  final spoken = <String>[];
  Duration speakTime = const Duration(milliseconds: 50);

  @override
  Future<void> vibrate(VibrationPattern p) async => vibrations.add(p.name);

  @override
  Future<String> speak(RoutePrompt p) async {
    spoken.add(p.id);
    await Future<void>.delayed(speakTime);
    return 'tts';
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeLocation implements LocationSource {
  Timer? _t;
  int started = 0;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  void start(void Function(GpsFix fix) onFix) {
    started++;
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 100),
        (_) => onFix(const GpsFix({'lat': 23.0, 'lon': 120.2, 'accuracy_m': 5.0})));
  }

  @override
  void stop() {
    _t?.cancel();
    _t = null;
  }
}

Future<void> waitFor(bool Function() cond,
    {Duration timeout = const Duration(seconds: 5), String? what}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > timeout) fail('Timed out waiting for ${what ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

List<Map<String, dynamic>> readLog(File f) => f
    .readAsLinesSync()
    .map((l) => jsonDecode(l) as Map<String, dynamic>)
    .toList();

Map<String, RouteScript> loadRoutesFromDisk() => {
      for (final id in ['PRACTICE', 'R1', 'R2'])
        id: RouteScript.parse(File('assets/routes/$id.json').readAsStringSync()),
    };

void main() {
  late Directory tmp;
  late WizardServer server;
  late ParticipantClient client;
  late FakeOutput output;
  late FakeLocation location;
  late WizardSession wizard;
  late ParticipantSession participant;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cane_nav_link');
    server = WizardServer(pingInterval: const Duration(milliseconds: 100));
    await server.start(port: 0);
    final wLog = await EventLogger.open(
        dir: Directory('${tmp.path}/wizard'),
        sessionId: 'P01_TEST',
        participantId: 'P01',
        deviceRole: 'wizard');
    wizard = WizardSession(
      server: server,
      logger: wLog,
      participantId: 'P01',
      sequence: Sequence.B, // AH on R1, then S on R2
      routes: loadRoutesFromDisk(),
      clockLogInterval: Duration.zero,
      ackTimeout: const Duration(milliseconds: 300),
    );
    wizard.start();

    client = ParticipantClient(retryDelay: const Duration(milliseconds: 100));
    output = FakeOutput();
    location = FakeLocation();
    participant = ParticipantSession(
      client: client,
      output: output,
      location: location,
      logDir: () async => Directory('${tmp.path}/participant'),
    );
    participant.start();
    client.connect('127.0.0.1', port: server.port!);
  });

  tearDown(() async {
    await participant.stop();
    await client.disconnect();
    await server.stop();
    tmp.deleteSync(recursive: true);
  });

  test('full session: blocks, prompts in both conditions, acks, sync, logs',
      () async {
    await waitFor(() => server.linkAlive, what: 'link');
    await waitFor(() => participant.logger != null, what: 'participant log');
    await waitFor(() => server.estimator.best != null, what: 'clock sample');
    // Same machine → offset ~0.
    expect(server.estimator.best!.offsetMs.abs(), lessThan(50));
    await waitFor(() => client.clockOffsetMs != null, what: 'offset relayed');

    // ---- Block 1: AH on R1 ----
    wizard.startBlock(index: 0);
    await waitFor(() => participant.condition == Condition.audioHaptic);
    expect(participant.routeId, 'R1');
    expect(location.started, 1);

    expect(wizard.next(), isTrue); // R1-P01-ADV (left)
    await waitFor(() => output.spoken.contains('R1-P01-ADV'), what: 'AH speech');
    expect(output.vibrations.last, 'left');
    expect(participant.displayPrompt, isNull,
        reason: 'AH must not show direction info on screen');

    // A second prompt sent quickly supersedes the first's pending audio.
    wizard.next(); // R1-P01-EXE
    wizard.next(); // R1-P02-ADV (right)
    await waitFor(() => output.spoken.contains('R1-P02-ADV'), what: 'latest prompt spoken');
    expect(output.spoken.contains('R1-P01-EXE'), isFalse);
    expect(output.vibrations.last, 'right');

    wizard.observe(ObserverEvent.stopObserved);
    wizard.toggleSignalWait();
    expect(wizard.undo(), 'signal_wait_start');
    expect(wizard.signalWaitActive, isFalse);
    wizard.syncMarker();
    await waitFor(() => output.vibrations.contains('sync'), what: 'sync');

    while (wizard.next()) {}
    await waitFor(() => output.spoken.contains('R1-END'), what: 'arrival');
    await waitFor(
        () => readLog(participant.logger!.file).any((e) =>
            e['event'] == 'prompt_finished' &&
            e['data']['prompt_id'] == 'R1-END' &&
            e['data']['interrupted'] == false),
        what: 'arrival finished');
    wizard.endBlock();
    await waitFor(() => participant.condition == null, what: 'block end');
    expect(wizard.completedBlocks, {0});

    // ---- Block 2: Screen on R2 ----
    wizard.startBlock(index: 1);
    await waitFor(() => participant.condition == Condition.screen);
    final spokenBefore = output.spoken.length;
    wizard.next(); // R2-P01-ADV
    await waitFor(() => participant.displayPrompt?.id == 'R2-P01-ADV',
        what: 'screen prompt');
    await waitFor(() => wizard.lastLatencyMs != null, what: 'latency');
    expect(output.vibrations.last, 'generic',
        reason: 'Screen condition uses a direction-free attention cue');
    wizard.offRoute();
    await waitFor(() => participant.displayPrompt?.id == 'OFF_ROUTE');
    wizard.repeatLast();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(output.spoken.length, spokenBefore, reason: 'no audio in Screen');
    wizard.endBlock(aborted: true);
    expect(wizard.completedBlocks, {0}, reason: 'aborted block not completed');

    await wizard.endSession();
    await waitFor(() => participant.sessionEnded, what: 'session end');

    // ---- Logs ----
    final wFile = Directory('${tmp.path}/wizard').listSync().single as File;
    final pFile = Directory('${tmp.path}/participant').listSync().single as File;
    final w = readLog(wFile);
    final p = readLog(pFile);

    List<String> events(List<Map<String, dynamic>> l) =>
        [for (final e in l) e['event'] as String];

    expect(events(w).first, 'session_start');
    expect(events(w).last, 'session_end');
    expect(events(p).first, 'session_joined');
    expect(events(p).last, 'session_end');
    expect(events(w), containsAll([
      'clock_sync', 'condition_start', 'prompt_sent', 'prompt_ack',
      'observer_event', 'observer_undo', 'sync_marker', 'condition_end',
    ]));
    expect(events(p), containsAll([
      'condition_start', 'prompt_received', 'prompt_rendered',
      'prompt_finished', 'prompt_superseded', 'gps_fix', 'sync_marker',
    ]));

    // seq strictly increasing in each file
    for (final l in [w, p]) {
      for (var i = 1; i < l.length; i++) {
        expect(l[i]['seq'], l[i - 1]['seq'] + 1);
      }
    }

    // Context fields carried on lines inside blocks.
    final firstPrompt = w.firstWhere((e) => e['event'] == 'prompt_sent');
    expect(firstPrompt['condition'], 'AH');
    expect(firstPrompt['route_id'], 'R1');
    expect(firstPrompt['data']['transmitted'], isTrue);
    expect(events(w), isNot(contains('prompt_unacked')));
    final pGps = p.firstWhere((e) => e['event'] == 'gps_fix');
    expect(pGps['condition'], 'AH');

    // Every prompt the wizard sent was received by the participant.
    final sentIds = {
      for (final e in w.where((e) => e['event'] == 'prompt_sent'))
        e['data']['msg_id'],
    };
    final recvIds = {
      for (final e in p.where((e) => e['event'] == 'prompt_received'))
        e['data']['msg_id'],
    };
    expect(recvIds, sentIds);

    // Rendered acks carry a computed latency.
    final rendered = w.where((e) =>
        e['event'] == 'prompt_ack' && e['data']['stage'] == 'rendered');
    expect(rendered, isNotEmpty);
    for (final e in rendered) {
      expect(e['data']['latency_ms'], isA<int>());
      expect((e['data']['latency_ms'] as int).abs(), lessThan(1000));
    }

    // Undo references the right event.
    final undo = w.firstWhere((e) => e['event'] == 'observer_undo');
    final target = w.firstWhere((e) => e['seq'] == undo['data']['ref_seq']);
    expect(target['data']['code'], 'signal_wait_start');

    // Participant offset recorded once known.
    expect(p.last['clock_offset_ms'], isA<int>());
  });

  test('participant reconnect resumes the current block without a new log',
      () async {
    await waitFor(() => server.linkAlive, what: 'link');
    await waitFor(() => participant.logger != null);
    wizard.startBlock(index: 0);
    await waitFor(() => participant.condition == Condition.audioHaptic);
    final logPath = participant.logger!.file.path;

    // Drop the connection from the participant side.
    await client.disconnect();
    await waitFor(() => !server.linkAlive, what: 'link down');
    expect(wizard.next(), isTrue); // sent while disconnected
    final sent = readLog(wizard.logger.file).lastWhere((e) => e['event'] == 'prompt_sent');
    expect(sent['data']['transmitted'], isFalse);

    // The watchdog warns the wizard that the prompt was not received.
    await waitFor(() => wizard.unackedPrompt?.id == 'R1-P01-ADV',
        what: 'unacked warning');
    expect(readLog(wizard.logger.file).map((e) => e['event']),
        contains('prompt_unacked'));

    client.connect('127.0.0.1', port: server.port!);
    await waitFor(() => server.linkAlive, what: 'relink');
    await participant.idle;
    expect(participant.logger!.file.path, logPath);
    expect(participant.condition, Condition.audioHaptic);

    // REPEAT delivers the prompt that was missed.
    wizard.repeatLast();
    await waitFor(() => output.spoken.contains('R1-P01-ADV'), what: 'repeat after reconnect');
    expect(wizard.unackedPrompt, isNull, reason: 'warning clears on receipt');

    final p = readLog(participant.logger!.file);
    expect(p.where((e) => e['event'] == 'condition_start'), hasLength(1),
        reason: 'resent condition_start must be deduplicated');
    expect(p.map((e) => e['event']), contains('connection_restored'));
  });
}
