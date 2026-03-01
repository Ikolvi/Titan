# Atlas

**Titan's routing & navigation system** — declarative, zero-boilerplate, high-performance page management for Flutter.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.10-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%5E3.38-blue)](https://flutter.dev)

Part of the [Titan](https://github.com/Ikolvi/titan) ecosystem.

---

## The Atlas Lexicon

| Concept | Titan Name | Purpose |
|---------|------------|---------|
| Router | **Atlas** | Maps all paths, bears the world |
| Route | **Passage** | A way through to a destination |
| Shell Route | **Sanctum** | Inner chamber — persistent layout |
| Route Guard | **Sentinel** | Protects passage |
| Redirect | **Drift** | Navigation shifts course |
| Parameters | **Runes** | Ancient symbols carrying meaning |
| Transition | **Shift** | Change of form/phase |
| Route State | **Waypoint** | Current position in the journey |

---

## Quick Start

```yaml
dependencies:
  titan_atlas: ^0.0.1
```

```dart
import 'package:titan_atlas/titan_atlas.dart';

final atlas = Atlas(
  passages: [
    Passage('/', (_) => const HomeScreen()),
    Passage('/profile/:id', (wp) => ProfileScreen(id: wp.runes['id']!)),
  ],
);

void main() => runApp(
  MaterialApp.router(routerConfig: atlas.config),
);
```

**That's it. No code generation. No boilerplate.**

---

## Features

### Passages — Route Definitions

```dart
// Static
Passage('/home', (_) => HomeScreen())

// Dynamic (Runes)
Passage('/user/:id', (wp) => UserScreen(id: wp.runes['id']!))

// Wildcard
Passage('/files/*', (wp) => FileViewer(path: wp.remaining!))

// Named
Passage('/settings', (_) => SettingsScreen(), name: 'settings')

// With transition
Passage('/modal', (_) => ModalScreen(), shift: Shift.slideUp())
```

### Navigation

```dart
// Static API
Atlas.to('/profile/42');
Atlas.to('/search?q=dart');
Atlas.to('/detail', extra: myData);
Atlas.toNamed('profile', runes: {'id': '42'});
Atlas.replace('/home');
Atlas.back();
Atlas.backTo('/home');
Atlas.reset('/login');

// Context extension
context.atlas.to('/profile/42');
context.atlas.back();
```

### Sanctum — Shell Routes

```dart
Sanctum(
  shell: (child) => Scaffold(
    body: child,
    bottomNavigationBar: const AppNavBar(),
  ),
  passages: [
    Passage('/home', (_) => HomeScreen()),
    Passage('/search', (_) => SearchScreen()),
  ],
)
```

### Sentinel — Route Guards

```dart
// Guard all routes
Sentinel((path, _) => isLoggedIn ? null : '/login')

// Guard specific paths
Sentinel.only(paths: {'/admin'}, guard: (_, __) => '/login')

// Exclude public paths
Sentinel.except(paths: {'/login', '/'}, guard: (_, __) => '/login')

// Async guard
Sentinel.async((path, _) async {
  final ok = await checkPermission(path);
  return ok ? null : '/403';
})
```

### Shift — Transitions

```dart
Shift.fade()      // Fade in/out
Shift.slide()     // Slide from right
Shift.slideUp()   // Slide from bottom
Shift.scale()     // Scale + fade
Shift.none()      // Instant
Shift.custom(builder: ...)  // Your own
```

### Drift — Redirects

```dart
Atlas(
  drift: (path, _) {
    if (path == '/old') return '/new';
    return null;
  },
  passages: [...],
)
```

---

## Performance

Atlas uses a **trie-based route matcher** for O(k) path resolution where k is the number of path segments — matching time is independent of total route count.

---

## Works with Titan State

```dart
void main() {
  final atlas = Atlas(passages: [...]);
  
  runApp(
    Beacon(
      pillars: [AuthPillar.new],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

---

## Packages

| Package | Description |
|---------|-------------|
| [`titan`](https://pub.dev/packages/titan) | Core reactive engine |
| [`titan_bastion`](https://pub.dev/packages/titan_bastion) | Flutter widgets (Vestige, Beacon) |
| **`titan_atlas`** | Routing & navigation (this package) |

## License

MIT — [Ikolvi](https://ikolvi.com)
