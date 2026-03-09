import 'dart:async';

import 'dispatch.dart';
import 'missive.dart';

/// A Courier intercepts HTTP requests and responses flowing through [Envoy].
///
/// Couriers form a chain of responsibility — each courier can inspect,
/// modify, short-circuit, or retry requests before they reach the network,
/// and transform responses on the way back.
///
/// ```dart
/// class TimingCourier extends Courier {
///   @override
///   Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
///     final sw = Stopwatch()..start();
///     final dispatch = await chain.proceed(missive);
///     sw.stop();
///     print('${missive.method.verb} took ${sw.elapsedMilliseconds}ms');
///     return dispatch;
///   }
/// }
/// ```
abstract class Courier {
  /// Intercepts a [missive] and returns a [Dispatch].
  ///
  /// Call [chain.proceed] to forward the request to the next courier
  /// or the network layer. You may:
  /// - Modify the [missive] before calling `proceed`
  /// - Modify the [Dispatch] after calling `proceed`
  /// - Short-circuit by returning a [Dispatch] without calling `proceed`
  /// - Retry by calling `proceed` multiple times
  Future<Dispatch> intercept(Missive missive, CourierChain chain);
}

/// The chain linking [Courier] interceptors together.
///
/// Each courier receives a [CourierChain] to forward the request to
/// the next courier or the final network execution.
class CourierChain {
  /// Creates a [CourierChain] with the given couriers and executor.
  CourierChain({
    required List<Courier> couriers,
    required Future<Dispatch> Function(Missive) execute,
  }) : _couriers = couriers,
       _index = 0,
       _execute = execute;

  CourierChain._({
    required List<Courier> couriers,
    required int index,
    required Future<Dispatch> Function(Missive) execute,
  }) : _couriers = couriers,
       _index = index,
       _execute = execute;

  final List<Courier> _couriers;
  final int _index;
  final Future<Dispatch> Function(Missive) _execute;

  /// Forwards the [missive] to the next courier in the chain, or
  /// executes the network request if all couriers have been called.
  Future<Dispatch> proceed(Missive missive) {
    if (_index < _couriers.length) {
      return _couriers[_index].intercept(
        missive,
        CourierChain._(
          couriers: _couriers,
          index: _index + 1,
          execute: _execute,
        ),
      );
    }
    return _execute(missive);
  }
}
