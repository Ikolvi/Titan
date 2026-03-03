# Chapter XXXV: The Mandate Decrees

> *"The laws of the ancients were not written in stone for stone's sake. They were written so that every citizen, every guard, every gate could answer the same question the same way: 'Shall this be permitted?' The stone did not deliberate. It declared."*

---

## The Problem

Questboard's permission system had become a sprawling tangle. Every screen, every button, every action had its own ad-hoc `if` chain checking user roles, subscription tiers, feature flags, and quest ownership.

"Look at this," Kael said, scrolling through the edit-quest handler. "We check `isAdmin` here, `isPremium` there, `isOwner` somewhere else. And when the product team adds a new rule — like 'editors can edit but not delete' — we have to hunt through fifty files."

Lyra pulled up a recent bug report. "A hero could edit quests they didn't own because someone forgot the ownership check on the mobile layout. The rules exist; they just weren't applied consistently."

The requirements were clear:

1. **Declarative rules** — define each policy once, by name
2. **Reactive evaluation** — verdicts update automatically when Cores change
3. **Composable strategies** — AND all rules, OR them, or use weighted majority
4. **Fine-grained queries** — check individual rules or the composite verdict
5. **Dynamic management** — add, remove, or replace rules at runtime
6. **Pattern-matchable results** — sealed verdicts with violation details

"What we need," Lyra said, "is a reactive policy engine. Something that evaluates rules against live state and gives a `granted` or `denied` verdict — with reasons."

Kael nodded. "We issue a **Mandate**."

---

## The Mandate

A **Mandate** evaluates a set of **Writs** — named policy rules — against reactive state. Each Writ reads Core values inside its `evaluate` function. When those Cores change, the Mandate's verdict automatically re-evaluates.

```dart
class QuestEditorPillar extends Pillar {
  late final currentUser = core<User?>(null);
  late final quest = core<Quest?>(null);
  late final featureFlags = core<Set<String>>({'editing', 'comments'});

  late final editAccess = mandate(
    writs: [
      Writ(
        name: 'authenticated',
        evaluate: () => currentUser.value != null,
        reason: 'Must be logged in',
        description: 'User authentication check',
      ),
      Writ(
        name: 'is-owner',
        evaluate: () =>
            quest.value?.ownerId == currentUser.value?.id,
        reason: 'Only the quest owner can edit',
        description: 'Quest ownership verification',
      ),
      Writ(
        name: 'editing-enabled',
        evaluate: () => featureFlags.value.contains('editing'),
        reason: 'Editing feature is disabled',
        description: 'Feature flag check',
      ),
    ],
  );
}
```

Three lines of setup. Three writs. One reactive verdict.

---

## Writs — Named Policy Rules

Each **Writ** is a single, named policy rule:

```dart
Writ(
  name: 'is-premium',
  evaluate: () => subscription.value.tier == 'premium',
  reason: 'Premium subscription required',
  description: 'Checks user subscription tier',
  weight: 2, // counts double in majority strategy
)
```

| Property | Type | Purpose |
|----------|------|---------|
| `name` | `String` | Unique identifier |
| `evaluate` | `bool Function()` | Reactive rule — reads Core values |
| `reason` | `String?` | Human-readable denial reason |
| `description` | `String?` | Documentation for the rule |
| `weight` | `int` | Influence in `majority` strategy (default: 1) |

The `evaluate` function is wrapped in a `TitanComputed<bool>` internally. This means it participates in Titan's auto-tracking — any Core values accessed during evaluation are automatically registered as dependencies.

---

## Strategies — How Rules Combine

Mandate supports three combination strategies via `MandateStrategy`:

### allOf (Default)

Every writ must pass. This is logical AND — the strictest mode.

```dart
late final deleteAccess = mandate(
  strategy: MandateStrategy.allOf, // default
  writs: [
    Writ(name: 'is-admin', evaluate: () => role.value == 'admin'),
    Writ(name: 'not-archived', evaluate: () => !quest.value!.isArchived),
    Writ(name: 'no-active-heroes', evaluate: () => heroCount.value == 0),
  ],
);
```

