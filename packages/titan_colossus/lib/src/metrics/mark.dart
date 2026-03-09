/// Performance metric data classes used throughout Colossus.
///
/// A [Mark] is a single performance measurement — a timestamp, duration,
/// category, and optional metadata. Specialized subclasses capture
/// domain-specific data: [FrameMark] for frame timing, [PageLoadMark]
/// for navigation latency, [RebuildMark] for widget rebuild counts,
/// and [MemoryMark] for memory snapshots.
library;

// ---------------------------------------------------------------------------
// Mark — Base performance metric
// ---------------------------------------------------------------------------

/// A single performance measurement captured by [Colossus].
///
/// Every metric in Colossus is a Mark — a timestamped measurement with
/// a category and optional metadata.
///
/// ```dart
/// final mark = Mark(
///   name: 'api_call',
///   category: MarkCategory.custom,
///   duration: Duration(milliseconds: 230),
/// );
/// ```
class Mark {
  /// Human-readable label for this metric.
  final String name;

  /// The category this mark belongs to.
  final MarkCategory category;

  /// The measured duration.
  final Duration duration;

  /// When this mark was recorded.
  final DateTime timestamp;

  /// Optional key-value metadata attached to this mark.
  final Map<String, dynamic>? metadata;

  /// Creates a performance [Mark].
  Mark({
    required this.name,
    required this.category,
    required this.duration,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts this mark to a JSON-serializable map.
  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category.name,
    'durationUs': duration.inMicroseconds,
    'timestamp': timestamp.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
  };

  @override
  String toString() =>
      'Mark($name, ${category.name}, ${duration.inMicroseconds}µs)';
}

/// Categories for performance marks.
enum MarkCategory {
  /// Frame rendering metric (build time, raster time, etc.).
  frame,

  /// Page/route load timing metric.
  pageLoad,

  /// Memory snapshot metric.
  memory,

  /// Widget rebuild metric.
  rebuild,

  /// API / HTTP request metric.
  api,

  /// User-defined custom metric.
  custom,
}

// ---------------------------------------------------------------------------
// FrameMark — Frame timing data
// ---------------------------------------------------------------------------

/// A frame timing measurement from Flutter's rendering pipeline.
///
/// ```dart
/// final frame = FrameMark(
///   buildDuration: Duration(microseconds: 4200),
///   rasterDuration: Duration(microseconds: 3100),
///   totalDuration: Duration(microseconds: 7300),
/// );
/// print(frame.isJank); // false (< 16ms)
/// ```
class FrameMark extends Mark {
  /// Time spent building the widget tree.
  final Duration buildDuration;

  /// Time spent rasterizing the frame.
  final Duration rasterDuration;

  /// Total frame duration (build + raster + overhead).
  final Duration totalDuration;

  /// Whether this frame exceeded the 16ms budget (60 FPS target).
  bool get isJank => totalDuration.inMilliseconds > 16;

  /// Whether this frame severely exceeded the budget (> 33ms = < 30 FPS).
  bool get isSevereJank => totalDuration.inMilliseconds > 33;

  /// Creates a [FrameMark] with build, raster, and total durations.
  FrameMark({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
    super.timestamp,
  }) : super(
         name: 'frame',
         category: MarkCategory.frame,
         duration: totalDuration,
       );

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'buildDurationUs': buildDuration.inMicroseconds,
    'rasterDurationUs': rasterDuration.inMicroseconds,
    'totalDurationUs': totalDuration.inMicroseconds,
    'isJank': isJank,
    'isSevereJank': isSevereJank,
  };

  @override
  String toString() =>
      'FrameMark(build=${buildDuration.inMicroseconds}µs, '
      'raster=${rasterDuration.inMicroseconds}µs, '
      'total=${totalDuration.inMicroseconds}µs'
      '${isJank ? ' JANK' : ''})';
}

// ---------------------------------------------------------------------------
// PageLoadMark — Page load timing
// ---------------------------------------------------------------------------

