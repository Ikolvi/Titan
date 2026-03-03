# Chapter XXXIV: The Pyre Burns

> *"The ancients built their pyres with purpose — each log placed by weight and worth, the heaviest at the base, the lightest at the crown. The fire did not consume at random. It burned in order, fed by discipline, governed by the hands that tended it. A wild fire destroys. A pyre transforms."*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

## The Problem

Questboard had a new feature: heroes could attach evidence to completed quests — screenshots, battle logs, map fragments. Each upload had to reach the server, but bandwidth was limited and not all uploads were equal.

"Critical bounty proof needs to go first," Kael said, watching the upload queue grow. "A hero submitting proof for a legendary quest shouldn't wait behind fifty thumbnail syncs."

Lyra nodded. "And we can't just fire all of them at once. The server caps us at three concurrent uploads. If we exceed that, we get throttled — or worse, banned."

Kael listed the requirements on the whiteboard:

1. Priority ordering — critical uploads before normal ones, normal before low
2. Concurrency control — no more than three uploads running simultaneously
3. Backpressure — reject new uploads when the queue is absurdly full
4. Pause and resume — let heroes suspend uploads on metered connections
5. Retry — transient failures should retry automatically with backoff
6. Cancellation — heroes should be able to cancel individual uploads or clear the queue

"That's a priority task queue with concurrency control," Lyra said. "We could wire up a `StreamController`, a priority heap, a semaphore, retry logic, cancellation tokens..."

"Or," Kael said, "we light a **Pyre**."

---

## The Pyre

A pyre is a structured fire — fuel arranged with intention, burning in disciplined order. Titan's `Pyre<T>` is a priority-ordered async task queue with configurable concurrency, backpressure, retry, and full reactive state.

```dart
import 'package:titan/titan.dart';

class UploadPillar extends Pillar {
  late final uploads = pyre<UploadResult>(
    concurrency: 3,
    name: 'uploads',
  );

  Future<UploadResult> uploadEvidence(String questId, File file) {
    return uploads.enqueue(
      () => api.uploadFile(questId, file),
      priority: PyrePriority.normal,
    );
  }

  Future<UploadResult> uploadBountyProof(String questId, File file) {
    return uploads.enqueue(
      () => api.uploadFile(questId, file),
      priority: PyrePriority.critical,
    );
  }
}
```

The `pyre<T>()` factory method on Pillar creates a managed Pyre with automatic disposal. Three concurrent workers. Priority ordering. The Future returned by `enqueue()` resolves when that specific task completes — not when the queue drains. A critical bounty proof leapfrogs every normal and low-priority task waiting in line.

---

## Priority

Every task has a priority. The Pyre always processes the highest-priority pending task next:

```dart
enum PyrePriority {
  critical, // processed first
  high,
  normal,   // default
  low,      // processed last
}
```

When a worker becomes available, the Pyre dequeues the highest-priority task. Among tasks of equal priority, FIFO order is preserved:

```dart
// These are enqueued in order, but processed by priority
uploads.enqueue(() => syncThumbnail(), priority: PyrePriority.low);
uploads.enqueue(() => syncThumbnail(), priority: PyrePriority.low);
uploads.enqueue(() => uploadBountyProof(), priority: PyrePriority.critical);

// The bounty proof runs first, even though it was enqueued last
```

---

## Concurrency Control

The `concurrency` parameter limits how many tasks run simultaneously:

```dart
late final uploads = pyre<UploadResult>(
  concurrency: 3, // at most 3 tasks running at once
);
```

When all workers are busy, new tasks wait in the priority queue. As each task completes, the next highest-priority task starts immediately. No thundering herd. No server overload.

You can peek at the next task that will be dequeued without removing it:

```dart
final nextTask = uploads.peek(); // null if queue is empty
```

---

## Backpressure

What happens when tasks arrive faster than they can be processed? The `maxQueueSize` parameter sets an upper bound:

```dart
late final uploads = pyre<UploadResult>(
  concurrency: 3,
  maxQueueSize: 100,
);
```

When the queue is full, `enqueue()` throws a `PyreBackpressureException` — a clear signal to the caller that the system is overwhelmed:

```dart
try {
  await uploads.enqueue(() => syncData());
} on PyreBackpressureException {
  showSnackBar('Upload queue is full. Please try again later.');
}
```

Without `maxQueueSize`, the queue grows without bound. Set it when you need to protect memory or signal the user gracefully.

---

## Batch Enqueue

For multiple tasks at once, `enqueueAll()` avoids the overhead of individual calls:

