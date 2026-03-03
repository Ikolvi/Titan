# Chapter XLIII: The Census Counts

> *"Before the Census, the dashboard was blind. It showed the current value — the last order, the latest response time, the most recent error — but it couldn't answer the questions that mattered: How many orders in the last five minutes? What's the average response time today? What's the 95th percentile latency trend? The Census gave the Questboard memory — not the deep memory of the Annals, which recorded every event forever, but a living memory that breathed with the present, always ready with the answer to 'how are things going right now?'"*

---

## The Problem

Kael stared at the Questboard's merchant dashboard. The guild master had asked a simple question: "How much gold flowed through the shop this morning?" Kael could see the last transaction — 47 gold for a healing salve — but the cumulative total? The average order? Whether orders were trending up or down? Nothing.

"I could keep a counter," Kael said, adding a variable:

```dart
double totalGold = 0;
int orderCount = 0;

void onOrder(double amount) {
  totalGold += amount;
  orderCount++;
}
```

"But that counts *all* orders since the app started," Lyra pointed out. "The guild master wants the last five minutes. And when slow requests pile up, we need the 95th percentile, not just the average."

Kael tried a `List<double>` with timestamps:

```dart
final List<(DateTime, double)> recentOrders = [];

void onOrder(double amount) {
  recentOrders.add((DateTime.now(), amount));
  // Evict old entries...
  recentOrders.removeWhere(
    (e) => DateTime.now().difference(e.$1) > Duration(minutes: 5),
  );
}

double get average => recentOrders.isEmpty ? 0 :
  recentOrders.map((e) => e.$2).reduce((a, b) => a + b) / recentOrders.length;
```

"Every call recomputes everything," Lyra frowned. "The eviction scans the entire list. The average allocates an iterator. And none of this is reactive — your widgets won't rebuild when the stats change."

She placed a new scroll on the table. "You need the **Census**."

---

## The Census Appears

```dart
class MerchantPillar extends Pillar {
  late final orderAmount = core(0.0);
  
  late final orderStats = census<double>(
    source: orderAmount,
    window: Duration(minutes: 5),
    name: 'orders',
  );
}
```

Kael blinked. "That's it?"

"Record a value, and the Census maintains everything: count, sum, average, min, max — all reactive, all within the sliding window. Old entries expire automatically."

```dart
// Every time a purchase completes:
pillar.orderAmount.value = 47.0;
pillar.orderAmount.value = 120.5;
pillar.orderAmount.value = 15.0;

// The dashboard reads live stats:
print(pillar.orderStats.count.value);   // 3
print(pillar.orderStats.sum.value);     // 182.5
print(pillar.orderStats.average.value); // 60.83
print(pillar.orderStats.min.value);     // 15.0
print(pillar.orderStats.max.value);     // 120.5
```

---

## The Window Slides

Five minutes later, the earliest orders expired. The Census evicted them silently:

```dart
// After 5 minutes, early entries age out:
pillar.orderAmount.value = 200.0; // This triggers eviction of stale entries.

print(pillar.orderStats.count.value); // Only recent entries remain.
```

"The window slides forward continuously," Lyra explained. "You always see the last five minutes of activity, not a stale total from hours ago."

---

## Manual Recording

For the server latency monitor, Kael didn't have a reactive Core — just callback events:

```dart
class LatencyPillar extends Pillar {
  late final latency = census<double>(
    window: Duration(minutes: 1),
    name: 'latency',
  );
  
  void onRequestComplete(double responseMs) {
    latency.record(responseMs);
  }
}
```

"Call `record()` directly when there's no reactive source to watch," Lyra said.

---

## The Percentile Question

The infrastructure team needed more than averages. "Average latency is fine," the lead architect said, "but one slow request hidden in a thousand fast ones doesn't move the average. We need the 95th percentile."

```dart
class InfraPillar extends Pillar {
  late final apiLatency = census<int>(
    window: Duration(minutes: 5),
    name: 'api_latency',
  );
  
  void onResponse(int ms) {
    apiLatency.record(ms);
  }
  
  double get p50 => apiLatency.percentile(50);  // Median
  double get p95 => apiLatency.percentile(95);  // 95th percentile
  double get p99 => apiLatency.percentile(99);  // 99th percentile
}
```

