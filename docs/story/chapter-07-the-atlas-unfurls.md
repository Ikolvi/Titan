# Chapter VII: The Atlas Unfurls

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"When the kingdom was young, it had one room. Then two. Then a dozen. Hallways appeared, doors multiplied, passages twisted through towers and dungeons. Someone needed to map it all. Atlas — the Titan who bore the weight of the entire world — stepped forward and unrolled his chart. Every path, every passage, every dead end — he knew them all."*

---

## Beyond a Single Screen

Questboard had outgrown its single screen. Kael needed:

- `/` — The quest board (home)
- `/quest/:id` — Quest detail with notes
- `/heroes` — Leaderboard
- `/hero/:id` — Hero profile
- `/settings` — App settings
- `/admin` — Admin panel (protected)

Kael had tried Flutter's built-in Navigator 1.0 with its imperative `push` and `pop`. It worked for simple apps, but Questboard needed deep links, route guards, and persistent layouts. That meant Navigator 2.0 — and Kael had heard the horror stories. 

Then Kael found **Atlas**.

---

## Charting the Passages

Atlas maps your app's routes declaratively. Each route is a **Passage** — a path pattern paired with a builder:

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  passages: [
    Passage('/', (waypoint) => const QuestboardScreen()),
    Passage('/quest/:id', (waypoint) {
      final questId = waypoint.runes['id']!;
      return QuestDetailScreen(questId: questId);
    }),
    Passage('/heroes', (waypoint) => const LeaderboardScreen()),
    Passage('/hero/:id', (waypoint) {
      final heroId = waypoint.runes['id']!;
      return HeroProfileScreen(heroId: heroId);
    }),
    Passage('/settings', (waypoint) => const SettingsScreen()),
  ],
);
```

Each Passage receives a **Waypoint** — the resolved route state containing the path, pattern, dynamic parameters (Runes), query parameters, and any extra data.

---

## Wiring to Flutter

Atlas provides a `RouterConfig` that plugs directly into Flutter's `MaterialApp.router`:

```dart
class QuestboardApp extends StatelessWidget {
  const QuestboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Questboard',
      routerConfig: atlas.config,
    );
  }
}
```

One line. Full Navigator 2.0. Deep links. Browser back button. URL bar sync. Done.

---

## Runes — Dynamic Parameters

The `:id` in `/quest/:id` is a dynamic segment. Atlas calls these **Runes** — ancient symbols carrying meaning:

```dart
Passage('/quest/:id', (waypoint) {
  // Raw string parameter
  final id = waypoint.runes['id']!;

  // Type-safe helpers
  final numericId = waypoint.intRune('id');   // int?
  final page = waypoint.intQuery('page');     // int? from ?page=3

  return QuestDetailScreen(questId: id);
}),
```

Waypoint provides type-safe helpers: `intRune()`, `intQuery()` — no manual parsing needed.

---

## Navigation — The Strike of Movement

```dart
// Navigate forward
Atlas.to('/quest/42');

// Navigate with extra data (not in URL)
Atlas.to('/quest/42', extra: quest);

// Go back
Atlas.back();

// Replace current route (no back entry)
Atlas.replace('/quest/42');

// Reset the entire navigation stack
Atlas.reset('/');

// Named navigation
Atlas.toNamed('quest-detail', runes: {'id': '42'});

// Check if we can go back
if (Atlas.canBack) Atlas.back();

