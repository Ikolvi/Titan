# Chapter XLVII: The Tithe is Tallied

> *"The Moat had controlled the flow — but flow without measure was still recklessness. How many API calls had been made today? How close was the storage quota? Were free-tier users burning through their allocation without warning? The application needed more than a gate; it needed an accountant. The Tithe rose to count every coin spent and sound the alarm before the coffers ran dry."*

---

## The Problem

Questboard's free tier allowed 1,000 API calls per hour. Premium heroes got 10,000. But there was no system to track consumption, warn users as they approached their limit, or refuse requests gracefully when the budget was spent.

"The Moat rate-limits bursts," Kael said, "but it doesn't know how much has been used in total."

```dart
// Moat limits flow rate, not cumulative total
final limiter = Moat(maxTokens: 10, refillRate: 10); // 10 RPS

// But how many total calls this hour?
int _callCount = 0; // Manual tracking...
```

"Manual counters aren't reactive," Lyra observed. "Your UI can't show a progress bar. You can't set threshold alerts at 80% and 90%. And when the billing period resets, you need to zero everything atomically — including per-endpoint breakdowns."

She produced a small ledger bound in bronze. "You need the **Tithe** — a reactive budget that counts every expenditure and sounds the alarm before the treasury is empty."

---

## The Tithe is Tallied

```dart
class ApiPillar extends Pillar {
  late final apiQuota = tithe(
    budget: 1000,                              // 1,000 calls per period
    resetInterval: Duration(hours: 1),         // Auto-resets hourly
    name: 'api_quota',
  );

  Future<Response> callApi(String endpoint) async {
    if (!apiQuota.tryConsume(1, key: endpoint)) {
      throw QuotaExceededException('API quota exhausted');
    }
    return _httpClient.get(endpoint);
  }
}
```

"The Tithe tracks consumption with a single `consume()` call," Lyra explained. "And `tryConsume()` checks before consuming — it returns `false` without deducting if the budget can't afford it."

---

## Reactive Budget Signals

Every metric was a reactive signal, ready for UI binding:

```dart
Vestige<ApiPillar>(
  builder: (context, pillar, child) {
    final consumed = pillar.apiQuota.consumed.value;
    final remaining = pillar.apiQuota.remaining.value;
    final ratio = pillar.apiQuota.ratio.value;
    final exceeded = pillar.apiQuota.exceeded.value;

    return Column(children: [
      LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
      Text('$consumed / ${pillar.apiQuota.budget} used'),
      Text('$remaining remaining'),
      if (exceeded)
        Text('⚠ Quota exceeded!', style: TextStyle(color: Colors.red)),
    ]);
  },
)
```

| Signal | Type | Description |
|--------|------|-------------|
| `consumed` | `Core<int>` | Total consumed this period |
| `remaining` | `Derived<int>` | Budget minus consumed (can go negative) |
| `exceeded` | `Derived<bool>` | True when consumed >= budget |
| `ratio` | `Derived<double>` | consumed / budget (0.0–1.0+) |
| `breakdown` | `Core<Map<String, int>>` | Per-key consumption |

---

## Per-Key Breakdown

Kael needed to know which endpoints ate the most quota:

```dart
pillar.apiQuota.consume(1, key: '/quests');
pillar.apiQuota.consume(1, key: '/heroes');
pillar.apiQuota.consume(1, key: '/quests');

print(pillar.apiQuota.breakdown.value);
// {/quests: 2, /heroes: 1}
```

"The breakdown is reactive too," Lyra said. "You can build a usage chart that updates in real time, broken down by endpoint, resource type, or user action."

---

## Threshold Alerts

"I want to warn users at 80%," Kael said.

```dart
pillar.apiQuota.onThreshold(0.8, () {
  showWarning('You have used 80% of your API quota');
});

pillar.apiQuota.onThreshold(0.95, () {
  showWarning('Almost at your limit!');
});

pillar.apiQuota.onThreshold(1.0, () {
  lockFeatures(); // Disable non-essential calls
});
```

"Thresholds fire once when the percentage is first crossed," Lyra explained. "They re-arm automatically when the budget resets — whether by timer or manual `reset()`."

---

## Auto-Reset and Manual Reset

The `resetInterval` created a periodic timer:

```dart
// Resets every hour automatically
late final hourlyQuota = tithe(
  budget: 1000,
  resetInterval: Duration(hours: 1),
);
```

For manual control — such as when a user upgrades their plan:

```dart
void onPlanUpgrade() {
  // Reset consumption and re-arm all thresholds
  pillar.apiQuota.reset();
}
```

---

## The Governance Triad

Kael stepped back and saw how Tithe completed the resource governance pattern:

| Component | Controls | Example |
|-----------|----------|---------|
| **Mandate** | Access control | "Can this role perform this action?" |
| **Moat** | Flow rate | "Max 10 requests per second" |
| **Tithe** | Cumulative usage | "Max 1,000 calls per hour" |

"Mandate decides *if* you can. Moat decides *how fast* you can. Tithe decides *how much* you can," Lyra summarized. "Together, they form a complete governance stack."

---

## The Metrics

```
47. Tithe       | consume(100K)             | 100000 × 0.073 µs/op
47. Tithe       | consume+key(100K)         | 100000 × 0.166 µs/op
47. Tithe       | tryConsume(100K)           | 100000 × 0.042 µs/op
```

Sub-100 nanosecond consume. The overhead was unmeasurable — a tithe so light it cost nothing to collect.

---

## What the Tithe Taught

Kael recorded the lessons:

1. **Count, don't just throttle** — rate limiting controls bursts; quotas control totals
2. **React to budgets** — remaining and exceeded as signals means the UI always knows the score
3. **Break it down** — per-key tracking reveals which features consume the most
4. **Alert before failure** — thresholds at 80%, 95%, 100% give users time to adapt
5. **Reset atomically** — period resets must zero consumption and re-arm alerts in one step

The Tithe had been tallied, and Questboard's heroes finally knew what they owed — and what they could still afford.

---

*Next: [Chapter XLVIII — *forthcoming*]*
