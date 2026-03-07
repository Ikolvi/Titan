import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Fresco — Screen Image Capture
// ---------------------------------------------------------------------------

/// **Fresco** — captures a PNG screenshot of the current screen.
///
/// Used internally by Colossus when `enableScreenCapture` is `true`.
/// Developers never interact with this directly — it is triggered
/// automatically during [Shade] recording alongside [Tableau] captures.
///
/// ## Why "Fresco"?
///
/// A painted mural on the Titan's wall — an actual visual image of
/// the screen, preserved alongside the structural [Glyph] data.
///
/// ## Privacy Note
///
/// Screenshots may contain PII (names, addresses, payment info).
/// This feature is **off by default** and must be explicitly enabled
/// via `Colossus.init(enableScreenCapture: true)`.
///
/// ## Usage (Internal — Called by Colossus)
///
/// ```dart
/// final bytes = await Fresco.capture(pixelRatio: 0.5);
/// if (bytes != null) {
///   // Attach to Tableau
/// }
/// ```
class Fresco {
  // Fresco is a utility class — no instances.
  Fresco._();

  /// Capture the current screen as PNG bytes.
  ///
  /// Uses [RenderRepaintBoundary.toImage] to capture the screen
  /// content. Returns `null` if capture fails (e.g., no render
  /// boundary available, or if called outside a paint cycle).
  ///
  /// [pixelRatio] controls resolution:
  /// - `1.0` = logical resolution (default)
  /// - `0.5` = half resolution (saves 75% space)
  /// - `2.0` = retina resolution (large files)
  ///
  /// ## Performance
  ///
  /// Capture takes 5-15ms depending on screen complexity and
  /// [pixelRatio]. This is acceptable since it only runs during
  /// recording (not in production) and is async.
  static Future<Uint8List?> capture({
    double pixelRatio = 1.0,
  }) async {
    try {
      final boundary = _findRepaintBoundary();
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      // Fail silently — screenshots are optional and non-critical.
      return null;
    }
  }

  /// Find the root [RenderRepaintBoundary] for screen capture.
  ///
  /// Walks up from the root render object to find the first
  /// [RenderRepaintBoundary], which typically wraps the entire
  /// app content.
  static RenderRepaintBoundary? _findRepaintBoundary() {
    final binding = WidgetsBinding.instance;
    final rootElement = binding.rootElement;
    if (rootElement == null) return null;

    final renderObject = rootElement.renderObject;
    if (renderObject == null) return null;

    // Check if root is already a boundary
    if (renderObject is RenderRepaintBoundary) return renderObject;

    // Walk children to find the first boundary
    RenderRepaintBoundary? result;
    void visitor(RenderObject child) {
      if (result != null) return;
      if (child is RenderRepaintBoundary) {
        result = child;
        return;
      }
      child.visitChildren(visitor);
    }
    renderObject.visitChildren(visitor);

    return result;
  }
}
