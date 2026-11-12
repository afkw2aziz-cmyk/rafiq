# Writing a skill

A skill is a self-contained capability. Adding one must require **only** a new file and one
registration line — no changes to the engine, UI, or permissions plumbing.

## 1. Implement the contract

```dart
class CoffeeSkill implements Skill {
  @override
  String get id => 'coffee';

  @override
  String get displayName => 'Coffee';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'coffee',
        name: 'Coffee',
        description: 'Logs how many cups you drank today.',
        icon: Icons.coffee,
        permissions: {},              // none: local only
        triggers: [r'coffee', r'قهوة'],
      );

  @override
  Future<void> init(SkillContext ctx) async {}

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final n = await req.ctx.storage.bumpCounter('coffee');
    return SkillResponse(
      text: req.ctx.isArabic ? 'هذه فنجانك رقم $n اليوم' : 'That is cup #$n today',
      face: CompanionState.happy,
    );
  }

  @override
  Stream<SkillEvent> get events => const Stream.empty();

  @override
  Widget? buildSettings(BuildContext context) => null;
}
```

## 2. Register it

In `lib/skills/registry.dart`:

```dart
SkillRegistry.bootstrap()..register(CoffeeSkill());
```

That is the entire integration. The registry resolves `enabledSkills` from settings, shows the
card in **Skills**, and routes any utterance matching `manifest.triggers`.

## Rules

1. **No UI side effects.** Never call TTS, notifications, or navigation from a skill; return a
   `SkillResponse` and let the engine speak it. Proactive pushes go through `events`.
2. **Declare permissions.** `SkillManifest.permissions` drives the privacy screen and the
   permission request flow; undeclared permission use is a bug.
3. **Local first.** Prefer on-device data; every network call must go through `ctx.http`
   (which logs to the Network activity view).
4. **Locale-aware.** Use `ctx.isArabic` for user-facing text; never hardcode one language.
5. **Be fast.** `invoke` must return within a few seconds or stream via `events`;
   the face switches to `thinking` while it runs.
6. **Fail soft.** Return a friendly `SkillResponse` with `face: sad` instead of throwing.

## Tests

Add a unit test that constructs the skill with a fake `SkillContext` and asserts the response
text and face state. `test/skills_test.dart` contains examples.
