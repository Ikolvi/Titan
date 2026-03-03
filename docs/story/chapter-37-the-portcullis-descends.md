# Chapter XXXVII — The Portcullis Descends

*In which the fortress learns to seal its gates when danger strikes, protecting the realm from cascading ruin.*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

The warning klaxons rang through the Questboard's watchtower.

"Payment gateway is failing!" shouted the watch commander, scrolling through a cascade of red error banners. Every quest completion attempt that morning had been met with the same cruel timeout — the third-party payment processor was drowning under load, and every retry attempt from the Questboard's servers only added to the deluge.

Kael watched the carnage unfold from the engineering chamber. Heroes couldn't claim their rewards. Quest givers couldn't post bounties. The entire reward pipeline had frozen — not because the Questboard itself was broken, but because it kept hammering a service that was already overwhelmed.

"We need to stop hitting it," Kael muttered. "When a gate is breached, you don't keep sending soldiers through it. You drop the **portcullis**."

---

## The First Gate

The Portcullis was a defensive mechanism as old as fortress warfare — a heavy iron gate that could be dropped in an instant when enemies approached. But unlike a wall, a portcullis could be raised again once the danger had passed. And unlike simply disconnecting, it could probe cautiously before fully reopening.

```dart
class PaymentPillar extends Pillar {
  late final gateway = portcullis(
    failureThreshold: 3,
    resetTimeout: Duration(seconds: 30),
    name: 'payment-gateway',
  );

  late final balance = core(0.0);

  Future<Receipt> processPayment(double amount) async {
    return gateway.protect(() async {
      final receipt = await paymentApi.charge(amount);
      balance.value += amount;
      return receipt;
    });
  }
}
```

"Three failures and the gate drops," Kael explained to the watch commander. "No more requests get through for thirty seconds. Then it opens a crack — one test request — and if that succeeds, the gate rises again."

---

## The Three States

The commander traced the circuit diagram on parchment:

```
   ┌──────────┐  failures >= 3    ┌──────────┐
   │  CLOSED  │ ────────────────→ │   OPEN   │
   │ (healthy)│                    │ (tripped)│
   └──────────┘                    └──────────┘
        ↑                               │
        │  probe succeeds               │ 30s timeout
        │                               ↓
        │                         ┌──────────┐
        └──────────────────────── │ HALF-OPEN│
                                   │ (probing)│
                                   └──────────┘
```

"**Closed** means everything is normal," Kael said. "Requests flow through. We count failures, but if a success comes along, the count resets to zero."

"**Open** means the gate has dropped. Every request is instantly rejected — no waiting, no timeout, no adding to the server's load. This is the fast-fail. We throw a `PortcullisOpenException` instead."

"**Half-open** is the cautious test. After the timeout, we let one request through. If it succeeds, we raise the gate. If it fails, we drop it again."

```dart
switch (pillar.gateway.state) {
  case PortcullisState.closed:
    return StatusBadge('Healthy', color: Colors.green);
  case PortcullisState.open:
    return StatusBadge('Circuit Open', color: Colors.red);
  case PortcullisState.halfOpen:
    return StatusBadge('Testing...', color: Colors.orange);
}
```

---

## Catching the Gate

When the gate was open, callers needed to handle the rejection gracefully:

```dart
Future<void> claimReward(String questId) async {
  try {
    final receipt = await pillar.processPayment(reward);
    showSuccess('Reward claimed!');
  } on PortcullisOpenException catch (e) {
    showWarning(
      'Payment system is recovering. '
      'Try again in ${e.remainingTimeout?.inSeconds}s.',
    );
  } catch (e) {
    showError('Payment failed: $e');
  }
}
```

"The `PortcullisOpenException` tells you *why* the request was rejected and *when* to try again," Kael noted. "It even carries the breaker's name so you know which service is down."

---

## Selective Failures

Not every error meant the service was down. A 400 Bad Request was a client error — the server was fine. Only server errors (500s, timeouts, network failures) should count toward tripping the circuit.

```dart
late final gateway = portcullis(
  failureThreshold: 5,
  resetTimeout: Duration(seconds: 30),
  shouldTrip: (error, stack) {
    // Only trip on server errors, not client errors
    if (error is ApiException) {
      return error.statusCode >= 500;
    }
    return true; // Network errors always count
  },
  name: 'payment-gateway',
);
```

"A `FormatException` from bad JSON parsing? That's our bug, not the server's — don't trip for that. A `SocketException`? The server is unreachable — that counts."

---

## The Watchtower Dashboard

Every piece of the Portcullis's state was reactive. The watch commander's dashboard updated in real time:

```dart
Vestige<PaymentPillar>(
  builder: (context, pillar) {
    return Column(
      children: [
        // Status indicator
        Chip(
          label: Text(pillar.gateway.state.name),
          backgroundColor: pillar.gateway.isClosed
              ? Colors.green.shade100
              : Colors.red.shade100,
        ),

        // Live counters
        Text('Failures: ${pillar.gateway.failureCount}'),
        Text('Successes: ${pillar.gateway.successCount}'),
        Text('Total trips: ${pillar.gateway.tripCount}'),

        // Trip history
        ...pillar.gateway.tripHistory.map(
          (r) => ListTile(
            title: Text('Trip at ${r.timestamp}'),
            subtitle: Text('After ${r.failureCount} failures'),
          ),
        ),
      ],
    );
  },
);
```

"Reactive state management isn't just for UI data," Kael reflected. "Infrastructure health is state too."

---

## Manual Overrides

Sometimes the watch commander needed to act on intelligence, not just metrics:

```dart
// Proactive protection — we know maintenance is scheduled
pillar.gateway.trip();

// Force recovery — we confirmed the service is back
pillar.gateway.reset();
```

"If the downstream team tells us they're deploying at midnight, we drop the gate proactively. No need to wait for three failures to tell us what we already know."

---

## Multiple Probes

For critical services, a single successful probe wasn't enough confidence:

```dart
late final gateway = portcullis(
  failureThreshold: 5,
  resetTimeout: Duration(seconds: 30),
  halfOpenMaxProbes: 3,  // Need 3 consecutive successes
  name: 'critical-api',
);
```

"Three successful probes before we raise the gate. One failure at any point sends us back to open. Trust is earned, not given."

---

## The Fortress Holds

By afternoon, the payment processor had recovered. The Portcullis had done its work — the Questboard remained responsive throughout the outage, showing heroes a polite "try again soon" message instead of freezing on timeouts. The processor thanked them; the reduced load had helped it recover faster.

"Without the Portcullis, we would have made things worse," the watch commander admitted. "Every retry was another nail in the coffin."

Kael nodded. "A good castle doesn't just have walls. It has gates that know when to close — and when to open again."

---

## What the Builder Learned

The Portcullis taught the fortress three lessons:

1. **Fast-fail is a feature** — Rejecting requests instantly is better than letting them
   queue and timeout. The user gets a clear answer in milliseconds instead of waiting
   30 seconds for nothing.

2. **Recovery must be automatic** — Manual intervention doesn't scale. The half-open
   state probes cautiously so the system self-heals without human involvement.

3. **Resilience state is reactive** — Circuit breaker status isn't just for ops dashboards.
   It should flow into the UI so users see meaningful feedback, not spinner-of-death.

---

| Navigation | |
|---|---|
| [← Chapter XXXVI: The Ledger Binds](chapter-36-the-ledger-binds.md) | [Chapter XXXVIII: The Anvil Strikes →](chapter-38-the-anvil-strikes.md) |
