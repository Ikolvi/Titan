# Chapter XXXIX: The Banner Rises

> *"In the age before the Banner, new features were blades unsheathed in battle — all or nothing, no retreat. A single miscalculated strike could fell the entire Questboard. But the Banner changed warfare. It let the commanders raise a standard gradually, testing the wind before committing the charge."*

---

## The Problem

Kael had built something ambitious: a new quest recommendation engine. It was faster, smarter, and completely untested in production. Deploying it to every hero at once was madness — if the algorithm failed, the entire Questboard would serve terrible recommendations.

"I need a way to show this to some heroes and not others," Kael told Lyra. "And I need to change who sees it without redeploying."

Lyra smiled. "You need feature flags. But not just any flags — you need **reactive** flags. Flags that integrate with the Pillar lifecycle. Flags that update instantly when remote configuration changes."

"We need the **Banner**."

---

## The Banner

A banner is a standard raised to announce intent. In Titan, `Banner` is a reactive feature flag registry that manages a collection of flags with:

- **Reactive state** — each flag is a `Core<bool>`, triggering UI rebuilds
- **Percentage rollout** — gradually expose features to a percentage of users
- **Targeting rules** — enable features for specific user segments
- **Developer overrides** — force flags on/off during development
- **Expiration** — flags that auto-disable after a date
- **Remote config** — bulk-update flags from a backend

```dart
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

class QuestPillar extends Pillar {
  late final flags = banner(
    flags: [
      BannerFlag(name: 'new-recommendations', rollout: 0.1),
      BannerFlag(
        name: 'premium-quests',
        rules: [
          BannerRule(
            name: 'is-premium',
            evaluate: (ctx) => ctx['tier'] == 'premium',
          ),
        ],
      ),
      BannerFlag(
        name: 'holiday-event',
        defaultValue: true,
        expiresAt: DateTime(2025, 1, 7),
        description: 'Winter festival quest line',
      ),
    ],
  );

  /// Reactive — Vestiges rebuild when this changes.
  late final showNewRecs = derived(
    () => flags['new-recommendations'].value,
  );
}
```

---

## Raising the Standard

### The Gradual Rollout

Kael started with 10% of users seeing the new recommendations:

```dart
// Deterministic per user — same hero always gets the same result
final showNewRecs = pillar.flags.isEnabled(
  'new-recommendations',
  userId: hero.id,  // Sticky assignment via FNV-1a hash
);
```

The hash-based rollout meant hero `"kael-42"` would *always* see the same result for a given flag — no flicker, no inconsistency across sessions. When Kael was satisfied with the metrics, he raised the rollout:

```dart
// From the admin panel or remote config
pillar.flags.updateFlags({'new-recommendations': true});
```

Every Vestige watching `showNewRecs` rebuilt instantly.

### Targeting Rules

The premium quests required more precision. Only heroes with a premium subscription should see them:

```dart
final isPremium = pillar.flags.isEnabled(
  'premium-quests',
  context: {'tier': currentHero.subscriptionTier},
);
```

Rules evaluated in order — the first matching rule determined the result. This allowed layered targeting:

```dart
BannerFlag(
  name: 'beta-feature',
  rules: [
    // Admins always see it
    BannerRule(name: 'admin', evaluate: (ctx) => ctx['role'] == 'admin'),
    // Beta testers see it
    BannerRule(name: 'beta', evaluate: (ctx) => ctx['beta'] == true),
    // Everyone else: check rollout percentage
  ],
  rollout: 0.25,  // 25% of remaining users
)
```

### Developer Overrides

During development, Kael's QA team needed to test both flag states:

```dart
// Force-enable for testing
pillar.flags.setOverride('new-recommendations', true);

// Overrides bypass ALL rules and rollout
assert(pillar.flags.isEnabled('new-recommendations') == true);

// Clean up
pillar.flags.clearOverride('new-recommendations');
```

### Expiration

The holiday event had a natural end date:

```dart
BannerFlag(
  name: 'holiday-event',
  defaultValue: true,
  expiresAt: DateTime(2025, 1, 7),
)
```

After January 7th, the flag would automatically evaluate to its `defaultValue`, regardless of rules or rollout. No code change needed, no redeployment.

---

## The Full Evaluation

The Banner evaluates flags with a clear priority chain:

```
Override → Expired → Rules → Rollout → Remote → Default
```

Each evaluation returns a `BannerEvaluation` with the reason:

```dart
final eval = pillar.flags.evaluate(
  'new-recommendations',
  context: {'tier': 'premium'},
  userId: 'hero-42',
);

print(eval.enabled);      // true
print(eval.reason);       // BannerReason.rollout
print(eval.matchedRule);  // null (resolved by rollout, not rule)
```

---

## Remote Configuration

Kael connected the Banner to the Questboard's remote config system:

```dart
// When Firebase/LaunchDarkly/custom backend pushes new values
final remoteFlags = await fetchRemoteConfig();
pillar.flags.updateFlags(remoteFlags);
// All reactive state updates instantly — Vestiges rebuild
```

Remote values sit below overrides in priority, allowing developers to always force flags during testing while production gets server-driven values.

---

## The Reactive Advantage

Unlike static feature flag libraries, Banner's flags are *reactive*:

```dart
class QuestListVestige extends Vestige<QuestPillar> {
  @override
  Widget build(BuildContext context, QuestPillar pillar) {
    // This rebuilds automatically when the flag changes
    if (pillar.flags['new-recommendations'].value) {
      return NewRecommendationsList();
    }
    return ClassicQuestList();
  }
}
```

No manual polling. No streams. No callbacks. The same reactive engine that powers Core and Derived now powers feature flags.

---

## Inspection

The Banner provides full observability:

```dart
// How many flags are enabled right now?
final enabled = pillar.flags.enabledCount.value;  // Reactive!

// Snapshot of all flag states
final states = pillar.flags.snapshot;
// {'new-recommendations': true, 'premium-quests': false, ...}

// Check if a flag exists
pillar.flags.has('new-recommendations');  // true

// Get flag configuration
final config = pillar.flags.config('new-recommendations');
print(config?.rollout);  // 0.1
```

---

## What Kael Learned

> *"The Banner is not just a feature flag. It's a deployment strategy. With reactive state, percentage rollout, and targeting rules, I can ship features fearlessly — raising the standard gradually, watching the metrics, and pulling back if needed. The Questboard is safer for it."*

| Concept | Titan Name | Purpose |
|---------|------------|---------|
| Feature Flag Registry | **Banner** | Reactive flag management |
| Flag Config | **BannerFlag** | Name, default, rules, rollout, expiry |
| Targeting Rule | **BannerRule** | Context-based flag evaluation |
| Evaluation Result | **BannerEvaluation** | Resolved value + reason |

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart'`

---

*Next: [Chapter XL →](chapter-40-the-sieve-filters.md)*
