import 'dart:convert';
import 'dart:typed_data';

/// A Parcel bundles multipart form data for file uploads via [Envoy].
///
/// Equivalent to `FormData` in traditional HTTP clients.
///
/// ```dart
/// final parcel = Parcel()
///   ..addField('name', 'Kael')
///   ..addFile('avatar', ParcelFile.fromBytes(
///     bytes: avatarBytes,
///     filename: 'avatar.png',
///     contentType: 'image/png',
///   ));
///
/// await envoy.post('/upload', data: parcel);
/// ```
class Parcel {
  /// Creates an empty [Parcel].
  Parcel();

  /// Creates a [Parcel] pre-populated with [fields].
  factory Parcel.fromMap(Map<String, String> fields) {
    final parcel = Parcel();
    fields.forEach(parcel.addField);
    return parcel;
  }

  final List<ParcelEntry> _entries = [];

  /// All entries in this parcel (fields and files).
  List<ParcelEntry> get entries => List.unmodifiable(_entries);

  /// Adds a text field to the parcel.
  void addField(String name, String value) {
    _entries.add(ParcelField(name: name, value: value));
  }

  /// Adds a file to the parcel.
  void addFile(String name, ParcelFile file) {
    _entries.add(ParcelFileEntry(name: name, file: file));
  }

  /// All field entries in this parcel.
  Iterable<ParcelField> get fields => _entries.whereType<ParcelField>();

  /// All file entries in this parcel.
  Iterable<ParcelFileEntry> get files => _entries.whereType<ParcelFileEntry>();

  /// Whether this parcel has any files (determines multipart encoding).
  bool get hasFiles => _entries.any((e) => e is ParcelFileEntry);

  /// Encodes as application/x-www-form-urlencoded (fields only, no files).
  String toUrlEncoded() {
    return fields
        .map((f) {
          final key = Uri.encodeQueryComponent(f.name);
          final value = Uri.encodeQueryComponent(f.value);
          return '$key=$value';
        })
        .join('&');
  }

  /// Builds the multipart body bytes with the given [boundary].
  List<int> buildMultipartBody(String boundary) {
    final buffer = <int>[];
    for (final entry in _entries) {
      buffer.addAll(utf8.encode('--$boundary\r\n'));
      switch (entry) {
        case ParcelField(:final name, :final value):
          buffer.addAll(
            utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
          );
          buffer.addAll(utf8.encode('$value\r\n'));
        case ParcelFileEntry(:final name, :final file):
          final disposition = StringBuffer(
            'Content-Disposition: form-data; name="$name"',
          );
          if (file.filename != null) {
            disposition.write('; filename="${file.filename}"');
          }
          buffer.addAll(utf8.encode('$disposition\r\n'));
          if (file.contentType != null) {
            buffer.addAll(utf8.encode('Content-Type: ${file.contentType}\r\n'));
          }
          buffer.addAll(utf8.encode('\r\n'));
          buffer.addAll(file.bytes);
          buffer.addAll(utf8.encode('\r\n'));
      }
    }
    buffer.addAll(utf8.encode('--$boundary--\r\n'));
    return buffer;
  }

  /// Generates a random multipart boundary string.
  static String generateBoundary() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer('----EnvoyBoundary');
    for (var i = 0; i < 16; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}

/// A single entry in a [Parcel].
sealed class ParcelEntry {
  /// The field name.
  String get name;
}

/// A text field entry in a [Parcel].
class ParcelField extends ParcelEntry {
  /// Creates a text field entry.
  ParcelField({required this.name, required this.value});

  @override
  final String name;

  /// The field value.
  final String value;
}

/// A file entry in a [Parcel].
class ParcelFileEntry extends ParcelEntry {
  /// Creates a file entry.
  ParcelFileEntry({required this.name, required this.file});

  @override
  final String name;

  /// The file data.
  final ParcelFile file;
}

/// File data for multipart uploads in a [Parcel].
///
/// ```dart
/// // From bytes
/// final file = ParcelFile.fromBytes(
///   bytes: imageData,
///   filename: 'photo.jpg',
///   contentType: 'image/jpeg',
/// );
///
/// // From string
/// final textFile = ParcelFile.fromString(
///   content: 'Hello, World!',
///   filename: 'greeting.txt',
///   contentType: 'text/plain',
/// );
/// ```
class ParcelFile {
  /// Creates a [ParcelFile] from raw bytes.
  ParcelFile.fromBytes({required this.bytes, this.filename, this.contentType});

  /// Creates a [ParcelFile] from a string.
  factory ParcelFile.fromString({
    required String content,
    String? filename,
    String? contentType,
  }) {
    return ParcelFile.fromBytes(
      bytes: Uint8List.fromList(utf8.encode(content)),
      filename: filename,
      contentType: contentType ?? 'text/plain',
    );
  }

  /// The raw file bytes.
  final Uint8List bytes;

  /// The filename, if any.
  final String? filename;

  /// The MIME type, if any.
  final String? contentType;

  /// File size in bytes.
  int get length => bytes.length;
}
