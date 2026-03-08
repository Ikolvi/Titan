// ---------------------------------------------------------------------------
// RouteParameterizer — Detect route parameters from observed routes
// ---------------------------------------------------------------------------

/// **RouteParameterizer** — detects route parameters from observed
/// route variations.
///
/// ## Why?
///
/// When the Scout observes `/quest/42` and `/quest/7`, it needs to
/// know they're the same screen pattern `/quest/:id`. This class
/// compares observed routes to detect which path segments are
/// parameters (variable) vs. constants.
///
/// ## Algorithm
///
/// ```
/// 1. Group routes by segment count
/// 2. Within each group, find segment positions that vary
/// 3. Replace varying segments with `:id` (numeric) or `:paramN`
/// 4. Cache and reuse patterns
/// ```
///
/// ## Usage
///
/// ```dart
/// final parameterizer = RouteParameterizer();
/// parameterizer.parameterize('/quest/42'); // → "/quest/42" (not enough data)
/// parameterizer.parameterize('/quest/7');  // → "/quest/:id" (now detected!)
/// ```
class RouteParameterizer {
  /// Known observed routes.
  final Set<String> _observedRoutes = {};

  /// Computed route-to-pattern mapping.
  final Map<String, String> _routeToPattern = {};

  /// Pre-registered patterns that should be used as-is.
  ///
  /// Useful when the developer knows the route structure and wants
  /// to skip the detection algorithm.
  final Set<String> _registeredPatterns = {};

  /// Register a known route pattern (e.g., from Atlas [Passage] definitions).
  ///
  /// Routes matching this pattern will use it directly instead of
  /// guessing from observations.
  void registerPattern(String pattern) {
    _registeredPatterns.add(pattern);
  }

  /// All observed routes.
  Set<String> get observedRoutes => Set.unmodifiable(_observedRoutes);

  /// All computed patterns.
  Map<String, String> get patterns => Map.unmodifiable(_routeToPattern);

  /// Register an observed route and return its parameterized pattern.
  ///
  /// On first observation, returns the route as-is. Once multiple
  /// routes with the same segment count are observed, varying
  /// segments are replaced with `:id` or `:paramN`.
  ///
  /// ```dart
  /// parameterize('/quest/42'); // → "/quest/42"
  /// parameterize('/quest/7');  // → "/quest/:id"
  /// // Now both map to "/quest/:id"
  /// ```
  String parameterize(String route) {
    _observedRoutes.add(route);

    // Check registered patterns first
    for (final pattern in _registeredPatterns) {
      if (_matchesPattern(route, pattern)) {
        _routeToPattern[route] = pattern;
        return pattern;
      }
    }

    // Check existing mapping
    if (_routeToPattern.containsKey(route)) {
      return _routeToPattern[route]!;
    }

    // Find routes with same segment count
    final segments = route.split('/');
    final sameLength = _observedRoutes
        .where((r) => r.split('/').length == segments.length && r != route)
        .toList();

    if (sameLength.isEmpty) {
      _routeToPattern[route] = route;
      return route;
    }

    // Compare segments to find varying positions
    final pattern = List<String>.filled(segments.length, '');
    var hasVariation = false;

    for (var i = 0; i < segments.length; i++) {
      final allValues = <String>{
        segments[i],
        ...sameLength.map((r) => r.split('/')[i]),
      };

      if (allValues.length == 1) {
        pattern[i] = segments[i]; // Constant segment
      } else {
        hasVariation = true;
        if (_looksLikeId(allValues)) {
          pattern[i] = ':id';
        } else {
          pattern[i] = ':param$i';
        }
      }
    }

    if (!hasVariation) {
      _routeToPattern[route] = route;
      return route;
    }

    // Require at least one non-empty constant segment to anchor the pattern.
    // Without an anchor, routes like /login and /home would be merged even
    // though they're distinct constant routes.
    final hasConstantAnchor = pattern.any(
      (p) => p.isNotEmpty && !p.startsWith(':'),
    );
    if (!hasConstantAnchor) {
      _routeToPattern[route] = route;
      return route;
    }

    final patternStr = pattern.join('/');

    // Update all matching routes to use this pattern
    _routeToPattern[route] = patternStr;
    for (final r in sameLength) {
      if (_segmentsMatch(r.split('/'), pattern)) {
        _routeToPattern[r] = patternStr;
      }
    }

    return patternStr;
  }

  /// Get the pattern for a previously observed route.
  ///
  /// Returns null if the route has never been observed.
  String? patternFor(String route) => _routeToPattern[route];

  /// Reset all observed routes and patterns.
  void reset() {
    _observedRoutes.clear();
    _routeToPattern.clear();
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  /// Whether a set of values looks like IDs (numeric or UUID-like).
  bool _looksLikeId(Set<String> values) {
    return values.every(
      (v) =>
          v.isEmpty ||
          int.tryParse(v) != null ||
          RegExp(r'^[a-f0-9-]{8,}$', caseSensitive: false).hasMatch(v),
    );
  }

  /// Whether a route matches a registered pattern.
  bool _matchesPattern(String route, String pattern) {
    final routeSegments = route.split('/');
    final patternSegments = pattern.split('/');

    if (routeSegments.length != patternSegments.length) return false;

    for (var i = 0; i < routeSegments.length; i++) {
      if (patternSegments[i].startsWith(':')) continue;
      if (routeSegments[i] != patternSegments[i]) return false;
    }

    return true;
  }

  /// Whether route segments match a pattern (constant segments equal).
  bool _segmentsMatch(List<String> segments, List<String> pattern) {
    if (segments.length != pattern.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (pattern[i].startsWith(':')) continue;
      if (segments[i] != pattern[i]) return false;
    }
    return true;
  }
}
