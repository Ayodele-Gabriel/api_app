import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:api_app/models/photos.dart';
import "package:http/http.dart" as http;

import '../../models/post.dart';
import '../../models/user.dart';

sealed class ApiResponse<T> {
  const ApiResponse();
}

class ApiSuccess<T> extends ApiResponse<T> {
  final T data;
  final Map<String, String> headers;
  final int statusCode;
  final String? requestId;

  const ApiSuccess({
    required this.data,
    required this.headers,
    required this.statusCode,
    this.requestId,
  });
}

class ApiError<T> extends ApiResponse<T> {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final NetworkErrorType type;
  final List<String>? suggestions;

  const ApiError({
    required this.message,
    required this.type,
    this.statusCode,
    this.originalError,
    this.suggestions,
  });
}

enum NetworkErrorType {
  noConnection,
  timeout,
  notFound,
  unauthorized,
  serverError,
  badRequest,
  parseError,
  unknown,
}

// Modern API service with pattern matching
class ModernJSONPlaceholderService {
  static const String _baseUrl = 'https://jsonplaceholder.typicode.com';
  static const Duration _timeout = Duration(seconds: 15);

  // Enhanced HTTP client with better configuration
  static final http.Client _client = http.Client();

  // Modern error handling with pattern matching
  static ApiError<T> _handleError<T>(dynamic error, {http.Response? response}) {
    return switch (error) {
      SocketException() => ApiError<T>(
        message: 'No internet connection',
        type: NetworkErrorType.noConnection,
        originalError: error,
      ),

      TimeoutException() => ApiError<T>(
        message: 'Request timeout',
        type: NetworkErrorType.timeout,
        originalError: error,
      ),

      FormatException() => ApiError<T>(
        message: 'Invalid data format',
        type: NetworkErrorType.parseError,
        originalError: error,
      ),

      _ when response != null => switch (response.statusCode) {
        400 => ApiError<T>(
          message: 'Bad request',
          type: NetworkErrorType.badRequest,
          statusCode: response.statusCode,
        ),
        401 => ApiError<T>(
          message: 'Unauthorized',
          type: NetworkErrorType.unauthorized,
          statusCode: response.statusCode,
        ),
        404 => ApiError<T>(
          message: 'Not found',
          type: NetworkErrorType.notFound,
          statusCode: response.statusCode,
        ),
        >= 500 => ApiError<T>(
          message: 'Server error',
          type: NetworkErrorType.serverError,
          statusCode: response.statusCode,
        ),
        _ => ApiError<T>(
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          type: NetworkErrorType.unknown,
          statusCode: response.statusCode,
        ),
      },

      _ => ApiError<T>(
        message: 'Unknown error: $error',
        type: NetworkErrorType.unknown,
        originalError: error,
      ),
    };
  }