All three must pass. If any fails, the verdict is `MandateDenial` with the specific violations listed.

### anyOf

At least one writ must pass. This is logical OR — the most permissive mode.

```dart
late final viewAccess = mandate(
  strategy: MandateStrategy.anyOf,
  writs: [
    Writ(name: 'is-public', evaluate: () => quest.value!.isPublic),
    Writ(name: 'is-member', evaluate: () => isMember.value),
    Writ(name: 'is-admin', evaluate: () => role.value == 'admin'),
  ],
);
```

If the quest is public OR the user is a member OR an admin, access is granted.

### majority

Passing writs must outweigh failing writs by total weight. This enables nuanced, weighted policy decisions.

```dart
late final publishAccess = mandate(
  strategy: MandateStrategy.majority,
  writs: [
    Writ(name: 'has-title', evaluate: () => title.value.isNotEmpty, weight: 2),
    Writ(name: 'has-desc', evaluate: () => desc.value.isNotEmpty, weight: 1),
    Writ(name: 'has-reward', evaluate: () => reward.value > 0, weight: 3),
    Writ(name: 'has-image', evaluate: () => image.value != null, weight: 1),
  ],
);
```

With weights: title (2) + reward (3) = 5 passing outweighs desc (1) + image (1) = 2 failing. Verdict: **granted**.

---

## Reading the Verdict

The Mandate exposes three reactive properties:

```dart
// Full verdict — sealed class for pattern matching
final v = pillar.editAccess.verdict.value;

// Convenience boolean
final allowed = pillar.editAccess.isGranted.value;

// All violations (empty when granted)
final issues = pillar.editAccess.violations.value;
```

### Pattern Matching

The `MandateVerdict` sealed class enables exhaustive pattern matching:

```dart
switch (pillar.editAccess.verdict.value) {
  case MandateGrant():
    return const EditButton();
  case MandateDenial(:final violations):
    return DeniedBanner(
      violations.map((v) => '${v.writName}: ${v.reason}').toList(),
    );
}
```

### Checking Individual Writs

Use `can()` to query a single writ by name:

```dart
if (pillar.editAccess.can('is-owner').value) {
  // Show owner-only controls
}
```

This returns the cached `TitanComputed<bool>` for that writ, so it participates in reactive tracking. If the writ doesn't exist, it throws `StateError`.

---

## Reactive Updates

Because Mandate writs read Core values, verdicts update automatically:

```dart
class AuthPillar extends Pillar {
  late final role = core('viewer');
  late final isVerified = core(false);

  late final adminAccess = mandate(
    writs: [
      Writ(name: 'is-admin', evaluate: () => role.value == 'admin'),
      Writ(name: 'verified', evaluate: () => isVerified.value),
    ],
  );
}

// Initially: role='viewer', isVerified=false → MandateDenial
final p = AuthPillar();
print(p.adminAccess.isGranted.value); // false

// User logs in as admin
p.role.value = 'admin';
// Still denied — not verified
print(p.adminAccess.isGranted.value); // false

// User completes verification
p.isVerified.value = true;
// Now granted — both writs pass
print(p.adminAccess.isGranted.value); // true
```

In a Vestige, this means the UI rebuilds automatically:

```dart
Vestige<AuthPillar>(
  builder: (_, p) {
    if (p.adminAccess.isGranted.value) {
      return const AdminDashboard();
    }
    final violations = p.adminAccess.violations.value;
    return AccessDeniedScreen(
      reasons: violations.map((v) => v.reason ?? v.writName).toList(),
    );
  },
)
```

---

## Dynamic Writ Management

Mandates aren't static. You can add, remove, and replace writs at runtime:

### Adding Writs

