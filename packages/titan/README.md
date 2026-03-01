# Titan

**Total Integrated Transfer Architecture Network**

A signal-based reactive state management engine for Dart & Flutter — fine-grained reactivity, zero boilerplate, surgical rebuilds.

[![pub package](https://img.shields.io/pub/v/titan.svg)](https://pub.dev/packages/titan)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.10-blue)](https://dart.dev)

---

## The Titan Lexicon

| Standard Term | Titan Name | Description |
|---------------|------------|-------------|
| Store / Bloc | **Pillar** | Structured state module with lifecycle |
| State | **Core** | Reactive mutable state |
| Computed | **Derived** | Auto-computed from Cores, cached, lazy |
| Dispatch / Add | **Strike** | Batched, tracked mutations |
| Side Effect | **Watch** | Reactive side effect — re-runs on change |
| Global DI | **Titan** | Global Pillar registry |
| Observer | **Oracle** | All-seeing state monitor |
| Middleware | **Aegis** | State change interceptor |
| DI Container | **Vault** | Hierarchical dependency container |
| Module | **Forge** | Dependency assembly unit |
| Config | **Edict** | Global Titan configuration |
| Async Data | **Ether** | Loading / error / data wrapper |

---

## Quick Start

```bash
flutter pub add titan
```

Or see the latest version on [pub.dev](https://pub.dev/packages/titan/install).

### Define a Pillar

```dart
import 'package:titan/titan.dart';

class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);
  late final isEven = derived(() => count.value % 2 == 0);

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);
}
```

### Use It (Pure Dart)

```dart
final counter = CounterPillar();

print(counter.count.value);    // 0
print(counter.doubled.value);  // 0

counter.increment();
print(counter.count.value);    // 1
print(counter.doubled.value);  // 2
print(counter.isEven.value);   // false

counter.dispose();
```

### Standalone Signals

```dart
final count = Core(0);
final doubled = Derived(() => count.value * 2);

count.value = 5;
print(doubled.value); // 10
```

---

## Key Features

### Fine-Grained Reactivity

Each `Core` is an independent reactive node. Reading `.value` inside a `Derived` auto-registers the dependency. Only dependents of changed Cores recompute — nothing else.

### Strike — Batched Mutations

```dart
strike(() {
  name.value = 'Alice';
  age.value = 30;
  role.value = 'Admin';
});
// Dependents recompute ONCE, not three times
```

### Watch — Reactive Side Effects

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final isLoggedIn = derived(() => user.value != null);

  @override
  void onInit() {
    watch(() {
      if (isLoggedIn.value) {
        analytics.track('logged_in');
      }
    });
  }
}
```

### Lifecycle

```dart
class DataPillar extends Pillar {
  @override
  void onInit() {
    // Called once after construction
  }

  @override
  void onDispose() {
    // Called on dispose — cleanup resources
  }
}
```

### Global DI

```dart
Titan.put(AuthPillar());
final auth = Titan.get<AuthPillar>();
Titan.remove<AuthPillar>();
Titan.reset(); // Remove all
```

### AsyncValue (Ether)

```dart
late final users = core(AsyncValue<List<User>>.loading());

Future<void> loadUsers() async {
  users.value = AsyncValue.loading();
  try {
    final data = await api.fetchUsers();
    users.value = AsyncValue.data(data);
  } catch (e) {
    users.value = AsyncValue.error(e);
  }
}

// Pattern match
users.value.when(
  data: (list) => print('Got ${list.length} users'),
  loading: () => print('Loading...'),
  error: (e) => print('Error: $e'),
);
```

### Oracle — Global Observer

```dart
class LoggingOracle extends TitanObserver {
  @override
  void onStateChange(String name, dynamic prev, dynamic next) {
    print('$name: $prev → $next');
  }
}

TitanConfig.observer = LoggingOracle();
```

### Aegis — Middleware

```dart
class ValidationAegis extends TitanMiddleware {
  @override
  bool beforeChange(String name, dynamic prev, dynamic next) {
    if (name == 'age' && next < 0) return false; // Block
    return true;
  }
}
```

---

## Why Titan?

| Feature | Provider | Bloc | Riverpod | GetX | **Titan** |
|---------|----------|------|----------|------|-----------|
| Fine-grained reactivity | ❌ | ❌ | ⚠️ | ⚠️ | ✅ |
| Zero boilerplate | ✅ | ❌ | ⚠️ | ✅ | ✅ |
| Auto-tracking rebuilds | ❌ | ❌ | ❌ | ❌ | ✅ |
| Structured scalability | ⚠️ | ✅ | ✅ | ❌ | ✅ |
| Lifecycle management | ❌ | ✅ | ✅ | ⚠️ | ✅ |
| Scoped + Global DI | ❌ | ⚠️ | ✅ | ❌ | ✅ |
| Pure Dart core | ❌ | ✅ | ✅ | ❌ | ✅ |

---

## Testing — Pure Dart

```dart
test('counter pillar works', () {
  final counter = CounterPillar();
  expect(counter.count.value, 0);

  counter.increment();
  expect(counter.count.value, 1);
  expect(counter.doubled.value, 2);

  counter.dispose();
});
```

---

## Packages

| Package | Description |
|---------|-------------|
| **`titan`** | Core reactive engine — pure Dart (this package) |
| [`titan_bastion`](https://pub.dev/packages/titan_bastion) | Flutter widgets (Vestige, Beacon) |
| [`titan_atlas`](https://pub.dev/packages/titan_atlas) | Routing & navigation (Atlas) |

## Documentation

| Guide | Link |
|-------|------|
| Introduction | [01-introduction.md](https://github.com/Ikolvi/titan/blob/main/docs/01-introduction.md) |
| Getting Started | [02-getting-started.md](https://github.com/Ikolvi/titan/blob/main/docs/02-getting-started.md) |
| Core Concepts | [03-core-concepts.md](https://github.com/Ikolvi/titan/blob/main/docs/03-core-concepts.md) |
| Pillars | [04-stores.md](https://github.com/Ikolvi/titan/blob/main/docs/04-stores.md) |
| Flutter Integration | [05-flutter-integration.md](https://github.com/Ikolvi/titan/blob/main/docs/05-flutter-integration.md) |
| Middleware | [06-middleware.md](https://github.com/Ikolvi/titan/blob/main/docs/06-middleware.md) |
| Testing | [07-testing.md](https://github.com/Ikolvi/titan/blob/main/docs/07-testing.md) |
| Advanced Patterns | [08-advanced-patterns.md](https://github.com/Ikolvi/titan/blob/main/docs/08-advanced-patterns.md) |
| API Reference | [09-api-reference.md](https://github.com/Ikolvi/titan/blob/main/docs/09-api-reference.md) |
| Migration Guide | [10-migration-guide.md](https://github.com/Ikolvi/titan/blob/main/docs/10-migration-guide.md) |
| Architecture | [11-architecture.md](https://github.com/Ikolvi/titan/blob/main/docs/11-architecture.md) |
| Atlas Routing | [12-atlas-routing.md](https://github.com/Ikolvi/titan/blob/main/docs/12-atlas-routing.md) |

## License

MIT — [Ikolvi](https://ikolvi.com)
