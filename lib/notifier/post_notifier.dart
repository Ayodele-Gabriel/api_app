import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../network/api/api_response.dart';

// Modern AsyncNotifier for Posts
class PostsAsyncNotifier extends AsyncNotifier<List<Post>> {
  // Cache for offline support
  List<Post>? _cachedPosts;
  DateTime? _lastFetch;

  @override
  Future<List<Post>> build() async {
    print('🧠 PostsAsyncNotifier: Initializing...');

    // Check if we have recent cached data
    if (_cachedPosts != null && _lastFetch != null) {
      final cacheAge = DateTime.now().difference(_lastFetch!);
      if (cacheAge.inMinutes < 5) {
        print('📦 Using cached posts (${cacheAge.inSeconds}s old)');
        return _cachedPosts!;
      }
    }

    return _fetchPosts();
  }

  // Private method to fetch posts
  Future<List<Post>> _fetchPosts() async {
    print('🌐 Fetching fresh posts from API...');

    final response = await ModernJSONPlaceholderService.getPosts();

    return switch (response) {
      ApiSuccess<List<Post>>(data: final posts) => () {
        _cachedPosts = posts;
        _lastFetch = DateTime.now();
        print('✅ Successfully loaded ${posts.length} posts');
        return posts;
      }(),

      ApiError<List<Post>>(message: final message, type: final type) => () {
        print('❌ Failed to load posts: $message');

        // Try to use cached data if available
        if (_cachedPosts != null) {
          print('📦 Falling back to cached data');
          return _cachedPosts!;
        }

        // Convert API error to appropriate exception
        throw switch (type) {
          NetworkErrorType.noConnection => Exception('No internet connection. Please check your network and try again.'),
          NetworkErrorType.timeout => Exception('Request timed out. Please try again.'),
          NetworkErrorType.serverError => Exception('Server error. Please try again later.'),
          _ => Exception(message),
        };
      }(),
    };
  }

  // Refresh posts (user-triggered)
  Future<void> refresh() async {
    print('🔄 User requested refresh');

    // Set loading state while keeping current data visible
    state = await AsyncValue.guard(() => _fetchPosts());
  }

  // Add a new post (optimistic update)
  Future<void> addPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    print('➕ Adding new post: "$title"');

    // Optimistic update - add post immediately
    final currentPosts = state.value ?? [];
    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
      userId: userId,
      title: title,
      body: body,
    );

    // Update state optimistically
    state = AsyncValue.data([...currentPosts, newPost]);

    try {
      // Try to create post on server
      final response = await ModernJSONPlaceholderService.createPost(
        title: title,
        body: body,
        userId: userId,
      );

      switch (response) {
        case ApiSuccess<Post>(data: final createdPost):
          print('✅ Post created successfully with ID: ${createdPost.id}');

          // Update with real post from server
          final updatedPosts = currentPosts.map((post) {
            return post.id == newPost.id ? createdPost : post;
          }).toList();

          state = AsyncValue.data(updatedPosts);
          _cachedPosts = updatedPosts;

        case ApiError<Post>(message: final message):
          print('❌ Failed to create post: $message');

          // Revert optimistic update
          state = AsyncValue.data(currentPosts);
          throw Exception('Failed to create post: $message');
      }
    } catch (e) {
      // Revert optimistic update on any error
      state = AsyncValue.data(currentPosts);
      rethrow;
    }
  }

  // Remove a post
  Future<void> removePost(int postId) async {
    print('🗑️ Removing post #$postId');

    final currentPosts = state.value ?? [];
    final updatedPosts = currentPosts.where((post) => post.id != postId).toList();

    // Optimistic update
    state = AsyncValue.data(updatedPosts);
    _cachedPosts = updatedPosts;

    // Note: JSONPlaceholder doesn't actually delete posts,
    // but in a real app you would make a DELETE request here
  }

  // Search posts locally
  List<Post> searchPosts(String query) {
    final posts = state.value ?? [];
    if (query.isEmpty) return posts;

    final lowercaseQuery = query.toLowerCase();
    return posts.where((post) {
      return post.title.toLowerCase().contains(lowercaseQuery) ||
          post.body.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}

// Create the provider using AsyncNotifierProvider
final postsProvider = AsyncNotifierProvider<PostsAsyncNotifier, List<Post>>(() {
  return PostsAsyncNotifier();
});
