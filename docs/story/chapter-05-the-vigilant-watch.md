# Chapter V: The Vigilant Watch

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"No kingdom endures without sentries. When the first errors crept across the borders — silent, insidious, corrupting — Vigil was already watching. And beside her stood Chronicle, the scribe with a perfect memory, recording every whisper, every warning, every scream into the abyss."*

---

## The First Cracks

Questboard had launched internally. Quests were being created, completed, and celebrated. The Herald carried messages between Pillars flawlessly. Everything worked.

Until it didn't.

It started with a flicker — a network timeout when loading quests from the API. Then a null pointer when a quest was completed mid-sync. Then, most insidiously, a silent failure in the leaderboard calculation that produced wrong numbers without crashing.

Kael opened the console logs. Nothing. Just `flutter: Instance of 'ApiException'` buried in a sea of framework noise. No context. No source. No breadcrumb.

"I need to see everything," Kael muttered. "Every error, where it came from, what was happening when it hit."

---

## Vigil — The Watchful Eye

**Vigil** is Titan's centralized error tracking system. Every error captured through Vigil carries context — which Pillar threw it, what action was being performed, and any metadata you attach.

```dart
import 'package:titan/titan.dart';

class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);
  late final isLoading = core(false);

  Future<void> loadQuests() => strikeAsync(() async {
    isLoading.value = true;
    final result = await api.fetchQuests();
    quests.value = result;
    isLoading.value = false;
  });
}
```

Wait — where's the error handling? Look at `strikeAsync`. It's not just an async version of `strike`. It's a **guarded** async mutation. If the closure throws, `strikeAsync` automatically:

1. Captures the error via Vigil with the Pillar's type as context
2. Preserves the stack trace
3. Rethrows so you can still handle it locally if needed

Every `strikeAsync` in every Pillar is automatically shielded by Vigil.

---

## Manual Error Capture

For finer control, Pillars have `captureError()`:

```dart
class QuestboardPillar extends Pillar {
  Future<void> loadQuests() async {
    try {
      strike(() => isLoading.value = true);
      final result = await api.fetchQuests();
      strike(() {
        quests.value = result;
        isLoading.value = false;
      });
    } catch (e, s) {
      strike(() => isLoading.value = false);
      captureError(
        e,
        stackTrace: s,
        action: 'loadQuests',
        severity: ErrorSeverity.error,
        metadata: {'retryCount': 0},
      );
    }
  }
}
```

The error is now tagged:
- **Source**: `QuestboardPillar` (auto-detected from `runtimeType`)
- **Action**: `'loadQuests'` (what was happening)
- **Severity**: `ErrorSeverity.error`
- **Metadata**: Additional context

---

## Watching for Errors

Vigil collects errors. You decide what to do with them:

```dart
void main() {
  // Handler 1: Send to Crashlytics
  Vigil.addHandler((report) {
    FirebaseCrashlytics.instance.recordError(
      report.error,
      report.stackTrace,
      reason: report.context?.action ?? 'unknown',
    );
  });

  // Handler 2: Show error UI for critical issues
  Vigil.addHandler((report) {
    if (report.severity == ErrorSeverity.fatal) {
      showErrorDialog(report.error.toString());
    }
  });

  // Handler 3: Development logging
  Vigil.addHandler((report) {
    debugPrint('[VIGIL] ${report.severity.name}: ${report.error}');
    if (report.context != null) {
      debugPrint('  Source: ${report.context!.source}');
      debugPrint('  Action: ${report.context?.action}');
    }
  });

  runApp(
    Beacon(
      pillars: [QuestboardPillar.new, HeroPillar.new],
      child: const QuestboardApp(),
    ),
  );
}
```

Multiple handlers. Different concerns. Crashlytics gets everything. The UI only shows fatal errors. Development builds get verbose debugging. All from the same error capture pipeline.

---

## Error History

Vigil keeps a history of recent errors (configurable, default 100):

```dart
// Access error history
final recent = Vigil.history;
print('Total errors captured: ${recent.length}');

for (final report in recent) {
  print('${report.timestamp}: ${report.error} [${report.severity.name}]');
}

// Stream of errors — react in real-time
Vigil.stream.listen((report) {
  print('New error: ${report.error}');
});

// Clear history
Vigil.clearHistory();
```

Kael built a debug screen that displayed the error history during development:

```dart
class DebugErrorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: Vigil.history.length,
      itemBuilder: (context, index) {
        final report = Vigil.history[index];
        return ListTile(
          leading: Icon(_iconFor(report.severity)),
          title: Text(report.error.toString()),
          subtitle: Text(
            '${report.context?.source ?? 'Unknown'} → '
            '${report.context?.action ?? 'Unknown action'}',
          ),
          trailing: Text(_timeAgo(report.timestamp)),
        );
      },
    );
  }
}
```

