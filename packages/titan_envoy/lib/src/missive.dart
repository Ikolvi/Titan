import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'parcel.dart';
import 'recall.dart';

/// HTTP method verbs supported by [Envoy].
enum Method {
  /// HTTP GET — retrieve a resource.
  get,

  /// HTTP POST — create a resource.
  post,

  /// HTTP PUT — replace a resource.
  put,

  /// HTTP DELETE — remove a resource.
  delete,

  /// HTTP PATCH — partially update a resource.
  patch,

  /// HTTP HEAD — retrieve headers only.
  head,

  /// HTTP OPTIONS — query supported methods.
  options;

  /// Upper-case verb string for HTTP headers.
  String get verb => name.toUpperCase();
}

/// A Missive is a request configuration sent by [Envoy].
///
/// Contains all information needed to make an HTTP request: method, URL,
/// headers, body, query parameters, and options.
///
/// ```dart
/// final missive = Missive(
///   method: Method.get,
///   uri: Uri.parse('https://api.example.com/users'),
///   headers: {'Accept': 'application/json'},
///   queryParameters: {'page': '1'},
/// );
/// ```
@immutable
class Missive {
  /// Creates a new [Missive] request configuration.
  const Missive({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.data,
    this.queryParameters = const {},
    this.recall,
    this.sendTimeout,
    this.receiveTimeout,
    this.responseType = ResponseType.json,
    this.extra = const {},
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.validateStatus,
    this.onSendProgress,
    this.onReceiveProgress,
  });

  /// The HTTP method.
  final Method method;

  /// The target URI (fully resolved with base URL and path).
  final Uri uri;

  /// Request headers.
  final Map<String, String> headers;

  /// Request body — can be [String], [Map], [List], [Parcel],
  /// [Uint8List], or [Stream<List<int>>].
  final Object? data;

  /// Additional query parameters merged into [uri].
  final Map<String, String> queryParameters;

  /// Optional [Recall] token to cancel this request.
  final Recall? recall;

  /// Timeout for sending the request body.
  final Duration? sendTimeout;

  /// Timeout for receiving the response.
  final Duration? receiveTimeout;

  /// Expected response content type.
  final ResponseType responseType;

  /// Extra metadata carried through the [Courier] chain.
  ///
  /// Use this to pass context between couriers without modifying headers.
  final Map<String, Object?> extra;

  /// Whether to follow HTTP redirects automatically.
  final bool followRedirects;

  /// Maximum number of redirects to follow.
  final int maxRedirects;

  /// Custom status code validator.
  ///
  /// Return `true` to treat the status as successful.
  /// Defaults to `status >= 200 && status < 300`.
  final bool Function(int status)? validateStatus;

  /// Called with upload progress updates.
  final void Function(int sent, int total)? onSendProgress;

  /// Called with download progress updates.
  final void Function(int received, int total)? onReceiveProgress;

  /// Returns the fully resolved URI with [queryParameters] merged in.
  Uri get resolvedUri {
    if (queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParameters},
    );
  }

  /// Serializes [data] to a request body string.
  ///
  /// - [Map] / [List] → JSON string
  /// - [String] → as-is
  /// - `null` → `null`
  String? get encodedBody {
    final d = data;
    if (d == null) return null;
    if (d is String) return d;
    if (d is Map || d is List) return jsonEncode(d);
    if (d is Parcel) return null; // handled separately
    return d.toString();
  }

  /// Creates a copy with the given fields replaced.
  Missive copyWith({
    Method? method,
    Uri? uri,
    Map<String, String>? headers,
    Object? data,
    bool clearData = false,
    Map<String, String>? queryParameters,
    Recall? recall,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    ResponseType? responseType,
    Map<String, Object?>? extra,
    bool? followRedirects,
    int? maxRedirects,
    bool Function(int status)? validateStatus,
    void Function(int sent, int total)? onSendProgress,
    void Function(int received, int total)? onReceiveProgress,
  }) {
    return Missive(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      data: clearData ? null : (data ?? this.data),
      queryParameters: queryParameters ?? this.queryParameters,
      recall: recall ?? this.recall,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      responseType: responseType ?? this.responseType,
      extra: extra ?? this.extra,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      validateStatus: validateStatus ?? this.validateStatus,
      onSendProgress: onSendProgress ?? this.onSendProgress,
      onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    );
  }

  @override
  String toString() => 'Missive(${method.verb} $resolvedUri)';
}

/// Expected response content format.
enum ResponseType {
  /// Parse response body as JSON.
  json,

  /// Return response body as raw [String].
  plain,

  /// Return response body as [Uint8List].
  bytes,

  /// Return response body as [Stream<List<int>>].
  stream,
}