```dart
// Add a single writ
pillar.editAccess.addWrit(
  Writ(
    name: 'rate-limit',
    evaluate: () => editsThisHour.value < 100,
    reason: 'Edit rate limit exceeded',
  ),
);

// Add multiple at once (single re-evaluation)
pillar.editAccess.addWrits([
  Writ(name: 'not-banned', evaluate: () => !isBanned.value),
  Writ(name: 'email-confirmed', evaluate: () => emailConfirmed.value),
]);
```

Adding a writ with a duplicate name throws `ArgumentError`. Use `replaceWrit()` to update an existing one.

### Removing Writs

```dart
final removed = pillar.editAccess.removeWrit('rate-limit');
print(removed); // true — writ was found and removed
```

### Replacing Writs

```dart
pillar.editAccess.replaceWrit(
  Writ(
    name: 'is-owner',
    evaluate: () =>
        quest.value?.ownerId == currentUser.value?.id ||
        role.value == 'admin', // admins can now edit too
    reason: 'Must be owner or admin',
  ),
);
```

### Changing Strategy

```dart
// Switch from allOf to anyOf
pillar.editAccess.updateStrategy(MandateStrategy.anyOf);
```

All dynamic changes trigger a reactive re-evaluation. Downstream Vestiges rebuild automatically.

---

## Inspection API

Mandate provides inspection methods for debugging and introspection:

```dart
final m = pillar.editAccess;

m.writNames;   // ['authenticated', 'is-owner', 'editing-enabled']
m.writCount;   // 3
m.hasWrit('is-owner');  // true
m.strategy;    // MandateStrategy.allOf
m.name;        // 'editAccess' (debug name)
m.isDisposed;  // false
```

---

## In Questboard

Kael and Lyra replaced the scattered permission checks with centralized Mandates:

```dart
class QuestboardPillar extends Pillar {
  late final currentUser = core<User?>(null);
  late final selectedQuest = core<Quest?>(null);
  late final subscription = core<Subscription?>(null);
  late final maintenanceMode = core(false);

  // --- Permission Mandates ---

  /// Can the user edit the selected quest?
  late final canEditQuest = mandate(
    name: 'canEditQuest',
    writs: [
      Writ(
        name: 'authenticated',
        evaluate: () => currentUser.value != null,
        reason: 'Sign in to edit quests',
      ),
      Writ(
        name: 'is-owner',
        evaluate: () =>
            selectedQuest.value?.ownerId == currentUser.value?.id,
        reason: 'You can only edit your own quests',
      ),
      Writ(
        name: 'not-maintenance',
        evaluate: () => !maintenanceMode.value,
        reason: 'System is in maintenance mode',
      ),
    ],
  );

  /// Can the user access premium features?
  late final canUsePremium = mandate(
    name: 'canUsePremium',
    strategy: MandateStrategy.anyOf,
    writs: [
      Writ(
        name: 'is-premium',
        evaluate: () => subscription.value?.tier == 'premium',
        reason: 'Premium subscription required',
      ),
      Writ(
        name: 'is-trial',
        evaluate: () => subscription.value?.isTrial == true,
        reason: 'No active trial',
      ),
      Writ(
        name: 'is-admin',
        evaluate: () => currentUser.value?.role == 'admin',
        reason: 'Admin access overrides subscription',
      ),
    ],
  );

  /// Quest publish readiness — weighted majority
  late final canPublish = mandate(
    name: 'canPublish',
    strategy: MandateStrategy.majority,
    writs: [
      Writ(
        name: 'has-title',
        evaluate: () =>
            (selectedQuest.value?.title.isNotEmpty ?? false),
        weight: 3,
        reason: 'Quest needs a title',
      ),
      Writ(
        name: 'has-description',
        evaluate: () =>
            (selectedQuest.value?.description?.isNotEmpty ?? false),
        weight: 2,
        reason: 'Quest needs a description',
      ),
      Writ(
        name: 'has-reward',
        evaluate: () => (selectedQuest.value?.reward ?? 0) > 0,
        weight: 2,
        reason: 'Quest needs a reward',
      ),
      Writ(
        name: 'has-category',
        evaluate: () => selectedQuest.value?.category != null,
        weight: 1,
        reason: 'Consider adding a category',
      ),
    ],
  );
}
```

