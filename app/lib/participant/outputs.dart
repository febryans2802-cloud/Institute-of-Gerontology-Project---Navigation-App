/// Hardware outputs on the participant phone, behind interfaces so the
/// session logic can be tested without plugins.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../core/route_script.dart';
import '../core/vibration_patterns.dart';

abstract class GuidanceOutput {
  Future<void> vibrate(VibrationPattern p);

  /// Plays the prompt and completes when playback ends.
  /// Returns the channel used: "audio_file" or "tts".
  Future<String> speak(RoutePrompt p);

  Future<void> stopSpeaking();
}

class DeviceGuidanceOutput implements GuidanceOutput {
  final _player = AudioPlayer();
  final _tts = FlutterTts();
  bool? _amplitude;
  bool _ttsReady = false;
  bool _audioReady = false;

  /// Prompts must play even when the iPhone ring/silent switch is on silent,
  /// and must route to the Bluetooth bone-conduction headset. On Android
  /// these are the defaults; on iOS they require the "playback" category.
  Future<void> _ensureAudioSession() async {
    if (_audioReady) return;
    _audioReady = true;
    await AudioPlayer.global.setAudioContext(AudioContextConfig(
      respectSilence: false,
      focus: AudioContextConfigFocus.duckOthers,
    ).build());
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
  }

  @override
  Future<void> vibrate(VibrationPattern p) async {
    _amplitude ??= await Vibration.hasAmplitudeControl();
    if (_amplitude!) {
      await Vibration.vibrate(pattern: p.timings, intensities: p.intensities);
    } else {
      await Vibration.vibrate(pattern: p.timings);
    }
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> speak(RoutePrompt p) async {
    await _ensureAudioSession();
    final file = p.audioFile;
    if (file != null && await _assetExists('assets/audio/$file')) {
      final done = _player.onPlayerComplete.first;
      await _player.play(AssetSource('audio/$file'));
      await done.timeout(const Duration(seconds: 15), onTimeout: () {});
      return 'audio_file';
    }
    // Fallback for development and piloting before prompts are recorded.
    if (!_ttsReady) {
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    }
    await _tts.speak(p.textZh);
    return 'tts';
  }

  @override
  Future<void> stopSpeaking() async {
    await _player.stop();
    await _tts.stop();
  }
}

class GpsFix {
  const GpsFix(this.data);
  final Map<String, dynamic> data;
}

abstract class LocationSource {
  Future<bool> ensurePermission();
  void start(void Function(GpsFix fix) onFix);
  void stop();
}

class DeviceLocationSource implements LocationSource {
  StreamSubscription<Position>? _sub;

  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  @override
  void start(void Function(GpsFix fix) onFix) {
    stop();
    final LocationSettings settings = Platform.isIOS
        ? AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
          )
        : AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
          );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) => onFix(GpsFix({
        'lat': p.latitude,
        'lon': p.longitude,
        'accuracy_m': p.accuracy,
        'speed_mps': p.speed,
        'heading': p.heading,
        'altitude_m': p.altitude,
        'fix_time': p.timestamp.toIso8601String(),
      })),
      onError: (_) {},
    );
  }

  @override
  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
