/// Route scripts: the fixed, ordered list of prompts for each study route.
library;

import 'dart:convert';

enum Direction { left, right, straight, arrived, stop }

enum PromptKind { advance, execute, reassure, arrived, offRoute }

Direction _directionFromJson(String s) => Direction.values.firstWhere(
    (d) => d.name == s,
    orElse: () => throw FormatException('Unknown direction: $s'));

PromptKind _kindFromJson(String s) => PromptKind.values.firstWhere(
    (k) => k.name == s || (s == 'off_route' && k == PromptKind.offRoute),
    orElse: () => throw FormatException('Unknown prompt kind: $s'));

class RoutePrompt {
  const RoutePrompt({
    required this.id,
    required this.kind,
    required this.direction,
    required this.textZh,
    this.decisionPoint,
    this.landmarkZh,
    this.audioFile,
  });

  final String id;
  final int? decisionPoint;
  final PromptKind kind;
  final Direction direction;

  /// The full sentence: spoken in AH, shown as the main line in S.
  final String textZh;

  /// Optional landmark, shown as a secondary line in S.
  final String? landmarkZh;

  /// Pre-recorded audio under assets/audio/. Falls back to TTS if missing.
  final String? audioFile;

  factory RoutePrompt.fromJson(Map<String, dynamic> j) => RoutePrompt(
        id: j['id'] as String,
        decisionPoint: j['decision_point'] as int?,
        kind: _kindFromJson(j['kind'] as String),
        direction: _directionFromJson(j['direction'] as String),
        textZh: j['text_zh'] as String,
        landmarkZh: j['landmark_zh'] as String?,
        audioFile: j['audio_file'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (decisionPoint != null) 'decision_point': decisionPoint,
        'kind': kind.name,
        'direction': direction.name,
        'text_zh': textZh,
        if (landmarkZh != null) 'landmark_zh': landmarkZh,
        if (audioFile != null) 'audio_file': audioFile,
      };
}

/// Sent by the wizard's OFF-ROUTE button, independent of the route script.
const RoutePrompt offRoutePrompt = RoutePrompt(
  id: 'OFF_ROUTE',
  kind: PromptKind.offRoute,
  direction: Direction.stop,
  textZh: '請停下，工作人員會協助您',
  audioFile: 'OFF_ROUTE.m4a',
);

class RouteScript {
  const RouteScript({
    required this.routeId,
    required this.name,
    required this.prompts,
    this.isTemplate = false,
  });

  final String routeId;
  final String name;

  /// True for placeholder routes that have not been surveyed yet.
  final bool isTemplate;
  final List<RoutePrompt> prompts;

  factory RouteScript.fromJson(Map<String, dynamic> j) {
    final prompts = (j['prompts'] as List)
        .map((p) => RoutePrompt.fromJson(p as Map<String, dynamic>))
        .toList();
    final ids = <String>{};
    for (final p in prompts) {
      if (!ids.add(p.id)) {
        throw FormatException('Duplicate prompt id ${p.id} in ${j['route_id']}');
      }
    }
    if (prompts.isEmpty || prompts.last.kind != PromptKind.arrived) {
      throw FormatException(
          'Route ${j['route_id']} must end with an "arrived" prompt');
    }
    return RouteScript(
      routeId: j['route_id'] as String,
      name: j['name'] as String,
      isTemplate: j['template'] as bool? ?? false,
      prompts: prompts,
    );
  }

  factory RouteScript.parse(String source) =>
      RouteScript.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