And in the UI:

```dart
Vestige<QuestboardPillar>(
  builder: (_, p) {
    return Column(
      children: [
        // Edit button — auto-hides when denied
        switch (p.canEditQuest.verdict.value) {
          MandateGrant() => ElevatedButton(
            onPressed: () => editQuest(p),
            child: const Text('Edit Quest'),
          ),
          MandateDenial(:final violations) => Tooltip(
            message: violations.map((v) => v.reason).join('\n'),
            child: const ElevatedButton(
              onPressed: null,
              child: Text('Edit Quest'),
            ),
          ),
        },

        // Premium badge
        if (p.canUsePremium.isGranted.value)
          const PremiumBadge(),

        // Publish readiness meter
        _PublishReadiness(mandate: p.canPublish),
      ],
    );
  },
)
```

"Every permission check in the app now reads from a Mandate," Lyra said. "Change the user's role? The verdict updates. Toggle a feature flag? The verdict updates. No manual invalidation, no stale checks."

---

## Under the Hood

Mandate's reactivity works through Titan's existing computed infrastructure:

1. Each Writ's `evaluate` function is wrapped in a `TitanComputed<bool>` — auto-tracking its Core dependencies.
2. The composite `verdict`, `isGranted`, and `violations` are `TitanComputed` nodes that read the per-writ results.
3. A `_revision` state bumps on structural changes (add/remove writ, strategy change), forcing re-evaluation.
4. All internal nodes are registered via `managedNodes` and `managedStateNodes` for Pillar auto-disposal.

This means:
- **Zero manual subscription management** — Vestige rebuilds on verdict changes.
- **Lazy evaluation** — writs only compute when their verdict is observed.
- **Structural sharing** — if a Core change doesn't alter the writ result, no downstream propagation occurs.

---

## Performance

Mandate benchmarks show sub-microsecond cached reads:

| Operation | µs/op |
|-----------|-------|
| Create (3 writs) | 1.751 |
| Verdict (cached) | 0.024 |
| Re-evaluate | 0.813 |
| `can()` lookup | 0.030 |
| `addWrit` | 0.371 |

Cached verdict reads at 0.024 µs/op means you can check permissions thousands of times per frame with zero measurable impact.

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Mandate` | Reactive policy evaluation engine |
| `mandate()` | Pillar factory method — auto-managed lifecycle |
| `Writ` | Named policy rule with reactive `evaluate` function |
| `MandateStrategy` | `allOf` (AND), `anyOf` (OR), `majority` (weighted) |
| `MandateVerdict` | Sealed result — `MandateGrant` or `MandateDenial` |
| `WritViolation` | Details of a failed writ (name + reason) |
| `verdict` | Composite reactive verdict (`TitanComputed<MandateVerdict>`) |
| `isGranted` | Convenience reactive boolean |
| `violations` | Reactive list of current violations |
| `can(name)` | Check individual writ by name |
| `addWrit()` / `addWrits()` | Add rules at runtime |
| `removeWrit()` | Remove a rule by name |
| `replaceWrit()` | Replace a rule (same name, new logic) |
| `updateStrategy()` | Change the combination strategy |
| `writNames` / `writCount` / `hasWrit()` | Inspection API |

---

> *"The Mandate was inscribed, and every gate in Questboard answered the same question the same way. Not by guessing. Not by checking a dozen scrolls scattered across the kingdom. By reading the single decree that governed passage. The guards no longer argued. The gates no longer wavered. The law was reactive, and the law was clear."*

---

[← Chapter XXXIV: The Pyre Burns](chapter-34-the-pyre-burns.md) | [Chapter XXXVI: The Ledger Binds →](chapter-36-the-ledger-binds.md)
