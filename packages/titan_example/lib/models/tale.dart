/// A tale posted on the Tavern bulletin board.
///
/// Maps to a JSONPlaceholder post — themed as a hero's tale
/// shared at the local tavern.
class Tale {
  final int id;
  final int userId;
  final String title;
  final String body;

  /// Author name — populated lazily from the users endpoint.
  String? authorName;

  Tale({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.authorName,
  });

  /// Creates a [Tale] from a JSONPlaceholder post JSON response.
  factory Tale.fromJson(Map<String, dynamic> json) => Tale(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  /// Serializes to JSON for POST/PUT requests.
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'userId': userId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tale && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A comment on a tavern tale — represents feedback from other heroes.
///
/// Maps to a JSONPlaceholder comment.
class TaleComment {
  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  const TaleComment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  /// Creates a [TaleComment] from a JSONPlaceholder comment JSON.
  factory TaleComment.fromJson(Map<String, dynamic> json) => TaleComment(
    id: json['id'] as int,
    postId: json['postId'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    body: json['body'] as String,
  );
}

/// Author identity — a guild member who posts tales.
///
/// Maps to a JSONPlaceholder user object.
class GuildMember {
  final int id;
  final String name;
  final String username;
  final String email;

  const GuildMember({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
  });

  /// Creates a [GuildMember] from a JSONPlaceholder user JSON.
  factory GuildMember.fromJson(Map<String, dynamic> json) => GuildMember(
    id: json['id'] as int,
    name: json['name'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
  );
}