"Percentile uses linear interpolation between ranks," Lyra explained. "It sorts the window entries and finds the value at the requested position. Not the cheapest operation, but exactly what you need for SLA monitoring."

---

## Bounding the Buffer

Kael worried about memory. "What if we get a million events in five minutes?"

```dart
late final highFreqStats = census<double>(
  window: Duration(minutes: 5),
  maxEntries: 10000,    // Hard cap: 10K entries maximum.
  name: 'high_freq',
);
```

"The `maxEntries` parameter caps the buffer," Lyra said. "If the queue overflows, the oldest entries are dropped — even if they're within the time window. For high-frequency data, this prevents unbounded growth."

---

## Real-Time Dashboard

The Vestige widget brought it all together:

```dart
class MerchantDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Vestige<MerchantPillar>(
      builder: (context, pillar) => Column(
        children: [
          Text('Orders (5 min): ${pillar.orderStats.count.value}'),
          Text('Total Gold: ${pillar.orderStats.sum.value.toStringAsFixed(1)}'),
          Text('Average: ${pillar.orderStats.average.value.toStringAsFixed(1)}'),
          Text('Min: ${pillar.orderStats.min.value.toStringAsFixed(1)}'),
          Text('Max: ${pillar.orderStats.max.value.toStringAsFixed(1)}'),
          Text('P95: ${pillar.orderStats.percentile(95).toStringAsFixed(1)}'),
        ],
      ),
    );
  }
}
```

Every time a new order arrived, the dashboard updated instantly. When old entries expired, the numbers adjusted. The guild master finally had the answer: *"How are things going right now?"*

---

## Census vs. Derived vs. Annals

Kael summarized the three computation models:

| Feature | Computes From | Time Scope | Purpose |
|---------|---------------|------------|---------|
| **Derived** | Current values | Point-in-time | "What is the value NOW?" |
| **Annals** | All events ever | Entire history | "What happened?" (audit) |
| **Census** | Recent values | Sliding window | "How are things going?" (metrics) |

"Derived is a lens on the present. Annals is a record of the past. Census is a pulse on the trend."

---

## The Incantation Scroll

```dart
// ─── Census: Sliding-Window Data Aggregation ───

// 1. Auto-record from a reactive source:
late final orderStats = census<double>(
  source: orderAmount,       // Subscribe to this Core
  window: Duration(minutes: 5),
  name: 'orders',
);

// 2. Manual recording:
late final latencyStats = census<int>(
  window: Duration(minutes: 1),
  name: 'latency',
);
latencyStats.record(42);

// 3. Read reactive aggregates:
orderStats.count.value      // int — entries in window
orderStats.sum.value        // double — sum
orderStats.average.value    // double — mean
orderStats.min.value        // double — minimum
orderStats.max.value        // double — maximum
orderStats.last.value       // double — most recent
orderStats.percentile(95)   // double — Nth percentile

// 4. Cap buffer size:
census<double>(
  window: Duration(minutes: 10),
  maxEntries: 5000,          // Hard limit
);

// 5. Snapshot entries:
final snapshot = orderStats.entries; // List<CensusEntry<double>>

// 6. Cleanup:
orderStats.reset();  // Clear all entries
orderStats.evict();  // Remove only stale entries
```

---

*The Census gave the Questboard the one thing it had always lacked — the ability to answer "how are things going right now?" Not a single number frozen in time, but a living aggregate that breathed with the system's pulse. Kael looked at the dashboard and smiled. The numbers were alive.*

*But living numbers need living alerts. As the Census tracked the trends, Kael realized the system needed something more: a way to detect when aggregates crossed thresholds, when trends turned dangerous, when the pulse quickened beyond safe limits. The answer was already forming in the forge...*

---

| | |
|---|---|
| [← Chapter XLII: The Embargo Holds](chapter-42-the-embargo-holds.md) | [Chapter XLIV →](chapter-44-tbd.md) |
