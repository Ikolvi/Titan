# Chapter XV: The Loom Weaves

*In which Kael tames chaos with state machines, and learns that not every state should be reachable from every other.*

---

The bug report was simple: "User can submit a quest while it's still loading." The fix was not.

Kael had been using a boolean `isLoading` Core. When someone tapped "Submit", the code checked `isLoading.value`. But there was a race condition — between the tap and the check, the state had already moved. Sometimes the quest was submitted twice. Sometimes it was submitted in an error state. Sometimes it corrupted the list.

"I need something that *enforces* which transitions are legal," Kael said. He needed a state machine. He needed the **Loom**.

---

## Weaving the First Loom

> *A loom weaves threads into fabric. Titan's Loom weaves states into controlled flows — no illegal transitions, no impossible combinations.*

The quest submission had four natural states: idle, submitting, success, and error. And only certain transitions between them made sense:

```dart
enum SubmitState { idle, submitting, success, error }
enum SubmitEvent { submit, succeed, fail, reset }

class QuestSubmitPillar extends Pillar {
  late final submission = loom<SubmitState, SubmitEvent>(
    initial: SubmitState.idle,
    transitions: {
      (SubmitState.idle, SubmitEvent.submit): SubmitState.submitting,
      (SubmitState.submitting, SubmitEvent.succeed): SubmitState.success,
      (SubmitState.submitting, SubmitEvent.fail): SubmitState.error,
      (SubmitState.error, SubmitEvent.reset): SubmitState.idle,
      (SubmitState.success, SubmitEvent.reset): SubmitState.idle,
    },
    name: 'submission',
  );

  Future<void> submitQuest(String questId) async {
    // Can only submit from idle — prevents double-submit
    if (!submission.canSend(SubmitEvent.submit)) return;

    submission.send(SubmitEvent.submit);
    try {
      await api.submitQuest(questId);
      submission.send(SubmitEvent.succeed);
    } catch (e, s) {
      submission.send(SubmitEvent.fail);
      captureError(e, stackTrace: s, action: 'submitQuest');
    }
  }
}
```

The key insight: `canSend(SubmitEvent.submit)` returns `true` only when the Loom is in `idle`. Double-tapping the submit button? Ignored. Submitting during an error state? Impossible. The *transitions table* is the single source of truth.

---

## Lifecycle Hooks — onEnter & onExit

> *Sometimes you need side effects at state boundaries — start a timer when entering, clear resources when leaving.*

```dart
late final auth = loom<AuthState, AuthEvent>(
  initial: AuthState.unauthenticated,
  transitions: {
    (AuthState.unauthenticated, AuthEvent.login): AuthState.authenticating,
    (AuthState.authenticating, AuthEvent.success): AuthState.authenticated,
    (AuthState.authenticating, AuthEvent.failure): AuthState.error,
    (AuthState.authenticated, AuthEvent.logout): AuthState.unauthenticated,
    (AuthState.error, AuthEvent.retry): AuthState.authenticating,
  },
  onEnter: {
    AuthState.authenticated: () => log.info('Welcome back!'),
    AuthState.error: () => log.error('Authentication failed'),
  },
  onExit: {
    AuthState.authenticated: () {
      // Clear session data when leaving authenticated state
      log.info('Session ended');
    },
  },
  onTransition: (from, event, to) {
    log.debug('Auth: $from --[$event]--> $to');
  },
);
```

The execution order is: `onExit(from)` → state changes → `onEnter(to)` → `onTransition(from, event, to)`.

---

## Querying the Loom

The Loom provides a rich query API:

```dart
// Current state — reactive (auto-tracked)
final state = auth.current; // AuthState.unauthenticated

// Check specific state — reactive
if (auth.isIn(AuthState.authenticated)) { /* ... */ }

// Check if an event is valid — non-reactive
if (auth.canSend(AuthEvent.login)) { /* ... */ }

// All valid events from current state — non-reactive
final events = auth.allowedEvents; // {AuthEvent.login}

// Transition history
final transitions = auth.history;
// [AuthState.unauthenticated --[login]--> authenticating, ...]
```

### In the UI

Because the Loom's state is a reactive `Core`, it works seamlessly with Vestige:

```dart
Vestige<QuestSubmitPillar>(
  builder: (context, pillar) {
    final state = pillar.submission.current;
    return switch (state) {
      SubmitState.idle => ElevatedButton(
          onPressed: () => pillar.submitQuest('quest-42'),
          child: const Text('Submit'),
        ),
      SubmitState.submitting => const CircularProgressIndicator(),
      SubmitState.success => const Icon(Icons.check, color: Colors.green),
      SubmitState.error => Column(
          children: [
            const Text('Submission failed'),
            TextButton(
              onPressed: () => pillar.submission.send(SubmitEvent.reset),
              child: const Text('Try Again'),
            ),
          ],
        ),
    };
  },
)
```

---

## When to Use Loom vs. Core

| Scenario | Use |
|----------|-----|
| Simple on/off toggle | `Core<bool>` |
| Numeric value | `Core<int>` |
| Multiple states with ANY transition | `Core<MyEnum>` |
| Multiple states with RESTRICTED transitions | **`Loom<S, E>`** |
| Authentication flow | **`Loom<S, E>`** |
| Multi-step wizard | **`Loom<S, E>`** |
| Network request lifecycle | **`Loom<S, E>`** |

The rule: if you catch yourself writing `if (state == X && nextState == Y)` guard logic scattered across your code, that's the Loom telling you it wants to exist.

---

## What Kael Learned

The double-submit bug was gone. The race condition was eliminated. And the auth flow that had been a tangled mess of booleans was now a clean, auditable state machine.

"The Loom doesn't just manage state," Kael told the team. "It defines the *rules* of state. States that shouldn't be reachable *aren't reachable*. Events that don't make sense *are silently ignored*."

The team lead nodded. "Now build me a test harness. I want to verify every transition in CI."

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
| [IX](chapter-09-the-scroll-inscribes.md) | The Scroll Inscribes |
| [X](chapter-10-the-codex-opens.md) | The Codex Opens |
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| **XV** | **The Loom Weaves** ← You are here |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
