# Chapter XXXII: The Moat Defends

> *"The castle walls were strong, but without a moat, the hordes could charge unchecked. The moat didn't stop everyone — it simply controlled the flow. One at a time, measured and deliberate, never more than the keep could bear."*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

## The Problem

Questboard was popular. *Too* popular. Heroes hammered the search endpoint — typing fast, every keystroke firing a request. Rate limits arrived. API keys got throttled. Worse, impatient heroes tapped "Retry" repeatedly, creating avalanches of duplicate requests.

"The debounce on the search input helps," Kael said, "but it doesn't stop a hero from calling the same endpoint 60 times in a minute from different screens. We need *request-level* rate limiting."

Lyra studied the API docs. "The search API allows 10 requests per second. The quest API allows 60 per minute. We need independent buckets with different rates."

"We need a **Moat**."

---

## The Moat

A moat controls access to a fortress. Titan's `Moat` is a token-bucket rate limiter — a fixed number of tokens are available, consumed with each request, and refilled at a steady rate. When the bucket is empty, requests are rejected.

```dart
import 'package:titan/titan.dart';

class SearchPillar extends Pillar {
  late final searchLimiter = moat(
    maxTokens: 10,
    refillRate: Duration(seconds: 1),
    name: 'search',
  );

  Future<List<Quest>> search(String query) async {
    if (!searchLimiter.tryConsume()) {
      throw RateLimitedException('Search rate limited');
    }
    return await api.search(query);
  }
}
```

The `moat()` factory method on Pillar creates a managed rate limiter with automatic disposal. When the Pillar disposes, the Moat — its refill timer, its reactive state — disposes with it.

---

## Token Bucket Algorithm

The Moat uses a classic token-bucket algorithm:

1. The bucket starts full (10 tokens)
2. Each `tryConsume()` removes one token
3. Tokens refill at the configured rate (1 per second)
4. When empty, requests are rejected

```dart
final limiter = Moat(
  maxTokens: 10,           // bucket capacity
  refillRate: Duration(seconds: 1),  // one token per second
);

limiter.tryConsume(); // true — 9 tokens remain
limiter.tryConsume(); // true — 8 tokens remain
// ... consume all tokens
limiter.tryConsume(); // false — bucket empty, request rejected
// Wait 1 second... token refills
limiter.tryConsume(); // true — token was refilled
```

Tokens are refilled based on elapsed time, not discrete ticks, giving precise sub-second accuracy.

---

## Cost-Based Consumption

Some operations are more expensive than others. Consume multiple tokens for heavy requests:

```dart
// Light operation: 1 token
limiter.tryConsume();

// Heavy operation: 3 tokens
limiter.tryConsume(3);

// Bulk export: 5 tokens
if (limiter.tryConsume(5)) {
  await exportAllQuests();
}
```

---

## The Guard Pattern

The most common pattern — execute if allowed, handle rejection otherwise — is a single call:

```dart
final result = await limiter.guard(
  () async => await api.fetchLeaderboard(),
  onLimit: () => showSnackBar('Too many requests — slow down!'),
);

if (result != null) {
  displayLeaderboard(result);
}
```

`guard()` tries to consume a token. If allowed, it executes the action and returns the result. If rejected, it calls `onLimit` and returns `null`.

---

## Blocking Consume

Sometimes you *want* to wait for a token rather than fail immediately:

```dart
// Wait until a token is available (with timeout)
final allowed = await limiter.consume(
  timeout: Duration(seconds: 5),
);

if (allowed) {
  await performAction();
} else {
  // Timed out waiting for a token
  showError('Request timed out');
}
```

Without a timeout, `consume()` waits indefinitely. With a timeout, it returns `false` if no token becomes available in time.

---

## Reactive Rate Limit State

Every Moat exposes reactive Cores for its state:

```dart
class ApiPillar extends Pillar {
  late final limiter = moat(
    maxTokens: 60,
    refillRate: Duration(seconds: 1),
    name: 'api',
  );

  // Reactive Cores:
  // limiter.remainingTokens  → current available tokens
  // limiter.rejections       → total rejected requests
  // limiter.consumed         → total consumed tokens
  // limiter.hasTokens        → bool
  // limiter.fillPercentage   → 0.0–100.0
  // limiter.timeToNextToken  → Duration until next refill
}
```

