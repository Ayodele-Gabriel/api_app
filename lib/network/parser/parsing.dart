// Result type for safe parsing
import 'package:api_app/models/photos.dart';

import '../../models/post.dart';
import '../../models/user.dart';

sealed class ParseResult<T> {
  const ParseResult();
}

class ParseSuccess<T> extends ParseResult<T> {
  final T data;
  final List<String> warnings;

  const ParseSuccess(this.data, {this.warnings = const []});
}

class ParseError<T> extends ParseResult<T> {
  final String message;
  final Map<String, dynamic> originalData;
  final List<String> fieldErrors;

  const ParseError({
    required this.message,
    required this.originalData,
    this.fieldErrors = const [],
  });
}

// Enhanced parsing service
class SafeJSONParser {
  static ParseResult<List<Post>> parsePosts(dynamic jsonData) {
    return switch (jsonData) {
      List<dynamic> list => () {
        final List<Post> posts = [];
        final List<String> errors = [];
        final List<String> warnings = [];

        for (int i = 0; i < list.length; i++) {
          try {
            final post = Post.fromJson(list[i] as Map<String, dynamic>);
            posts.add(post);
          } catch (e) {
            errors.add('Failed to parse post at index $i: $e');
            warnings.add('Skipped invalid post at position $i');
          }
        }

        if (errors.length > list.length / 2) {
          return ParseError<List<Post>>(
            message: 'Too many parsing errors (${errors.length}/${list.length})',
            originalData: {'posts': jsonData},
            fieldErrors: errors,
          );
        }

        return ParseSuccess(posts, warnings: warnings);
      }(),

      _ => ParseError<List<Post>>(
        message: 'Expected array of posts, got ${jsonData.runtimeType}',
        originalData: {'invalid_data': jsonData},
      ),
    };
  }

  static ParseResult<User> parseUser(dynamic jsonData) {
    return switch (jsonData) {
      Map<String, dynamic> userMap => () {
        try {
          final user = User.fromJson(userMap);
          final warnings = <String>[];

          // Add warnings for missing optional fields
          if (!userMap.containsKey('phone') || userMap['phone'] == null) {
            warnings.add('Phone number not provided');
          }
          if (!userMap.containsKey('website') || userMap['website'] == null) {
            warnings.add('Website not provided');
          }

          return ParseSuccess(user, warnings: warnings);
        } catch (e) {
          return ParseError<User>(
            message: 'Failed to parse user: $e',
            originalData: userMap,
          );
        }
      }(),

      _ => ParseError<User>(
        message: 'Expected user object, got ${jsonData.runtimeType}',
        originalData: {'invalid_data': jsonData},
      ),
    };
  }

  static ParseResult<Photos> parsePhotos(dynamic jsonData) {
    return switch (jsonData) {
      Map<String, dynamic> photoMap => () {
        try {
          final photo = Photos.fromJson(photoMap);
          final warnings = <String>[];

          // Add warnings for missing optional fields
          if (!photoMap.containsKey('title') || photoMap['title'] == null) {
            warnings.add('Title not provided');
          }

          return ParseSuccess(photo, warnings: warnings);
        } catch (e) {
          return ParseError<Photos>(
            message: 'Failed to parse user: $e',
            originalData: photoMap,
          );
        }
      }(),

      _ => ParseError<Photos>(
        message: 'Expected user object, got ${jsonData.runtimeType}',
        originalData: {'invalid_data': jsonData},
      ),
    };
  }
}
