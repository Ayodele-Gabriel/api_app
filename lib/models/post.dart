class Post {
  final int userId;
  final int id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final List<String> tags;
  final PostStatus status;

  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
    this.tags = const [],
    this.status = PostStatus.published,
  });

  // Modern JSON parsing with exhaustive pattern matching
  factory Post.fromJson(Map<String, dynamic> json) {
    return switch (json) {
    // Perfect match - all required fields present and correct types
      {
      'userId': int userId,
      'id': int id,
      'title': String title,
      'body': String body,
      } => Post(
        userId: userId,
        id: id,
        title: title,
        body: body,
        createdAt: _parseDateTime(json['createdAt']),
        tags: _parseTags(json['tags']),
        status: _parseStatus(json['status']),
      ),

    // Handle type mismatches with conversion
      {
      'userId': final dynamic userIdRaw,
      'id': final dynamic idRaw,
      'title': final dynamic titleRaw,
      'body': final dynamic bodyRaw,
      } => Post(
        userId: _parseInt(userIdRaw),
        id: _parseInt(idRaw),
        title: _parseString(titleRaw),
        body: _parseString(bodyRaw),
        createdAt: _parseDateTime(json['createdAt']),
        tags: _parseTags(json['tags']),
        status: _parseStatus(json['status']),
      ),

    // Minimal data pattern
      {'id': final dynamic idRaw} => Post(
        userId: 0,
        id: _parseInt(idRaw),
        title: 'Untitled Post',
        body: 'No content available',
      ),

    // Fallback for completely invalid data
      _ => throw FormatException(
        'Invalid post data structure. Expected at least an id field. Got: $json',
      ),
    };
  }

  // Helper methods for safe type conversion
  static int _parseInt(dynamic value) {
    return switch (value) {
      int intValue => intValue,
      String stringValue => int.tryParse(stringValue) ?? 0,
      double doubleValue => doubleValue.toInt(),
      _ => 0,
    };
  }

  static String _parseString(dynamic value) {
    return switch (value) {
      String stringValue => stringValue,
      null => '',
      _ => value.toString(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    return switch (value) {
      String dateString => DateTime.tryParse(dateString),
      int timestamp => DateTime.fromMillisecondsSinceEpoch(timestamp),
      _ => null,
    };
  }

  static List<String> _parseTags(dynamic value) {
    return switch (value) {
      List<dynamic> list => list
          .map((item) => item.toString())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      String singleTag => [singleTag],
      _ => <String>[],
    };
  }

  static PostStatus _parseStatus(dynamic value) {
    return switch (value) {
      'published' => PostStatus.published,
      'draft' => PostStatus.draft,
      'archived' => PostStatus.archived,
      _ => PostStatus.published,
    };
  }

  // Modern toJson with validation
  Map<String, dynamic> toJson() {
    final json = {
      'userId': userId,
      'id': id,
      'title': title,
      'body': body,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (tags.isNotEmpty) 'tags': tags,
      'status': status.name,
    };

    // Validate the output using pattern matching
    return switch (json) {
      {'userId': int, 'id': int, 'title': String, 'body': String} => json,
      _ => throw StateError('Generated invalid JSON for post'),
    };
  }

  // Copy method with pattern matching validation
  Post copyWith({
    int? userId,
    int? id,
    String? title,
    String? body,
    DateTime? createdAt,
    List<String>? tags,
    PostStatus? status,
  }) {
    return Post(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      status: status ?? this.status,
    );
  }

  @override
  String toString() => 'Post(id: $id, title: "$title", userId: $userId, status: ${status.name})';

  @override
  bool operator ==(Object other) {
    return other is Post &&
        other.id == id &&
        other.userId == userId &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, userId, title);
}

enum PostStatus { published, draft, archived }
