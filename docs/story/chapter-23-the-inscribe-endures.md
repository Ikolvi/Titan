# Chapter XXIII: The Inscribe Endures

*In which Kael learns that a verdict unwritten is a verdict forgotten — and discovers the art of making performance visible to all.*

---

The Colossus was watching. The Tremors were firing. The Decree was rendering its verdict.

But Kael had a problem.

"I *know* the app is getting faster," he told his lead, standing in the morning standup. "The jank rate dropped from twelve percent to three. Page loads are under two hundred milliseconds. We fixed two leak suspects."

"Show me."

Kael opened his mouth. Closed it. He had the numbers in his head. He'd seen them in the Lens overlay, teal text on a dark background, metrics flickering in real-time. But he hadn't captured them. Hadn't saved them. Hadn't written them down.

The Decree existed only in memory. And memory, as any Vessel would tell you, is the first thing to leak.

"I need to inscribe the Decree," Kael muttered.

---

## The Inscribe

> *The Titans inscribed their decrees onto stone and parchment for posterity. Your Inscribe writes the Colossus's verdict into a permanent, shareable format.*

Inscribe converts a Decree into three exportable formats: Markdown for documentation, JSON for data pipelines, and HTML for visual dashboards.

```dart
final decree = Colossus.instance.decree();

// Markdown — clean tables, perfect for GitHub issues and PRs
final md = Inscribe.markdown(decree);

// JSON — structured data for CI pipelines and dashboards
final json = Inscribe.json(decree);

// HTML — a self-contained visual dashboard
final html = Inscribe.html(decree);
```

Kael stared at the three lines. Each one took the same Decree — the same verdict from the same Colossus — and rendered it for a different audience.

---

## The Markdown Decree

The first format Kael tried was Markdown. He wanted something he could paste into a pull request.

```dart
final md = Inscribe.markdown(Colossus.instance.decree());
print(md);
```

The output was clean and structured:

```markdown
# Colossus Performance Decree

**Health: GOOD** ✅

| | |
|---|---|
| **Session start** | 2025-01-15 10:00:00 |
| **Report generated** | 2025-01-15 10:47:30 |
| **Duration** | 2850s |

## Pulse (Frame Metrics)

| Metric | Value |
|--------|-------|
| FPS | 59.2 |
| Total frames | 12,847 |
| Jank frames | 38 |
| Jank rate | 0.3% |

## Stride (Page Loads)

| Path | Pattern | Duration |
|------|---------|----------|
| /quests | /quests | 82ms |
| /quests/42 | /quests/:id | 187ms |
| /profile | /profile | 67ms |
```

"That's a PR description," Kael said. "Before and after performance metrics, right in the code review."

He pasted it into his branch's description. The diff showed code changes. The Decree showed their impact. The reviewers could see both.

---

## The JSON Pipeline

The next morning, the DevOps engineer stopped by Kael's desk.

"Can I get those perf numbers in a machine-readable format? I want to track them in our CI dashboard."

JSON.

```dart
final json = Inscribe.json(decree);
```

```json
{
  "health": "good",
  "durationSeconds": 2850,
  "pulse": {
    "totalFrames": 12847,
    "jankFrames": 38,
    "jankRate": 0.3,
    "avgFps": 59.2,
    "avgBuildTimeUs": 3200,
    "avgRasterTimeUs": 2100
  },
  "stride": {
    "totalPageLoads": 47,
    "avgPageLoadMs": 145,
    "pageLoads": [...]
  },
  "vessel": {
    "pillarCount": 8,
    "totalInstances": 15,
    "leakSuspects": []
  },
  "echo": {
    "totalRebuilds": 342,
    "topRebuilders": {
      "QuestCard": 89,
      "HeroAvatar": 45
    }
  }
}
```

The JSON came from `Decree.toMap()` — every data class in the Colossus hierarchy serialized cleanly:

```dart
// Every Mark, FrameMark, PageLoadMark, MemoryMark, LeakSuspect
// has a toMap() method for structured serialization
final decree = Colossus.instance.decree();
final map = decree.toMap();  // Map<String, dynamic>
```

The DevOps engineer connected it to their Grafana dashboard within the hour.

---

## The HTML Dashboard

"Can we get something visual for the sprint review?" the product manager asked. "The executives don't read JSON."

HTML. A self-contained dashboard with embedded CSS, dark theme, color-coded metrics. No external dependencies — just a single file that opens in any browser.

```dart
final html = Inscribe.html(decree);
```

Kael saved it and opened the file. A dark dashboard appeared:

- A **health badge** at the top — green for GOOD, yellow for FAIR, red for POOR
- **Pulse card** with FPS, jank rate, and a visual jank bar
- **Stride card** with page load timings, color-coded by speed
- **Vessel card** with memory counts and red-highlighted leak suspects
- **Echo card** with a ranked rebuild table