```dart
final files = getSelectedFiles();

final futures = uploads.enqueueAll(
  files.map((file) => () => api.uploadFile(questId, file)),
  priority: PyrePriority.normal,
);

// Each future resolves independently
final results = await Future.wait(futures);
```

Each returned Future corresponds to its task — you get individual completion tracking even in a batch.

---

## Pause and Resume

Heroes on metered connections need to suspend uploads without losing progress:

```dart
// Suspend processing — running tasks finish, but no new tasks start
uploads.pause();

// Resume processing — queued tasks start flowing again
uploads.resume();
```

Pausing does not cancel running tasks. It simply stops the Pyre from dequeuing new ones. When resumed, the Pyre picks up exactly where it left off, respecting priority order.

---

## Cancellation

Cancel a specific task by its ID, or clear the entire queue:

```dart
// Enqueue returns a future, but you can also capture the task ID
final taskId = uploads.enqueue(
  () => api.uploadFile(questId, file),
  priority: PyrePriority.normal,
);

// Cancel a specific pending task
uploads.cancel(taskId);

// Cancel all pending tasks (running tasks continue to completion)
uploads.cancelAll();
```

Cancelled tasks complete with a `PyreFailure` result. Running tasks cannot be cancelled — they run to completion.

---

## Drain, Stop, and Reset

Three lifecycle operations for different scenarios:

```dart
// Drain: cancel all pending tasks, wait for running tasks to finish
await uploads.drain();

// Stop: permanent shutdown — no new tasks accepted
uploads.stop();

// Reset: clear everything and restart fresh
uploads.reset();
```

`drain()` is perfect for cleanup — "let the current work finish, discard everything else." `stop()` is a permanent shutdown for when the Pillar is being disposed. `reset()` clears all state and counters, ready for a fresh start.

---

## Automatic Retry

Transient failures — network hiccups, server 503s — should retry automatically:

```dart
late final uploads = pyre<UploadResult>(
  concurrency: 3,
  maxRetries: 3,
);
```

When a task throws, the Pyre re-enqueues it with exponential backoff (1s, 2s, 4s). After `maxRetries` attempts, the task fails permanently and its Future completes with a `PyreFailure`.

---

## Reactive State

The Pyre exposes its internal state as reactive Cores — perfect for driving UI:

```dart
class UploadPillar extends Pillar {
  late final uploads = pyre<UploadResult>(
    concurrency: 3,
    maxRetries: 2,
    name: 'uploads',
  );

  late final statusText = derived(() {
    final queued = uploads.queueLength;
    final running = uploads.runningCount;
    final done = uploads.completedCount;
    final failed = uploads.failedCount;
    return '$running uploading, $queued queued, $done done, $failed failed';
  });

  late final progressPercent = derived(() {
    return uploads.progress; // 0.0 to 1.0
  });
}
```

All reactive state at a glance:

| Core | Type | Description |
|------|------|-------------|
| `queueLength` | `int` | Number of tasks waiting (reactive) |
| `runningCount` | `int` | Number of tasks currently executing (reactive) |
| `completedCount` | `int` | Total tasks completed successfully (reactive) |
| `failedCount` | `int` | Total tasks that failed permanently (reactive) |
| `progress` | `double` | Overall progress from 0.0 to 1.0 (reactive) |
| `status` | `PyreStatus` | Current queue status (reactive) |

The `status` Core tracks the queue lifecycle:

```dart
switch (uploads.status) {
  case PyreStatus.idle:        // no tasks
  case PyreStatus.processing:  // actively processing
  case PyreStatus.paused:      // suspended by pause()
  case PyreStatus.stopped:     // permanently shut down
}
```

---

## Results and Callbacks

Every task produces a `PyreResult<T>` — a sealed class:

```dart
final result = await uploads.enqueue(() => api.uploadFile(questId, file));

switch (result) {
  case PyreSuccess(:final value):
    showSnackBar('Uploaded: ${value.url}');
  case PyreFailure(:final error):
    showSnackBar('Failed: $error');
}
```

For fire-and-forget monitoring, use callbacks:

```dart
late final uploads = pyre<UploadResult>(
  concurrency: 3,
  onTaskComplete: (taskId, result) {
    log.info('Upload finished: ${result.url}');
  },
  onTaskFailed: (taskId, error) {
    analytics.track('upload_failed', {'error': '$error'});
  },
  onDrained: () {
    showSnackBar('All uploads complete!');
  },
);
```

The `onDrained` callback fires when the queue empties and all workers are idle — perfect for showing a completion banner.

---

## Manual Start

