import 'dart:convert';

import 'package:meta/meta.dart';

import 'missive.dart';

/// A Dispatch is the response returned by [Envoy] after sending a [Missive].
///
/// Contains the HTTP status code, parsed response data, headers, and timing
/// information for performance monitoring.
///
/// ```dart
/// final dispatch = await envoy.get('/users');
/// print(dispatch.statusCode);    // 200
/// print(dispatch.data);          // parsed JSON Map or List
/// print(dispatch.headers);       // response headers
/// print(dispatch.duration);      // request round-trip time
/// ```
@immutable
class Dispatch {
  /// Creates a new [Dispatch] response.
  const Dispatch({
    required this.statusCode,
    required this.headers,
    required this.missive,
    this.data,
    this.rawBody,
    this.duration,
  });

  /// The HTTP status code.
  final int statusCode;

  /// Parsed response data.
  ///
  /// - [ResponseType.json]: Decoded JSON ([Map], [List], [String], etc.)
  /// - [ResponseType.plain]: Raw [String]
  /// - [ResponseType.bytes]: [Uint8List]
  final Object? data;

  /// The raw response body as a string, before any parsing.
  final String? rawBody;

  /// Response headers.
  final Map<String, String> headers;

  /// The original [Missive] that produced this dispatch.
  final Missive missive;

  /// Time elapsed from request start to response completion.
  final Duration? duration;

  /// Whether the response status indicates success (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the response status indicates a redirect (3xx).
  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  /// Whether the response status indicates a client error (4xx).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the response status indicates a server error (5xx).
  bool get isServerError => statusCode >= 500;

  /// Content-Type header value, if present.
  String? get contentType => headers['content-type'];

  /// Content-Length header value, if present.
  int? get contentLength {
    final value = headers['content-length'];
    return value != null ? int.tryParse(value) : null;
  }

  /// Returns [data] cast to [Map<String, dynamic>].
  ///
  /// Throws [FormatException] if [data] is not a Map.
  Map<String, dynamic> get jsonMap {
    final d = data;
    if (d is Map<String, dynamic>) return d;
    throw FormatException(
      'Expected JSON object, got ${d.runtimeType}',
      rawBody,
    );
  }

  /// Returns [data] cast to [List<dynamic>].
  ///
  /// Throws [FormatException] if [data] is not a List.
  List<dynamic> get jsonList {
    final d = data;
    if (d is List) return d;
    throw FormatException('Expected JSON array, got ${d.runtimeType}', rawBody);
  }

  /// Parses the response body as JSON (useful for [ResponseType.plain]).
  Object? get parsedJson {
    final raw = rawBody;
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  /// Creates a copy with the given fields replaced.
  Dispatch copyWith({
    int? statusCode,
    Object? data,
    bool clearData = false,
    String? rawBody,
    Map<String, String>? headers,
    Missive? missive,
    Duration? duration,
  }) {
    return Dispatch(
      statusCode: statusCode ?? this.statusCode,
      data: clearData ? null : (data ?? this.data),
      rawBody: rawBody ?? this.rawBody,
      headers: headers ?? this.headers,
      missive: missive ?? this.missive,
      duration: duration ?? this.duration,
    );
  }

  @override
  String toString() =>
      'Dispatch(${missive.method.verb} ${missive.resolvedUri} → $statusCode)';
}
