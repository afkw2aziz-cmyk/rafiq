import 'package:flutter/material.dart';

/// All visual/behavioural states of the companion face.
enum CompanionState {
  idle,
  listening,
  thinking,
  speaking,
  happy,
  sad,
  surprised,
  sleeping,
}

extension CompanionStateX on CompanionState {
  String get labelAr => switch (this) {
        CompanionState.idle => 'صاحي',
        CompanionState.listening => 'أسمعك',
        CompanionState.thinking => 'أفكر',
        CompanionState.speaking => 'أتكلم',
        CompanionState.happy => 'سعيد',
        CompanionState.sad => 'متأسف',
        CompanionState.surprised => 'متفاجئ',
        CompanionState.sleeping => 'نائم',
      };

  String get labelEn => switch (this) {
        CompanionState.idle => 'Idle',
        CompanionState.listening => 'Listening',
        CompanionState.thinking => 'Thinking',
        CompanionState.speaking => 'Speaking',
        CompanionState.happy => 'Happy',
        CompanionState.sad => 'Oops',
        CompanionState.surprised => 'Surprised',
        CompanionState.sleeping => 'Sleeping',
      };

  Color get accent => switch (this) {
        CompanionState.idle => const Color(0xFF6EE7F9),
        CompanionState.listening => const Color(0xFF7CFFB2),
        CompanionState.thinking => const Color(0xFFFFD479),
        CompanionState.speaking => const Color(0xFF9BB8FF),
        CompanionState.happy => const Color(0xFF7CFFB2),
        CompanionState.sad => const Color(0xFFFF9BA6),
        CompanionState.surprised => const Color(0xFFFFC46B),
        CompanionState.sleeping => const Color(0xFF8E9BB3),
      };
}
