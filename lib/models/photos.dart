class Photos {
  final int albumId;
  final int id;
  final String title;
  final String url;
  final String thumbnailUrl;

  const Photos({
    required this.albumId,
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
  });

  factory Photos.empty() => Photos(
    albumId: 0,
    id: 0,
    title: '',
    url: '',
    thumbnailUrl: '',
  );

  // Modern JSON parsing with exhaustive pattern matching
  factory Photos.fromJson(Map<String, dynamic> json) {
    return switch (json) {
    // Perfect match - all required fields present and correct types
      {
      'albumId': int albumId,
      'id': int id,
      'title': String title,
      'url': String url,
      'thumbnailUrl': String thumbnailUrl,
      } => Photos(
        albumId: albumId,
        id: id,
        title: title,
        url: url,
        thumbnailUrl: thumbnailUrl,
      ),

    // Handle type mismatches with conversion
      {
      'albumId': final dynamic albumIdRaw,
      'id': final dynamic idRaw,
      'title': final dynamic titleRaw,
      'url': final dynamic urlRaw,
      'thumbnailUrl': final dynamic thumbnailUrlRaw,
      } => Photos(
        albumId: _parseInt(albumIdRaw),
        id: _parseInt(idRaw),
        title: _parseString(titleRaw),
        url: _parseString(urlRaw),
        thumbnailUrl: _parseString(thumbnailUrlRaw),

      ),

    // Minimal data pattern
      {'id': final dynamic idRaw} => Photos(
        albumId: 0,
        id: _parseInt(idRaw),
        title: 'Untitled Post',
        url: 'No image available',
        thumbnailUrl: 'No thumbnail available',
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

  // Modern toJson with validation
  Map<String, dynamic> toJson() {
    final json = {
      'albumId': albumId,
      'id': id,
      'title': title,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
    };

    // Validate the output using pattern matching
    return switch (json) {
      {'albumId': int, 'id': int, 'title': String, 'url': String, 'thumbnailUrl': String} => json,
      _ => throw StateError('Generated invalid JSON for post'),
    };
  }

  // Copy method with pattern matching validation
  Photos copyWith({
    int? albumId,
    int? id,
    String? title,
    String? url,
    String? thumbnailUrl,
  }) {
    return Photos(
      albumId: albumId ?? this.albumId,
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  @override
  String toString() => 'Post(id: $id, title: "$title", albumId: $albumId, url: $url, thumbnailUrl: $thumbnailUrl,})';

  @override
  bool operator ==(Object other) {
    return other is Photos &&
        other.id == id &&
        other.albumId == albumId &&
        other.title == title &&
        other.url == url &&
        other.thumbnailUrl == thumbnailUrl;
  }

  @override
  int get hashCode => Object.hash(id, albumId, title, url, thumbnailUrl);
}