// Get current waypoint
final current = Atlas.current;
print(current.path);   // '/quest/42'
```

Or use context extensions:

```dart
// Inside any widget
context.atlas.to('/heroes');
context.atlas.back();
context.atlas.replace('/settings');
```

---

## Sentinels — Guards at the Gate

The admin panel needed protection. Only authenticated users should pass. In Atlas, route guards are called **Sentinels**:

```dart
final atlas = Atlas(
  passages: [
    Passage('/', (wp) => const QuestboardScreen()),
    Passage('/admin', (wp) => const AdminScreen()),
    Passage('/login', (wp) => const LoginScreen()),
  ],
  sentinels: [
    // Guard the admin route — redirect to login if not authenticated
    Sentinel.only(
      paths: {'/admin'},
      guard: (path, waypoint) {
        final auth = Titan.get<AuthPillar>();
        if (auth.user.value == null) {
          return '/login'; // Redirect to login
        }
        return null; // Allow passage
      },
    ),
  ],
);
```

A Sentinel returns `null` to allow passage, or a redirect path to reroute the traveler. `Sentinel.only()` applies to specific paths. `Sentinel.except()` guards everything *except* certain paths:

```dart
// Guard everything except public routes
Sentinel.except(
  paths: {'/', '/login', '/register'},
  guard: (path, waypoint) {
    return isAuthenticated ? null : '/login';
  },
),
```

For async guards (checking a token with a server):

```dart
Sentinel.async((path, waypoint) async {
  final isValid = await authService.validateToken();
  return isValid ? null : '/login';
}),
```

---

## Sanctum — Persistent Shells

Most apps have persistent layouts — a bottom navigation bar, a sidebar, a top app bar that stays while inner content changes. In Atlas, these are **Sanctums** — inner chambers that wrap their passages:

```dart
final atlas = Atlas(
  passages: [
    Passage('/login', (wp) => const LoginScreen()),

    // Sanctum wraps inner passages in a persistent shell
    Sanctum(
      shell: (child) => MainShell(child: child),
      passages: [
        Passage('/', (wp) => const QuestboardScreen()),
        Passage('/heroes', (wp) => const LeaderboardScreen()),
        Passage('/settings', (wp) => const SettingsScreen()),
      ],
    ),

    // Routes outside the Sanctum don't have the shell
    Passage('/quest/:id', (wp) => QuestDetailScreen(questId: wp.runes['id']!)),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child, // The current route's content
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexFor(Atlas.current.path),
        onTap: (i) => Atlas.to(_pathFor(i)),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Quests'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Heroes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

Navigate from `/` to `/heroes`? The `MainShell` stays mounted — no rebuild, no animation jank. Only the inner `child` swaps. Navigate to `/quest/42`? The shell disappears because that route is outside the Sanctum.

---

## Shift — Transition Animations

Each Passage can have a custom **Shift** — a transition animation:

```dart
final atlas = Atlas(
  passages: [
    Passage('/', (wp) => const HomeScreen(),
      shift: Shift.fade(),
    ),
    Passage('/quest/:id', (wp) => QuestDetailScreen(questId: wp.runes['id']!),
      shift: Shift.slideUp(duration: Duration(milliseconds: 400)),
    ),
    Passage('/settings', (wp) => const SettingsScreen(),
      shift: Shift.slide(),
    ),
  ],
  defaultShift: Shift.fade(), // Fallback for routes without a specific Shift
);
```

Built-in Shifts: `fade`, `slide`, `slideUp`, `scale`, `none`. Need something custom?

```dart
Shift.custom(
  builder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0).animate(animation),
        child: child,
      ),
    );
  },
)
```

---

## Drift — Global Redirects

Before any Sentinel evaluates, Atlas checks the **Drift** — a global redirect function:

```dart
final atlas = Atlas(
  passages: [...],
  drift: (path, waypoint) {
    // Maintenance mode — redirect everyone to a notice page
    if (isMaintenanceMode) return '/maintenance';

    // Old URLs redirect to new ones
    if (path == '/old-dashboard') return '/';

    return null; // No redirect
  },
);
```

Drift runs first, then Sentinels. If Drift redirects, Sentinels are skipped entirely.

---

## Route-Scoped Pillars

This is where Atlas and Titan truly merge. Passages can declare **Pillars** that are created when the route is entered and disposed when it's left:

```dart
Passage('/quest/:id', (wp) {
  return Vestige<QuestDetailPillar>(
    builder: (context, pillar) => QuestDetailScreen(pillar: pillar),
  );
},
  pillars: [
    () => QuestDetailPillar(questId: Atlas.current.runes['id']!),
  ],
),
```

The `QuestDetailPillar` lives only while the user is on that route. Navigate away? Disposed. Navigate back? A fresh instance is created. Zero leaks, zero stale state.

Sanctums can also host Pillars that live for the duration of the shell:

```dart
Sanctum(
  shell: (child) => MainShell(child: child),
  pillars: [DashboardPillar.new], // Lives while any route in this Sanctum is active
  passages: [...],
),
```

---

## Herald Meets Atlas

Remember the Herald from Chapter IV? Atlas can emit Herald events on every navigation action with the **HeraldAtlasObserver**:

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  passages: [...],
  observers: [HeraldAtlasObserver()],
);

// Now any Pillar can listen for navigation events
class AnalyticsPillar extends Pillar {
  @override
  void onInit() {
    listen<AtlasRouteChanged>((event) {
      analytics.trackScreen(event.toPath);
      log.info('Navigation: ${event.fromPath} → ${event.toPath}');
    });

    listen<AtlasGuardRedirect>((event) {
      log.warning('Guard redirected: ${event.from} → ${event.to}');
    });

    listen<AtlasRouteNotFound>((event) {
      log.error('Route not found: ${event.path}');
    });
  }
}
```

Navigation events flow through the same Herald system as all other cross-domain events. No special wiring. No separate analytics layer. One event bus, one pattern, everywhere.

---

## The Complete Questboard Router

```dart
final atlas = Atlas(
  passages: [
    Passage('/login', (wp) => const LoginScreen(),
      shift: Shift.fade(),
    ),

    Sanctum(
      shell: (child) => MainShell(child: child),
      pillars: [LeaderboardPillar.new],
      passages: [
        Passage('/', (wp) => const QuestboardScreen(), name: 'home'),
        Passage('/heroes', (wp) => const LeaderboardScreen(), name: 'heroes'),
        Passage('/settings', (wp) => const SettingsScreen(), name: 'settings'),
      ],
    ),

    Passage('/quest/:id', (wp) => QuestDetailScreen(questId: wp.runes['id']!),
      shift: Shift.slideUp(),
      pillars: [
        () => QuestDetailPillar(questId: Atlas.current.runes['id']!),
      ],
    ),

    Passage('/hero/:id', (wp) => HeroProfileScreen(heroId: wp.runes['id']!),
      shift: Shift.slide(),
    ),

    Passage('/admin', (wp) => const AdminScreen()),
  ],

  sentinels: [
    Sentinel.except(
      paths: {'/', '/login', '/heroes'},
      guard: (path, wp) {
        final auth = Titan.get<AuthPillar>();
        return auth.user.value == null ? '/login' : null;
      },
    ),
  ],

  observers: [HeraldAtlasObserver()],

  drift: (path, wp) {
    if (path == '/old-board') return '/';
    return null;
  },

  onError: (path) => NotFoundScreen(path: path),
  defaultShift: Shift.fade(),
);
```

Declarative. Type-safe. Deep-linkable. Guarded. Animated. Integrated with Titan's state and event systems.

---

> *Atlas mapped every path in the kingdom. Sentinels guarded the gates. Sanctums held persistent courts. But there was one final challenge — the kingdom needed to survive the night. When the app closed and reopened, all state vanished. Quests, settings, preferences — gone. The kingdom needed Relics: artifacts that could endure across the ages.*

---

**Next:** [Chapter VIII — The Relic Endures →](chapter-08-the-relic-endures.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| **VII** | **The Atlas Unfurls** ← You are here |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
