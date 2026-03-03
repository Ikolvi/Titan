# Chapter XLVIII — The Sluice Channels

*In which the data flows through gates of transformation*

---

The workshop hummed with the sound of water. Not the chaotic rush of a broken dam, but the measured, deliberate flow of channels cut through stone — each gate opening in sequence, each passage narrowing or widening to shape what passed through.

"We have built Pillars that hold state," Kael observed, studying the network of channels carved into the workshop floor. "We have Heralds that carry messages, and Tithes that measure consumption. But when data must pass through many hands — validated, enriched, transformed, filtered — each hand working at its own pace, with its own rules of failure and retry..."

The Elder Architect nodded slowly. "You speak of the pipeline problem. A single function can transform one item. But an enterprise must transform thousands — through multiple stages, each with its own concerns, its own failure modes, its own capacity."

"And we must see it happening," Kael added. "Not just the final result, but every gate along the way. How many items passed through? How many were turned away? How many stumbled and were caught?"

The Elder smiled. "Then you are ready for the Sluice."

---

## The Gate Opens

The Sluice was not a single mechanism but a series of gates — each one a **stage** that could process, transform, or filter what flowed through:

```dart
class OrderPillar extends Pillar {
  late final pipeline = sluice<Order>(
    stages: [
      SluiceStage(name: 'validate', process: (order) {
        if (order.total <= 0) return null;  // Filter out invalid
        return order.copyWith(validated: true);
      }),
      SluiceStage(
        name: 'charge',
        process: (order) async => await paymentService.charge(order),
        maxRetries: 2,
        timeout: Duration(seconds: 10),
      ),
      SluiceStage(name: 'fulfill', process: (order) async {
        await warehouse.ship(order);
        return order.copyWith(shipped: true);
      }),
    ],
    onComplete: (order) => log.info('Order ${order.id} fulfilled'),
    onError: (order, error, stage) =>
        log.error('Order ${order.id} failed at $stage: $error'),
  );
}
```

"Each stage has a name," the Elder explained. "Not merely for identification, but for accountability. Every gate knows how many items it processed, how many it filtered, how many it caught in error."

## The Flow Observes Itself

What made the Sluice remarkable was not merely its processing — it was its **self-awareness**. Every aspect of the pipeline was reactive:

```dart
// The pipeline knows its own state
pipeline.fed.value        // Items that entered
pipeline.completed.value  // Items that exited successfully
pipeline.failed.value     // Items that fell permanently
pipeline.inFlight.value   // Items still inside
pipeline.errorRate.value  // The ratio of failure

// Each gate knows its own truth
pipeline.stage('charge').processed.value  // Successful charges
pipeline.stage('charge').errors.value     // Failed charges
pipeline.stage('charge').filtered.value   // Filtered out
```

"The Sluice does not merely process," Kael realized. "It *observes* its own processing. Every gate reports its metrics through reactive signals — visible anywhere a Vestige watches."

## The Gates of Overflow

The Elder raised a hand. "But what happens when the river runs too fast? When items arrive faster than the gates can process them?"

The Sluice offered three strategies:

```dart
// Backpressure: refuse new items when full
sluice<Data>(stages: [...], overflow: SluiceOverflow.backpressure);
// feed() returns false — caller decides what to do

// Drop oldest: sacrifice the oldest waiting item
sluice<Data>(stages: [...], overflow: SluiceOverflow.dropOldest);
// Makes room by discarding what waited longest

// Drop newest: refuse the incoming item
sluice<Data>(stages: [...], overflow: SluiceOverflow.dropNewest);
// The newest item is sacrificed to protect the queue
```

"Each strategy serves a different philosophy," the Elder explained. "Backpressure respects all items equally. Dropping oldest prioritizes freshness. Dropping newest protects those already waiting."

---

## The Current Pauses

Kael noticed one final mechanism — a great lever beside the channel:

```dart
pipeline.pause();   // The water stops, but nothing is lost
// ... maintenance, inspection, reconfiguration ...
pipeline.resume();  // The flow continues from where it paused

await pipeline.flush();  // Wait until every last drop passes through
```

"Sometimes," the Elder said quietly, "the wisest act is to stop the flow — not to destroy what waits, but to hold it until the channel is ready again."

---

*The Sluice channels now, each gate a stage of transformation. Data flows through ordered passages — validated, enriched, filtered, transformed — and at every gate the pipeline observes itself, counting what passed, what fell, and what remains. The workshop has learned that processing is not a single act but a journey through many hands, and that the journey itself deserves to be watched.*

---

**Lexicon Entry:**

| Term | Titan Name | Purpose |
|------|-----------|---------|
| Data Pipeline | **Sluice** | Multi-stage reactive data processing pipeline |
| Pipeline Stage | **SluiceStage** | Named processing step with retry, timeout, concurrency |
| Stage Metrics | **SluiceStageMetrics** | Per-stage reactive observability (processed, filtered, errors) |
| Pipeline Status | **SluiceStatus** | Lifecycle states: idle, processing, paused, disposed |
| Overflow Strategy | **SluiceOverflow** | Buffer-full behavior: backpressure, dropOldest, dropNewest |
