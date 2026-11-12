import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/calendar_service.dart';
import '../services/conversation_engine.dart';
import '../services/notification_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../skills/registry.dart';
import '../skills/skill.dart';
import 'settings.dart';
import 'state.dart';

final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'PixelCompanion/1.0'},
  ));
});

final notificationsProvider = Provider<NotificationService>((ref) {
  final n = NotificationService();
  n.init();
  return n;
});

final calendarProvider = Provider<CalendarService>((ref) => CalendarService());
final ttsProvider = Provider<TtsService>((ref) => TtsService());
final sttProvider = Provider<SttService>((ref) => SttService());

final registryProvider = Provider<SkillRegistry>((ref) => SkillRegistry.bootstrap());

final faceProvider = StateProvider<CompanionState>((ref) => CompanionState.idle);

class ChatEntry {
  const ChatEntry({required this.who, required this.text, required this.at});
  final String who;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'who': who,
        'text': text,
        'at': at.toIso8601String(),
      };

  factory ChatEntry.fromJson(Map<dynamic, dynamic> j) => ChatEntry(
        who: j['who'] as String? ?? 'model',
        text: j['text'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class MessagesNotifier extends StateNotifier<List<ChatEntry>> {
  MessagesNotifier() : super([]) {
    _load();
  }

  Box? get _box {
    try {
      return Hive.box('chat');
    } catch (_) {
      return null;
    }
  }

  void _load() {
    final box = _box;
    if (box == null) return;
    final items = box.values
        .map((e) => ChatEntry.fromJson(e as Map))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    state = items.length > 200 ? items.sublist(items.length - 200) : items;
  }

  void add(String who, String text) {
    final entry = ChatEntry(who: who, text: text, at: DateTime.now());
    state = [...state, entry];
    _box?.add(entry.toJson());
  }

  Future<void> clear() async {
    state = [];
    await _box?.clear();
  }
}

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatEntry>>((ref) {
  return MessagesNotifier();
});

final engineProvider = Provider<ConversationEngine>((ref) {
  final settings = ref.watch(settingsProvider);
  final messages = ref.read(messagesProvider.notifier);
  return ConversationEngine(
    registry: ref.watch(registryProvider),
    settings: settings,
    http: ref.watch(dioProvider),
    notifications: ref.watch(notificationsProvider),
    calendar: ref.watch(calendarProvider),
    tts: ref.watch(ttsProvider),
    storage: SkillStorage(ref.watch(prefsProvider)),
    setFace: (s) => ref.read(faceProvider.notifier).state = s,
    onMessage: messages.add,
  );
});
