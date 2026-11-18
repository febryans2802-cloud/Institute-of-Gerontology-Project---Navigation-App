library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/route_script.dart';
import '../core/study_design.dart';

/// Logs go to app-specific external storage when available, so they can be
/// copied over USB from Android/data/org.navstudy.cane_nav/files/logs.
Future<Directory> logDirectory() async {
  Directory? base;
  try {
    base = await getExternalStorageDirectory();
  } catch (_) {}
  base ??= await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/logs');
  await dir.create(recursive: true);
  return dir;
}

const routeIds = [practiceRouteId, 'R1', 'R2'];

Future<Map<String, RouteScript>> loadRoutes() async {
  final out = <String, RouteScript>{};
  for (final id in routeIds) {
    final src = await rootBundle.loadString('assets/routes/$id.json');
    out[id] = RouteScript.parse(src);
  }
  return out;
}