/// A page/route load timing measurement.
///
/// Captures the time from navigation start to first meaningful paint
/// for a specific route.
///
/// ```dart
/// final load = PageLoadMark(
///   path: '/quest/42',
///   duration: Duration(milliseconds: 120),
/// );
/// ```
class PageLoadMark extends Mark {
  /// The route path that was loaded.
  final String path;

  /// The route pattern that matched (e.g. `/quest/:id`).
  final String? pattern;

  /// Creates a [PageLoadMark] for the given [path] and [duration].
  PageLoadMark({
    required this.path,
    required super.duration,
    this.pattern,
    super.timestamp,
  }) : super(
         name: 'page_load',
         category: MarkCategory.pageLoad,
         metadata: {'path': path, 'pattern': ?pattern},
       );

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'path': path,
    if (pattern != null) 'pattern': pattern,
    'durationMs': duration.inMilliseconds,
  };

  @override
  String toString() => 'PageLoadMark($path, ${duration.inMilliseconds}ms)';
}

// ---------------------------------------------------------------------------
// RebuildMark — Widget rebuild snapshot
// ---------------------------------------------------------------------------

/// A widget rebuild count snapshot.
///
/// Captures the total rebuild count for a labeled widget at a point in time.
class RebuildMark extends Mark {
  /// The widget label (from [Echo]).
  final String label;

  /// The cumulative rebuild count at the time of this snapshot.
  final int rebuildCount;

  /// Creates a [RebuildMark].
  RebuildMark({
    required this.label,
    required this.rebuildCount,
    super.timestamp,
  }) : super(
         name: 'rebuild',
         category: MarkCategory.rebuild,
         duration: Duration.zero,
         metadata: {'label': label, 'count': rebuildCount},
       );

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'label': label,
    'rebuildCount': rebuildCount,
  };
}

// ---------------------------------------------------------------------------
// MemoryMark — Memory snapshot
// ---------------------------------------------------------------------------

/// A memory state snapshot.
///
/// Captures the number of live Pillar instances and any suspected leaks.
class MemoryMark extends Mark {
  /// Number of live Pillar instances.
  final int pillarCount;

  /// Number of total Titan DI instances.
  final int totalInstances;

  /// Pillar types suspected of leaking (alive longer than expected).
  final List<String> leakSuspects;

  /// Creates a [MemoryMark].
  MemoryMark({
    required this.pillarCount,
    required this.totalInstances,
    this.leakSuspects = const [],
    super.timestamp,
  }) : super(
         name: 'memory',
         category: MarkCategory.memory,
         duration: Duration.zero,
         metadata: {
           'pillarCount': pillarCount,
           'totalInstances': totalInstances,
           'leakSuspects': leakSuspects,
         },
       );

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'pillarCount': pillarCount,
    'totalInstances': totalInstances,
    'leakSuspects': leakSuspects,
  };
}

// ---------------------------------------------------------------------------
// LeakSuspect — Potential memory leak
// ---------------------------------------------------------------------------

/// A Pillar instance suspected of leaking.
///
/// Tracked when a Pillar remains registered in Titan longer than
/// [Vessel]'s configured threshold without being accessed.
class LeakSuspect {
  /// The runtime type name of the suspected Pillar.
  final String typeName;

  /// When the Pillar was first detected in the registry.
  final DateTime firstSeen;

  /// How long the Pillar has been alive.
  Duration get age => DateTime.now().difference(firstSeen);

  /// Creates a [LeakSuspect].
  const LeakSuspect({required this.typeName, required this.firstSeen});

  /// Converts this suspect to a JSON-serializable map.
  Map<String, dynamic> toMap() => {
    'typeName': typeName,
    'firstSeen': firstSeen.toIso8601String(),
    'ageSeconds': age.inSeconds,
  };

  @override
  String toString() => 'LeakSuspect($typeName, age=${age.inSeconds}s)';
}
