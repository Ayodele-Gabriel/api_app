import 'dart:convert';
import 'dart:math' as math;

import 'package:api_app/models/photos.dart';
import 'package:api_app/network/parser/parsing.dart';
import 'package:api_app/network/retry/retry_manager.dart';
import 'package:http/http.dart' as http;

import '../../models/post.dart';
import '../../models/user.dart';
import '../errors/error_detector.dart';
import '../errors/error_severity.dart';
import '../retry/retry_config.dart';
import 'api_response.dart';


class ProfessionalJSONPlaceholderService {
  static const String _baseUrl = 'https://jsonplaceholder.typicode.com';
  static final http.Client _client = http.Client();

  // Enhanced request with comprehensive error handling
  static Future<ApiResponse<T>> _makeRequest<T>(
      String endpoint,
      T Function(dynamic json) parser, {
        String method = 'GET',
        Map<String, dynamic>? body,
        RequestContext context = RequestContext.userInitiated,
        Duration? timeout,
      }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final config = ContextualRetryManager.getRetryConfig(context);

    print('🌐 [$method] $endpoint (context: ${context.name})');

    return SmartRetrySystem.executeWithRetry<ApiResponse<T>>(
          () => _performRequest(uri, parser, method: method, body: body, timeout: timeout),
      config: config,
      shouldRetry: (error) => ContextualRetryManager.shouldRetryError(error, context),
      onRetry: (attempt, error, delay) {
        print('🔄 Retry attempt $attempt for $endpoint');
        print('   Reason: ${error.userMessage}');
        print('   Waiting: ${delay.inSeconds}s');
      },
    );
  }

  static Future<ApiResponse<T>> _performRequest<T>(
      Uri uri,
      T Function(dynamic json) parser, {
        String method = 'GET',
        Map<String, dynamic>? body,
        Duration? timeout,
      }) async {
    try {
      late http.Response response;
      final requestTimeout = timeout ?? Duration(seconds: 15);

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(
            uri,
            headers: _getHeaders(),
          ).timeout(requestTimeout);

        case 'POST':
          response = await _client.post(
            uri,
            headers: _getHeaders(),
            body: body != null ? json.encode(body) : null,
          ).timeout(requestTimeout);

        case 'PUT':
          response = await _client.put(
            uri,
            headers: _getHeaders(),
            body: body != null ? json.encode(body) : null,
          ).timeout(requestTimeout);

        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: _getHeaders(),
          ).timeout(requestTimeout);

        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }

      return _processResponse(response, parser);

    } catch (error) {
      final networkError = ModernErrorDetector.analyzeError(error);

      return ApiError<T>(
        message: networkError.userMessage,
        type: _mapNetworkErrorType(networkError),
        originalError: error,
        suggestions: networkError.recoverySuggestions,
      );
    }
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'User-Agent': 'Flutter-JSONPlaceholder-Pro/2.0',
      'X-Request-ID': _generateRequestId(),
    };
  }

  static String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(9999)}';
  }

  static ApiResponse<T> _processResponse<T>(
      http.Response response,
      T Function(dynamic json) parser,
      ) {
    final statusCode = response.statusCode;

    print('📡 Response: $statusCode (${response.body.length} chars)');

    return switch (statusCode) {
      >= 200 && < 300 => () {
        try {
          final jsonData = json.decode(response.body);
          final parsedData = parser(jsonData);

          return ApiSuccess<T>(
            data: parsedData,
            statusCode: statusCode,
            headers: response.headers,
            requestId: response.headers['x-request-id'],
          );
        } catch (parseError) {
          final networkError = ParserError(parseError.toString());
          return ApiError<T>(
            message: networkError.userMessage,
            type: NetworkErrorType.parseError,
            originalError: parseError,
            suggestions: networkError.recoverySuggestions,
          );
        }
      }(),

      _ => () {
        final networkError = ModernErrorDetector.analyzeError(
          'HTTP $statusCode',
          response: response,
        );

        return ApiError<T>(
          message: networkError.userMessage,
          type: _mapNetworkErrorType(networkError),
          statusCode: statusCode,
          originalError: 'HTTP $statusCode: ${response.reasonPhrase}',
          suggestions: networkError.recoverySuggestions,
        );
      }(),
    };
  }

  static NetworkErrorType _mapNetworkErrorType(NetworkError error) {
    return switch (error) {
      NoConnectionError() => NetworkErrorType.noConnection,
      TimeoutError() => NetworkErrorType.timeout,
      AuthenticationError() => NetworkErrorType.unauthorized,
      ServerError(statusCode: final code) => switch (code) {
        404 => NetworkErrorType.notFound,
        >= 500 => NetworkErrorType.serverError,
        _ => NetworkErrorType.unknown,
      },
      ParseError() => NetworkErrorType.parseError,
      _ => NetworkErrorType.unknown,
    };
  }

  // Public API methods with context awareness
  static Future<ApiResponse<List<Post>>> getPosts({
    RequestContext context = RequestContext.userInitiated,
  }) async {
    return _makeRequest<List<Post>>(
      '/posts',
          (jsonData) => SafeJSONParser.parsePosts(jsonData).fold(
        onSuccess: (posts) => posts,
        onError: (error) => throw FormatException(error.message),
      ),
      context: context,
    );
  }

  static Future<ApiResponse<User>> getUser(
      int userId, {
        RequestContext context = RequestContext.userInitiated,
      }) async {
    return _makeRequest<User>(
      '/users/$userId',
          (jsonData) => SafeJSONParser.parseUser(jsonData).fold(
        onSuccess: (user) => user,
        onError: (error) => throw FormatException(error.message),
      ),
      context: context,
    );
  }

  static Future<ApiResponse<Photos>> getPhotos(
      int albumId, {
        RequestContext context = RequestContext.userInitiated,
      }) async {
    return _makeRequest<Photos>(
      '/photos/$albumId',
          (jsonData) => SafeJSONParser.parsePhotos(jsonData).fold(
        onSuccess: (photo) => photo,
        onError: (error) => throw FormatException(error.message),
      ),
      context: context,
    );
  }

  static Future<ApiResponse<Post>> createPost({
    required String title,
    required String body,
    required int userId,
    RequestContext context = RequestContext.userInitiated,
  }) async {
    return _makeRequest<Post>(
      '/posts',
          (jsonData) => Post.fromJson(jsonData as Map<String, dynamic>),
      method: 'POST',
      body: {
        'title': title,
        'body': body,
        'userId': userId,
      },
      context: context,
    );
  }

  // Cleanup
  static void dispose() {
    _client.close();
  }
}

// Enhanced result extensions for better handling
extension ParseResultExt<T> on ParseResult<T> {
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ParseError<T> error) onError,
  }) {
    return switch (this) {
      ParseSuccess<T>(data: final data) => onSuccess(data),
      ParseError<T> error => onError(error),
    };
  }
}
