# Chapter XLIX — The Clarion Sounds

*In which Kael teaches Questboard to call its workers at appointed hours, and every summons is watched by the reactive graph.*

---

The Elder Architect studied the Questboard dashboard. Quests expired without notice. Analytics sat unflushed for hours. Auth tokens lapsed in silence.

"The system never _forgets_ its data," the Elder observed, "but it forgets to _act_ on schedule. A kingdom without a herald's horn is a kingdom caught unawares."

Kael nodded. "We need recurring tasks — token refresh, analytics flush, stale-quest checks — but scattered `Timer.periodic` calls are invisible. No one knows what's running, what's failed, or what's overdue."

"Then raise a **Clarion**," the Elder said. "A trumpet that sounds on time, every time — and whose every note echoes through the reactive graph."

---

## The First Call

A Clarion manages named jobs, each with an interval, a handler, and reactive observability over its lifecycle.

```dart
class QuestMaintenancePillar extends Pillar {
  late final scheduler = clarion(name: 'maintenance');

  void onInit() {
    scheduler.schedule(
      'refresh-token',
      const Duration(minutes: 25),
      () async => await authService.refreshToken(),
    );

    scheduler.schedule(
      'flush-analytics',
      const Duration(minutes: 1),
      () async => await analytics.flush(),
      policy: ClarionPolicy.skipIfRunning,
    );

    scheduler.schedule(
      'expire-stale-quests',
      const Duration(hours: 1),
      () async => await questRepo.expireStale(),
      immediate: true, // Run once immediately on registration.
    );
  }
}
```

"Three jobs, three intervals, three policies," Kael murmured. "And every one registers its lifecycle in the reactive graph."

---

## Watching the Trumpeter

The Clarion exposes aggregate and per-job reactive state — run counts, error tallies, success rates — all as `Core` and `Derived` signals.

```dart
// Aggregate state.
print(scheduler.totalRuns.value);   // 42
print(scheduler.totalErrors.value); // 1
print(scheduler.successRate.value); // 0.976...

// Per-job state.
final tokenJob = scheduler.job('refresh-token');
print(tokenJob.isRunning.value);    // false
print(tokenJob.runCount.value);     // 14
print(tokenJob.lastRun.value?.duration); // 0:00:00.032000
print(tokenJob.nextRun.value);      // 2025-01-15 14:25:00
```

"Every run is a `ClarionRun`," the Elder noted. "Start time, duration, error if any. The Clarion remembers what plain timers forget."

---

## One-Shot Summons and Manual Triggers

Not every call repeats. A `scheduleOnce` fires after a delay and removes itself. A `trigger` sounds the horn on command.

```dart
// Fire once after 30 seconds, then auto-unregister.
scheduler.scheduleOnce(
  'welcome-banner',
  const Duration(seconds: 30),
  () async => await notifications.showWelcome(),
);

// Manual trigger — respects the job's concurrency policy.
scheduler.trigger('flush-analytics');
```

"And when the siege lifts?" Kael asked.

"Pause and resume — per job or globally."

```dart
scheduler.pause('flush-analytics'); // Freeze one job.
scheduler.pause();                  // Freeze everything.
scheduler.resume();                 // Resume all.
```

---

## The Clarion in the Crucible

Kael wrote tests that verified every reactive signal without waiting for real timers.

```dart
test('trigger tracks run count and last run', () async {
  final c = Clarion(name: 'test');
  c.schedule('job', Duration(hours: 1), () async {});

  c.trigger('job');
  await Future.delayed(Duration.zero);

  expect(c.job('job').runCount.value, 1);
  expect(c.job('job').lastRun.value?.succeeded, true);
  expect(c.totalRuns.value, 1);
  expect(c.successRate.value, 1.0);

  c.dispose();
});
```

The Elder smiled. "The Clarion sounds at 0.050 µs per trigger. Fast enough to summon an army."

---

*Every system needs a timekeeper — something that calls workers to action, tracks what was done, and remembers what failed. Scattered timers are noise. A Clarion is a signal.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Job Scheduler | **Clarion** | Reactive recurring/one-shot job scheduler |
| Job Status | **ClarionStatus** | `idle` · `running` · `paused` · `disposed` |
| Execution Record | **ClarionRun** | `startedAt` · `duration` · `error` · `succeeded` |
| Concurrency Policy | **ClarionPolicy** | `skipIfRunning` · `allowOverlap` |
| Per-Job State | **ClarionJobState** | `isRunning` · `runCount` · `errorCount` · `lastRun` · `nextRun` |