  // Modern HTTP GET with enhanced error handling
  static Future<ApiResponse<T>> _get<T>(
      String endpoint,
      T Function(dynamic json) parser,
      ) async {
    final url = '$_baseUrl$endpoint';
    print('🌐 GET request to: $url');

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'User-Agent': 'Flutter-JSONPlaceholder-Explorer/1.0',
        },
      ).timeout(_timeout);

      print('📡 Response status: ${response.statusCode}');
      print('📊 Response length: ${response.body.length} chars');

      return switch (response.statusCode) {
        >= 200 && < 300 => () {
          try {
            final jsonData = json.decode(response.body);
            final parsedData = parser(jsonData);

            return ApiSuccess<T>(
              data: parsedData,
              headers: response.headers,
              statusCode: response.statusCode,
            );
          } catch (parseError) {
            print('❌ Parse error: $parseError');
            return _handleError<T>(parseError, response: response);
          }
        }(),

        _ => _handleError<T>(
          'HTTP ${response.statusCode}',
          response: response,
        ),
      };

    } catch (error) {
      print('❌ Network error: $error');
      return _handleError<T>(error);
    }
  }

  // Enhanced POST method with pattern matching
  static Future<ApiResponse<T>> _post<T>(
      String endpoint,
      Map<String, dynamic> body,
      T Function(dynamic json) parser,
      ) async {
    final url = '$_baseUrl$endpoint';
    print('🌐 POST request to: $url');
    print('📤 Request body: ${json.encode(body)}');

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      ).timeout(_timeout);

      return switch (response.statusCode) {
        201 || 200 => () {
          try {
            final jsonData = json.decode(response.body);
            final parsedData = parser(jsonData);

            return ApiSuccess<T>(
              data: parsedData,
              headers: response.headers,
              statusCode: response.statusCode,
            );
          } catch (parseError) {
            return _handleError<T>(parseError, response: response);
          }
        }(),

        _ => _handleError<T>(
          'HTTP ${response.statusCode}',
          response: response,
        ),
      };

    } catch (error) {
      return _handleError<T>(error);
    }
  }

  // Modern service methods with enhanced pattern matching
  static Future<ApiResponse<List<Post>>> getPosts() async {
    return _get<List<Post>>(
      '/posts',
          (jsonData) => switch (jsonData) {
        List<dynamic> list => list
            .map((item) => switch (item) {
          Map<String, dynamic> postJson => Post.fromJson(postJson),
          _ => throw FormatException('Invalid post format: $item'),
        })
            .toList(),
        _ => throw FormatException('Expected list of posts, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<List<User>>> getUsers() async {
    return _get<List<User>>(
      '/users',
          (jsonData) => switch (jsonData) {
        List<dynamic> list => list
            .map((item) => switch (item) {
          Map<String, dynamic> userJson => User.fromJson(userJson),
          _ => throw FormatException('Invalid user format: $item'),
        })
            .toList(),
        _ => throw FormatException('Expected list of users, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<User>> getUser(int userId) async {
    return _get<User>(
      '/users/$userId',
          (jsonData) => switch (jsonData) {
        Map<String, dynamic> userJson => User.fromJson(userJson),
        _ => throw FormatException('Expected user object, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<List<Photos>>> getPhotos() async {
    return _get<List<Photos>>(
      '/photos',
          (jsonData) => switch (jsonData) {
        List<dynamic> list => list
            .map((item) => switch (item) {
          Map<String, dynamic> photoJson => Photos.fromJson(photoJson),
          _ => throw FormatException('Invalid photo format: $item'),
        })
            .toList(),
        _ => throw FormatException('Expected list of photos, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<Photos>> getPhoto(int userId) async {
    return _get<Photos>(
      '/photos/$userId',
          (jsonData) => switch (jsonData) {
        Map<String, dynamic> photoJson => Photos.fromJson(photoJson),
        _ => throw FormatException('Expected photo object, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<Post>> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    return _post<Post>(
      '/posts',
      {
        'title': title,
        'body': body,
        'userId': userId,
      },
          (jsonData) => switch (jsonData) {
        Map<String, dynamic> postJson => Post.fromJson(postJson),
        _ => throw FormatException('Expected post object, got: ${jsonData.runtimeType}'),
      },
    );
  }

  // Enhanced filtering with pattern matching
  static Future<ApiResponse<List<Post>>> getPostsByUser(int userId) async {
    return _get<List<Post>>(
      '/posts?userId=$userId',
          (jsonData) => switch (jsonData) {
        List<dynamic> list when list.isNotEmpty => list
            .where((item) => switch (item) {
          Map<String, dynamic> post => post['userId'] == userId,
          _ => false,
        })
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList(),
        List<dynamic> _ => <Post>[],
        _ => throw FormatException('Expected list of posts, got: ${jsonData.runtimeType}'),
      },
    );
  }

  static Future<ApiResponse<List<Photos>>> getPhotosByUser(int userId) async {
    return _get<List<Photos>>(
      '/photos?userId=$userId',
          (jsonData) => switch (jsonData) {
        List<dynamic> list when list.isNotEmpty => list
            .where((item) => switch (item) {
          Map<String, dynamic> photo => photo['userId'] == userId,
          _ => false,
        })
            .map((item) => Photos.fromJson(item as Map<String, dynamic>))
            .toList(),
        List<dynamic> _ => <Photos>[],
        _ => throw FormatException('Expected list of photos, got: ${jsonData.runtimeType}'),
      },
    );
  }

  // Cleanup method
  static void dispose() {
    _client.close();
  }
}
