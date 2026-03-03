# Chapter XLIV: The Warden Patrols

> *"Before the Warden, the application was like a castle with unwatched gates. The frontend spoke to a dozen services — authentication, payments, notifications, search, analytics — but never knew which were alive until a request failed. Users saw spinning loaders that never resolved, error messages that blamed the wrong thing, retry buttons that hammered dead endpoints. The Warden changed everything: it patrolled the borders continuously, checking every outpost, and the moment any fell silent, the castle knew."*

---

## The Problem

Kael's Questboard talked to five backend services: the quest API, the merchant API, the authentication server, the notification service, and the leaderboard. When the merchant API went down during a sale, users saw a cryptic error: "Something went wrong." No one knew *what* went wrong.

"I could ping each service manually," Kael said, writing health check code:

```dart
bool _authHealthy = true;
bool _merchantHealthy = true;
bool _questHealthy = true;

Future<void> checkHealth() async {
  try {
    await http.get('/auth/health');
    _authHealthy = true;
  } catch (_) {
    _authHealthy = false;
  }
  // Repeat for every service...
}
```

"That's five separate try-catch blocks," Lyra said. "Five boolean flags. No timestamps, no failure counts, no latency tracking. And none of it is reactive — your widgets don't rebuild when health changes."

She unrolled a scroll with a new sigil. "You need the **Warden**."

---

## The Warden Appears

```dart
class ApiPillar extends Pillar {
  late final health = warden(
    interval: Duration(seconds: 30),
    services: [
      WardenService(
        name: 'auth',
        check: () => api.ping('/auth/health'),
      ),
      WardenService(
        name: 'merchant',
        check: () => api.ping('/merchant/health'),
      ),
      WardenService(
        name: 'quests',
        check: () => api.ping('/quests/health'),
      ),
      WardenService(
        name: 'notifications',
        check: () => api.ping('/notifications/health'),
        critical: false,  // Non-critical service
      ),
    ],
  );

  @override
  void onInit() {
    health.start();
  }
}
```

"Define your services, start the Warden, and it patrols every 30 seconds," Lyra explained. "Each service gets its own reactive state. The aggregate health covers all *critical* services."

---

## Per-Service Reactive State

Every service exposed four reactive properties:

```dart
// Status: unknown → healthy → degraded → down
health.status('auth').value     // ServiceStatus.healthy

// Latency: milliseconds of the last check
health.latency('auth').value    // 45

// Consecutive failures
health.failures('auth').value   // 0

// Timestamp of last check
health.lastChecked('auth').value  // DateTime(2024, 3, 15, 10, 30, 0)
```

"When a check function completes normally, the service is healthy," Lyra said. "When it throws, the failure counter increments. After three consecutive failures, the service is marked *down*."

---

## The Down Threshold

```dart
WardenService(
  name: 'payments',
  check: () => api.ping('/payments/health'),
  downThreshold: 5,  // Mark down after 5 consecutive failures
)
```

"One failed ping might be a network blip," Lyra explained. "Three might be a problem. Five — the service is truly down. You choose the threshold."

When a check succeeds again, the failure counter resets to zero and the status returns to healthy:

```dart
// After recovery:
health.status('payments').value   // ServiceStatus.healthy
health.failures('payments').value // 0
```

---

## Aggregate Health

The Warden computed aggregate health from all critical services:

```dart
health.overallHealth.value   // ServiceStatus.healthy (all critical pass)
health.healthyCount.value    // 3 (out of 4 services)
health.degradedCount.value   // 1 (notifications — but non-critical)
```

"The `overallHealth` is healthy only when *every critical* service is healthy," Lyra said. "Non-critical services — like notifications — don't affect the aggregate. They can fail without bringing down the status page."

---

## Graceful Degradation

With reactive health state, the UI could respond intelligently:

```dart
class ShopScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Vestige<ApiPillar>(
      builder: (context, pillar) {
        final merchantOk =
            pillar.health.status('merchant').value == ServiceStatus.healthy;

        return Column(
          children: [
            if (!merchantOk)
              Banner(
                message: 'Shop is temporarily unavailable',
                backgroundColor: Colors.orange,
              ),
            FilledButton(
              onPressed: merchantOk ? () => buyItem() : null,
              child: Text(merchantOk ? 'Buy' : 'Shop Offline'),
            ),
            // Show health dashboard for admins
            Text('System: ${pillar.health.overallHealth.value.name}'),
            Text('Latency: ${pillar.health.latency("merchant").value}ms'),
          ],
        );
      },
    );
  }
}
```

"Instead of letting users click a button that will fail," Kael realized, "we disable it before they try. The Warden tells us *before* the failure happens."

---

## Per-Service Intervals

Some services needed more frequent monitoring:

```dart
WardenService(
  name: 'auth',
  check: () => api.ping('/auth/health'),
  interval: Duration(seconds: 10),  // Check every 10 seconds
),
WardenService(
  name: 'analytics',
  check: () => api.ping('/analytics/health'),
  interval: Duration(minutes: 2),   // Less critical, check less often
  critical: false,
),
```

"Authentication is critical — check it every 10 seconds," Lyra said. "Analytics is nice-to-have — every 2 minutes is fine."

---

## Manual Checks

Sometimes you needed an immediate answer:

```dart
// Force-check a single service
await health.checkService('payments');

// Force-check all services
await health.checkAll();
```

---

## The Status Dashboard

The operations team wanted a full status page:

```dart
class StatusPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Vestige<ApiPillar>(
      builder: (context, pillar) {
        final names = pillar.health.serviceNames;
        return ListView.builder(
          itemCount: names.length,
          itemBuilder: (context, i) {
            final name = names[i];
            final status = pillar.health.status(name).value;
            final latency = pillar.health.latency(name).value;
            final failures = pillar.health.failures(name).value;

            return ListTile(
              leading: Icon(
                status == ServiceStatus.healthy
                    ? Icons.check_circle
                    : status == ServiceStatus.down
                        ? Icons.error
                        : Icons.warning,
                color: status == ServiceStatus.healthy
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(name),
              subtitle: Text('${latency}ms • $failures failures'),
            );
          },
        );
      },
    );
  }
}
```

---

## The Incantation Scroll

```dart
// ─── Warden: Reactive Service Health Monitor ───

// 1. Define services:
late final health = warden(
  interval: Duration(seconds: 30),
  services: [
    WardenService(name: 'auth', check: () => api.ping('/auth')),
    WardenService(name: 'db', check: () => db.ping()),
    WardenService(
      name: 'analytics',
      check: () => api.ping('/analytics'),
      critical: false,       // Doesn't affect overall health
      downThreshold: 5,      // 5 failures before "down"
      interval: Duration(minutes: 2),  // Less frequent
    ),
  ],
);

// 2. Start/stop polling:
health.start();   // Begins periodic checks
health.stop();    // Cancels all timers

// 3. Per-service reactive state:
health.status('auth').value       // ServiceStatus
health.latency('auth').value      // int (ms)
health.failures('auth').value     // int
health.lastChecked('auth').value  // DateTime?

// 4. Aggregate reactive state:
health.overallHealth.value  // ServiceStatus (all critical)
health.healthyCount.value   // int
health.degradedCount.value  // int
health.isChecking.value     // bool
health.totalChecks.value    // int

// 5. Manual checks:
await health.checkService('auth');
await health.checkAll();

// 6. Reset:
health.reset();  // Clears all state, stops polling
```

---

*The Warden gave the Questboard eyes where it had been blind. Every service, every endpoint, every dependency — all monitored, all reactive, all visible. The operations team could see the realm's health at a glance, and the users never again clicked a button connected to a dead service.*

*But as the Warden watched the borders, Kael noticed a pattern in the Census data: response times were climbing, errors were clustering, and the system's pulse was quickening. The numbers told a story, but they needed someone — or something — to read it and sound the alarm before the crisis arrived...*

---

| | |
|---|---|
| [← Chapter XLIII: The Census Counts](chapter-43-the-census-counts.md) | [Chapter XLV →](chapter-45-tbd.md) |