---

## Chronicle — The Scribe

Vigil watches for errors. But what about everything else? What about the flow of normal operations — the breadcrumbs that help you understand *how* the app reached the error state?

**Chronicle** is Titan's structured logging system. Every Pillar has a built-in `log` object, auto-named after the Pillar's class:

```dart
class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);

  @override
  void onInit() {
    log.info('QuestboardPillar initialized');
    loadQuests();
  }

  Future<void> loadQuests() async {
    log.debug('Loading quests from API...');
    try {
      final result = await api.fetchQuests();
      strike(() => quests.value = result);
      log.info('Loaded ${result.length} quests');
    } catch (e, s) {
      log.error('Failed to load quests', e, s);
      captureError(e, stackTrace: s, action: 'loadQuests');
    }
  }

  void completeQuest(String id) {
    final quest = quests.value.firstWhere((q) => q.id == id);
    log.debug('Completing quest', {'id': id, 'title': quest.title});

    strike(() {
      quests.value = quests.value.map((q) {
        return q.id == id ? q.copyWith(isCompleted: true) : q;
      }).toList();
    });

    log.info('Quest completed: ${quest.title}', {'glory': quest.glory});
    emit(QuestCompleted(questId: id, questTitle: quest.title, glory: quest.glory));
  }
}
```

The console output is clean and structured:

```
[INFO]  QuestboardPillar: QuestboardPillar initialized
[DEBUG] QuestboardPillar: Loading quests from API...
[INFO]  QuestboardPillar: Loaded 5 quests
[DEBUG] QuestboardPillar: Completing quest {id: 3, title: Slay the Null Dragon}
[INFO]  QuestboardPillar: Quest completed: Slay the Null Dragon {glory: 50}
```

---

## Log Levels

Chronicle supports six levels, from most verbose to most severe:

```dart
log.trace('Extremely detailed');      // For deep debugging
log.debug('Useful during dev');       // Development details
log.info('Normal operation');         // Noteworthy events
log.warning('Something suspicious'); // Potential problems
log.error('Something broke', e, s);  // Errors with exception & stack
log.fatal('Catastrophic failure');    // The kingdom is falling
```

Control the global level to filter noise:

```dart
// Development — see everything
Chronicle.level = LogLevel.trace;

// Staging — info and above
Chronicle.level = LogLevel.info;

// Production — errors only
Chronicle.level = LogLevel.error;

// Disable all logging
Chronicle.level = LogLevel.off;
```

---

## Custom Sinks

By default, Chronicle writes to the console with color-coded icons. But you can add custom sinks — send logs to a file, a server, an analytics platform:

```dart
class CloudLogSink extends LogSink {
  @override
  void write(LogEntry entry) {
    cloudService.log({
      'level': entry.level.name,
      'logger': entry.loggerName,
      'message': entry.message,
      'timestamp': entry.timestamp.toIso8601String(),
      if (entry.error != null) 'error': entry.error.toString(),
    });
  }
}

// Add the sink globally
Chronicle.addSink(CloudLogSink());
```

Multiple sinks can run simultaneously — console for development, cloud for production, analytics for product teams.

---

## Vigil + Chronicle: The Complete Picture

Kael wired them together. Chronicle captured the normal flow. Vigil captured the explosions. Together, they painted a complete picture of every journey through the app:

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final isLoading = core(false);

  Future<void> login(String email, String password) async {
    log.info('Login attempt', {'email': email});

    try {
      strike(() => isLoading.value = true);

      log.debug('Calling auth API...');
      final result = await api.login(email, password);

      strike(() {
        user.value = result.user;
        isLoading.value = false;
      });

      log.info('Login successful', {'userId': result.user.id});
      emit(UserLoggedIn(user: result.user));

    } catch (e, s) {
      strike(() => isLoading.value = false);
      log.error('Login failed', e, s);
      captureError(e, stackTrace: s, action: 'login', metadata: {'email': email});
    }
  }
}
```

When Kael traced a bug report, the log told the full story:

```
[INFO]  AuthPillar: Login attempt {email: kael@ironclad.dev}
[DEBUG] AuthPillar: Calling auth API...
[ERROR] AuthPillar: Login failed — SocketException: Connection refused
```

And Vigil had the error captured, tagged with `source: AuthPillar`, `action: login`, and the full stack trace. Between them, no error could hide.

---

> *The Vigil stood watch. The Chronicle recorded all. But Kael discovered a new fear: what if the hero made a mistake? What if a quest was completed by accident, or a note was deleted unintentionally? The kingdom needed the power to turn back time — to revisit the Epochs that had passed.*

---

**Next:** [Chapter VI — Turning Back the Epochs →](chapter-06-turning-back-the-epochs.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| **V** | **The Vigilant Watch** ← You are here |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