In a Vestige:

```dart
Vestige<ApiPillar>(
  builder: (context, pillar) {
    final remaining = pillar.limiter.remainingTokens.value;
    final max = pillar.limiter.maxTokens;
    return Column(
      children: [
        LinearProgressIndicator(value: remaining / max),
        Text('$remaining/$max requests available'),
        Text('Rejected: ${pillar.limiter.rejections.value}'),
      ],
    );
  },
)
```

---

## Per-Key Rate Limiting with MoatPool

Different resources need different rate limits. `MoatPool` creates independent Moat instances per key:

```dart
class ApiGatewayPillar extends Pillar {
  final pool = MoatPool(
    maxTokens: 10,
    refillRate: Duration(seconds: 1),
  );

  Future<dynamic> request(String endpoint, Future<dynamic> Function() call) async {
    if (!pool.tryConsume(endpoint)) {
      throw RateLimitedException('$endpoint rate limited');
    }
    return await call();
  }
}

// Each endpoint gets its own independent bucket:
await gateway.request('search', () => api.search(query));
await gateway.request('quests', () => api.fetchQuests());
await gateway.request('users', () => api.fetchUser(id));
```

Each key gets a lazily-created Moat with the pool's shared configuration. The `search` bucket running dry doesn't affect the `quests` bucket.

### Pool Management

```dart
// Get a specific limiter
final searchLimiter = pool.get('search');
print(searchLimiter.remainingTokens.value);

// Check if a key has a limiter
if (pool.containsKey('search')) { ... }

// Remove a specific limiter (disposes it)
pool.remove('search');

// See all active keys
print(pool.keys); // {'quests', 'users'}

// Dispose all limiters
pool.dispose();
```

---

## Rejection Callbacks

Get notified when requests are rejected:

```dart
final limiter = Moat(
  maxTokens: 5,
  refillRate: Duration(seconds: 1),
  onReject: () {
    analytics.track('rate_limited');
    log.warn('Rate limit hit');
  },
);
```

The callback fires on every rejection — from `tryConsume()`, `consume()` timeout, or `guard()`.

---

## Burst Control

Control the initial burst capacity separately from the steady-state refill:

```dart
final limiter = Moat(
  maxTokens: 100,               // steady-state capacity
  initialTokens: 10,            // start with only 10
  refillRate: Duration(seconds: 1),
);

// Only 10 requests allowed immediately
// Then 1 per second up to 100
```

This prevents startup bursts while allowing a generous sustained rate.

---

## Pillar Integration

The `moat()` factory method creates a managed rate limiter:

```dart
class QuestPillar extends Pillar {
  late final createLimiter = moat(
    maxTokens: 5,
    refillRate: Duration(minutes: 1),
    onReject: () => log.warn('Quest creation rate limited'),
    name: 'quest-create',
  );

  Future<void> createQuest(Quest quest) async {
    final result = await createLimiter.guard(
      () async => await api.createQuest(quest),
      onLimit: () => emit('rate_limited'),
    );
    if (result != null) {
      quests.value = [...quests.value, result];
    }
  }
}
```

No manual cleanup — when the Pillar disposes, the Moat disposes with it.

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Moat` | Token-bucket rate limiter with reactive state |
| `moat()` | Pillar factory method — auto-managed lifecycle |
| `tryConsume()` | Non-blocking token consumption (true/false) |
| `consume()` | Blocking consumption with optional timeout |
| `guard()` | Execute-or-reject pattern with callback |
| `MoatPool` | Per-key independent rate limiters |
| `remainingTokens` / `rejections` / `consumed` | Reactive rate limit state (Cores) |
| `hasTokens` / `fillPercentage` | Convenience getters |
| `timeToNextToken` | Duration until next refill |
| `initialTokens` | Control startup burst behavior |
| `onReject` | Callback for rejected requests |

---

> *"The Moat encircled the fortress, its waters calm but unyielding. Requests arrived in waves, but only those the bucket allowed crossed the bridge. The servers breathed easy. The heroes barely noticed — except that nothing crashed anymore."*

---

[← Chapter XXXI: The Trove Hoards](chapter-31-the-trove-hoards.md) | [Chapter XXXIII: The Omen Foretells →](chapter-33-the-omen-foretells.md)
