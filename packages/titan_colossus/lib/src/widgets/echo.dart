import 'package:flutter/widgets.dart';

import '../colossus.dart';

// ---------------------------------------------------------------------------
// Echo — Widget Rebuild Tracking
// ---------------------------------------------------------------------------

/// **Echo** — tracks widget rebuilds to detect excessive re-rendering.
///
/// Wrap any widget with [Echo] to count how many times it rebuilds.
/// The Colossus aggregates rebuild counts and can alert via [Tremor]
/// when thresholds are exceeded.
///
/// ## Why "Echo"?
///
/// Each rebuild echoes through the widget tree. Too many echoes
/// means wasted work.
///
/// ## Usage
///
/// ```dart
/// // Wrap a widget to track its rebuilds
/// Echo(
///   label: 'QuestList',
///   child: QuestListWidget(),
/// )
///
/// // Check rebuild counts
/// final counts = Colossus.instance.rebuildsPerWidget;
/// print(counts['QuestList']); // e.g. 42
/// ```
///
/// ## How It Works
///
/// Every time [Echo] rebuilds, it increments a counter for its [label]
/// in the [Colossus] instance. This is extremely lightweight — just a
/// map increment per rebuild.
class Echo extends StatelessWidget {
  /// A unique label identifying this widget for rebuild tracking.
  ///
  /// Use a descriptive name like `'QuestList'` or `'HeroProfile'`.
  final String label;

  /// The child widget to track.
  final Widget child;

  /// Creates an [Echo] rebuild tracker.
  ///
  /// ```dart
  /// Echo(
  ///   label: 'QuestList',
  ///   child: QuestListWidget(),
  /// )
  /// ```
  const Echo({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Colossus.isActive) {
      Colossus.instance.recordRebuild(label);
    }
    return child;
  }
}