"That's the sprint review slide," the PM said, leaning over his shoulder.

---

## Convenience on the Colossus

Kael found himself calling `decree()` then `Inscribe.` so often that he checked for a shorthand. There was one:

```dart
// These generate a decree and format it in one step
final md   = Colossus.instance.inscribeMarkdown();
final json = Colossus.instance.inscribeJson();
final html = Colossus.instance.inscribeHtml();
```

Clean. The Colossus could inscribe its own decree.

---

## Saving to Disk

Copying strings was fine for quick shares. But Kael wanted persistent files — artifacts he could attach to CI runs, archive in his project, or email to the team.

```dart
// Save a single format
final path = await InscribeIO.saveHtml(
  decree,
  directory: '/tmp/perf-reports',
);
print('Saved to $path');
// → /tmp/perf-reports/colossus-decree-20250115-104730.html
```

The filename was auto-generated with a timestamp. The directory was created if it didn't exist.

For saving all three formats at once:

```dart
final result = await InscribeIO.saveAll(
  decree,
  directory: '/reports',
);

print(result.markdown); // /reports/colossus-decree-20250115-104730.md
print(result.json);     // /reports/colossus-decree-20250115-104730.json
print(result.html);     // /reports/colossus-decree-20250115-104730.html

// All paths as a list
print(result.all);
```

The `SaveResult` gave him all three paths. The timestamp was identical across all three files — one session, three views.

---

## The Export Tab

But the best discovery came from the Lens overlay itself.

Kael tapped the "Perf" tab and noticed a fifth sub-tab he hadn't seen before: **Export**.

Three clipboard buttons: **Markdown**, **JSON**, **Summary**.

Two save buttons: **Save HTML**, **Save All**.

He tapped "JSON". The status line glowed teal: *JSON copied to clipboard*.

He tapped "Save All". Three paths appeared:

```
/tmp/colossus-decree-20250115-104730.md
/tmp/colossus-decree-20250115-104730.json
/tmp/colossus-decree-20250115-104730.html
```

No terminal. No code changes. Just a tap in the debug overlay.

"That's how you share performance data," Kael said. "You inscribe it."

---

## The CI Integration

The real power of Inscribe came in the CI pipeline. Kael added a performance gate to their GitHub Actions:

```dart
// integration_test/perf_gate.dart
void main() {
  testWidgets('performance gate', (tester) async {
    Colossus.init();
    
    // ... run through critical user flows ...
    
    final decree = Colossus.instance.decree();
    
    // Save report as CI artifact
    await InscribeIO.saveAll(
      decree,
      directory: 'build/perf-reports',
    );
    
    // Assert performance thresholds
    expect(decree.health, isNot(PerformanceHealth.poor));
    expect(decree.jankRate, lessThan(10));
    expect(decree.avgPageLoad.inMilliseconds, lessThan(500));
    
    Colossus.shutdown();
  });
}
```

The JSON output fed into their dashboard. The HTML report was uploaded as a build artifact. The Markdown summary was posted as a PR comment.

Three formats. Three audiences. One decree.

---

## What Kael Learned

Kael leaned back and thought about what Inscribe had taught him:

1. **Inscribe.markdown()** is for humans who read — PR descriptions, tickets, docs
2. **Inscribe.json()** is for machines that parse — CI pipelines, dashboards, data lakes
3. **Inscribe.html()** is for stakeholders who see — sprint reviews, executive summaries
4. **InscribeIO** saves to disk — CI artifacts, local archives, shareable files
5. **The Export tab** makes it all accessible without code — tap, copy, done

"A monitoring system that can't export its findings," Kael said, "is a monitoring system that talks to itself."

The Colossus watches. The Decree judges. And now the Inscribe ensures the verdict endures.

---

*Next: [Chapter XXIV: The Shade Follows](chapter-24-the-shade-follows.md)*

---

## API Quick Reference

| Class | Purpose |
|-------|---------|
| `Inscribe` | Format a Decree — `markdown()`, `json()`, `html()` |
| `InscribeIO` | Save to disk — `saveMarkdown()`, `saveJson()`, `saveHtml()`, `saveAll()` |
| `SaveResult` | Paths from `saveAll()` — `.markdown`, `.json`, `.html`, `.all` |
| `Decree.toMap()` | JSON-serializable map of all metrics |
| `Mark.toMap()` | Serialize any metric data point |
| `Colossus.inscribeMarkdown()` | Convenience — decree + format in one call |
| `Colossus.inscribeJson()` | Convenience — decree + format in one call |
| `Colossus.inscribeHtml()` | Convenience — decree + format in one call |
