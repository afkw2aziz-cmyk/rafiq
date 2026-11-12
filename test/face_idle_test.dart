import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_companion/core/state.dart';
import 'package:pixel_companion/ui/face.dart';

void main() {
  testWidgets('idle face renders without error and boots moods', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CompanionFace(state: CompanionState.idle, variant: 0),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The painter is present and painted.
    expect(find.byType(CompanionFace), findsOneWidget);

    // Advance 30 seconds of fake time; the mood timer must not throw and the
    // face must keep rendering across many mood transitions.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-idle states render without throwing', (tester) async {
    for (final s in CompanionState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: CompanionFace(state: s, variant: s.index % 3),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull, reason: 'state $s threw');
    }
  });
}