By default, the Pyre starts processing immediately when tasks are enqueued. Pass `autoStart: false` to batch tasks before starting:

```dart
late final batchQueue = pyre<ProcessResult>(
  concurrency: 5,
  autoStart: false,
);

void prepareBatch(List<Job> jobs) {
  batchQueue.enqueueAll(
    jobs.map((job) => () => processJob(job)),
  );
  // Nothing is processing yet
}

void startProcessing() {
  batchQueue.resume(); // now all tasks begin flowing
}
```

This is useful when you want to collect all tasks first and then start processing in one burst.

---

## A Complete Example

Kael wired up the Questboard evidence upload system. Heroes could attach multiple files, see real-time progress, pause on metered connections, and trust that bounty proofs always jumped the queue:

```dart
import 'package:titan/titan.dart';

class EvidencePillar extends Pillar {
  late final queue = pyre<UploadResult>(
    concurrency: 3,
    maxQueueSize: 50,
    maxRetries: 2,
    onDrained: () => _allDone.value = true,
    name: 'evidence',
  );

  late final _allDone = core(false);

  late final statusLine = derived(() {
    if (_allDone.value) return 'All uploads complete!';
    final r = queue.runningCount;
    final q = queue.queueLength;
    if (r == 0 && q == 0) return 'No uploads';
    return '$r uploading, $q queued (${(queue.progress * 100).toInt()}%)';
  });

  Future<UploadResult> uploadFile(String questId, File file,
      {bool isBountyProof = false}) async {
    _allDone.value = false;
    final pyreResult = await queue.enqueue(
      () => api.uploadFile(questId, file),
      priority:
          isBountyProof ? PyrePriority.critical : PyrePriority.normal,
    );
    return switch (pyreResult) {
      PyreSuccess(:final value) => value,
      PyreFailure(:final error) => throw error,
    };
  }

  void pauseUploads() => queue.pause();
  void resumeUploads() => queue.resume();
  void cancelAll() => queue.cancelAll();
}
```

In the UI:

```dart
Vestige<EvidencePillar>(
  builder: (context, pillar) {
    return Column(
      children: [
        Text(pillar.statusLine.value),
        LinearProgressIndicator(
          value: pillar.queue.progress,
        ),
        Row(
          children: [
            if (pillar.queue.status == PyreStatus.processing)
              IconButton(
                icon: Icon(Icons.pause),
                onPressed: pillar.pauseUploads,
              )
            else if (pillar.queue.status == PyreStatus.paused)
              IconButton(
                icon: Icon(Icons.play_arrow),
                onPressed: pillar.resumeUploads,
              ),
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: pillar.cancelAll,
            ),
          ],
        ),
      ],
    );
  },
)
```

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Pyre<T>` | Priority-ordered async task queue with concurrency control |
| `pyre<T>()` | Pillar factory method — auto-managed lifecycle |
| `PyrePriority` | `critical`, `high`, `normal`, `low` — task ordering |
| `enqueue()` | Add a task, returns a Future for that task's result |
| `enqueueAll()` | Batch-add tasks, returns a list of Futures |
| `concurrency` | Maximum number of tasks running simultaneously |
| `maxQueueSize` | Backpressure limit — throws `PyreBackpressureException` |
| `pause()` / `resume()` | Suspend and resume task processing |
| `cancel()` / `cancelAll()` | Cancel a specific task or all pending tasks |
| `drain()` | Cancel pending, wait for running tasks to finish |
| `stop()` | Permanent shutdown — no new tasks accepted |
| `reset()` | Clear all state and restart fresh |
| `maxRetries` | Automatic retry with exponential backoff |
| `queueLength` / `runningCount` / `completedCount` / `failedCount` | Reactive queue statistics |
| `progress` | Overall progress from 0.0 to 1.0 |
| `status` | `idle`, `running`, `paused`, `stopped` |
| `PyreResult<T>` | Sealed class — `PyreSuccess` or `PyreFailure` |
| `onTaskComplete` / `onTaskFailed` / `onDrained` | Event callbacks |
| `autoStart: false` | Defer processing until `resume()` is called |
| `peek()` | Inspect the next task without dequeuing |

---

> *"The Pyre burned through the night, each task consumed in its turn — the urgent before the ordinary, the critical before the mundane. The heroes slept soundly, knowing the fire was tended. It would not rage. It would not starve. It would burn precisely as long as there was work to be done."*

---

[← Chapter XXXIII: The Omen Foretells](chapter-33-the-omen-foretells.md) | [Chapter XXXV →](chapter-35-the-mandate-decrees.md)
