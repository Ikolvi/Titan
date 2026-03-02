# Chapter IX: The Scroll Inscribes

*In which Kael discovers that even the mightiest heroes need forms, and learns to validate the words of those who seek to join the quest.*

---

The morning standup was barely over when the PM dropped a bomb.

"We need a hero registration form," she said, as casually as someone ordering coffee. "Name, email, class, bio. Full validation. And Kael — it has to feel *right*. No submitting until everything's valid. Show errors only after they interact with a field."

Kael leaned back. Forms. The bane of every developer's existence. In previous projects, form state had been a tangled mess of `TextEditingController`s, `GlobalKey<FormState>`s, manual rebuilds, and validation callbacks that fired at the wrong time.

But this was Titan. There had to be a better way.

---

## The Ancient Scrolls

Kael opened the docs and found **Scroll** — Titan's form field primitive.

> *A Scroll is a Core with form powers: validation, dirty tracking, touch state, and reset. It IS a Core, so it works everywhere Cores work.*

The key insight hit immediately: a form field is just reactive state with extra metadata. No separate "form framework" needed.

```dart
class HeroRegistrationPillar extends Pillar {
  late final name = scroll<String>(
    '',
    validator: (v) => v.length < 2 ? 'Name too short' : null,
    name: 'name',
  );

  late final email = scroll<String>(
    '',
    validator: (v) => v.contains('@') ? null : 'Invalid email address',
    name: 'email',
  );

  late final heroClass = scroll<String>(
    '',
    validator: (v) => v.isEmpty ? 'Choose a class' : null,
    name: 'heroClass',
  );

  late final bio = scroll<String>(
    '',
    validator: (v) => v.length > 500 ? 'Bio cannot exceed 500 characters' : null,
    name: 'bio',
  );
}
```

Kael stared. That was... shockingly clean. Each `scroll()` created a field that:
- **Is** a Core — reads auto-track in Vestige/Derived
- Tracks whether the user changed it (`isDirty`)
- Tracks whether the user interacted with it (`isTouched`)
- Validates on demand with a pure function
- Can reset to its initial value

---

## Inscribing the Form

The UI came together naturally. Since Scrolls are Cores, Vestige's auto-tracking just worked:

```dart
Vestige<HeroRegistrationPillar>(
  builder: (context, form) => Column(
    children: [
      TextField(
        onChanged: (v) => form.name.value = v,
        onEditingComplete: () => form.name.touch(),
        decoration: InputDecoration(
          labelText: 'Hero Name',
          errorText: form.name.isTouched ? form.name.error : null,
        ),
      ),
      TextField(
        onChanged: (v) => form.email.value = v,
        onEditingComplete: () => form.email.touch(),
        decoration: InputDecoration(
          labelText: 'Email',
          errorText: form.email.isTouched ? form.email.error : null,
        ),
      ),
      // ... heroClass and bio fields
    ],
  ),
)
```

The pattern was elegant: show errors only when `isTouched` is true. The field is touched when the user blurs it or when they attempt to submit.

---

## The ScrollGroup

But the real magic came when Kael needed a submit button that was disabled until the entire form was valid:

```dart
class HeroRegistrationPillar extends Pillar {
  // ... fields from above

  late final form = ScrollGroup([name, email, heroClass, bio]);

  late final canSubmit = derived(() => form.isValid && form.isDirty);

  void submit() {
    form.touchAll(); // Show all errors
    if (!form.validateAll()) return;

    strike(() {
      // Process the registration
      emit(HeroRegistered(
        name: name.value,
        email: email.value,
        heroClass: heroClass.value,
        bio: bio.value,
      ));
    });
  }

  void resetForm() => form.resetAll();
}
```

`ScrollGroup` aggregated the state of all fields:
- `form.isValid` — true only when ALL fields pass validation
- `form.isDirty` — true when ANY field has been changed
- `form.isTouched` — true when ANY field has been interacted with
- `form.validateAll()` — validates every field, returns `true` if all pass
- `form.touchAll()` — marks all fields as touched (to reveal all errors on submit)
- `form.resetAll()` — resets every field to its initial value

---

## Validation in Action

Kael wrote a test (of course — in Titan, Pillars are testable as plain Dart):

```dart
void main() {
  test('form validates correctly', () {
    final pillar = HeroRegistrationPillar();
    pillar.initialize();

    // Initially invalid
    expect(pillar.form.validateAll(), false);
    expect(pillar.name.error, 'Name too short');
    expect(pillar.email.error, 'Invalid email address');

    // Fill in valid data
    pillar.name.value = 'Kael';
    pillar.email.value = 'kael@ironclad.io';
    pillar.heroClass.value = 'Architect';
    pillar.bio.value = 'Builder of reactive fortresses';

    expect(pillar.form.validateAll(), true);
    expect(pillar.canSubmit.value, true);

    // Reset
    pillar.resetForm();
    expect(pillar.name.value, '');
    expect(pillar.form.isDirty, false);

    pillar.dispose();
  });
}
```

No mocking frameworks. No widget test ceremony. Just plain Dart assertions on reactive form state.

---

## How It Works

Under the hood, `Scroll<T>` extends `TitanState<T>` — making it a full-fledged Core:

| Property | Type | Description |
|----------|------|-------------|
| `.value` | `T` | The current value (read/write, reactive) |
| `.error` | `String?` | Current validation error |
| `.isDirty` | `bool` | Value differs from initial |
| `.isPristine` | `bool` | Value unchanged from initial |
| `.isTouched` | `bool` | User has interacted with field |
| `.isValid` | `bool` | No validation error |

| Method | Description |
|--------|-------------|
| `validate()` | Run validator, return `true` if valid |
| `touch()` | Mark field as interacted |
| `reset()` | Restore initial value, clear error/touched |
| `setError(String)` | Set a manual error (e.g., server-side) |
| `clearError()` | Remove the current error |

Because Scroll IS a Core, it works with:
- **Vestige** auto-tracking (reads of `.value`, `.error`, `.isTouched` auto-register)
- **Derived** computations (`derived(() => form.isValid)`)
- **Epoch** history (if you need undo/redo on form fields)
- **Watcher** side effects

---

## The Result

The registration form was live by lunch. Kael leaned back, satisfied. No `FormState`, no `GlobalKey`, no `TextEditingController` lifecycle management. Just reactive state with validation built in.

The PM approved the form on first review. "Clean," she said. High praise.

But then came a new requirement: "We need to show a paginated list of available quests that heroes can sign up for..."

Kael smiled. He was about to open the Codex.

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
| **IX** | **The Scroll Inscribes** ← You are here |
| [X](chapter-10-the-codex-opens.md) | The Codex Opens |
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
