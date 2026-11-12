import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/settings.dart';
import 'services/background_worker.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('chat');
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsStore.load();

  try {
    await NotificationService().init();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => SettingsNotifier(settings)),
      ],
      child: const PixelCompanionApp(),
    ),
  );

  unawaited(_scheduleBackground(settings));
}

Future<void> _scheduleBackground(AppSettings settings) async {
  await BackgroundScheduler.init();
  await BackgroundScheduler.scheduleMorningBrief(settings);
  await BackgroundScheduler.scheduleStockCheck(settings);
  await BackgroundScheduler.scheduleHourlyDigest(settings);
}
