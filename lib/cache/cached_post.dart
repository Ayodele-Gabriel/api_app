import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../network/api/api_response.dart';
import '../network/api/api_service.dart';
import '../network/retry/retry_manager.dart';
import '../offline_manager/offline_manager.dart';
import 'cache_layer.dart';
import 'cache_manager.dart';

class CachedPostsAsyncNotifier extends AsyncNotifier<List<Post>> {
  final UnifiedCacheManager _cacheManager = UnifiedCacheManager();
  final OfflineManager _offlineManager = OfflineManager();

  static const String _postsKey = 'posts_list';

  @override
  Future<List<Post>> build() async {
    // Initialize offline manager
    await _offlineManager.initialize();

    // Setup connectivity listeners
    _setupConnectivityListeners();

    return _loadPosts();
  }

  void _setupConnectivityListeners() {
    _offlineManager.connectivityStream.listen((isConnected) {
      if (isConnected && state.hasValue) {
        // Refresh data when connection is restored
        refresh();
      }
    });
  }

  Future<List<Post>> _loadPosts() async {
    // Try cache first if offline or cache-first strategy
    if (_offlineManager.isEffectivelyOffline) {
      final cachedPosts = await _cacheManager.get<List<dynamic>>(_postsKey);
      if (cachedPosts != null) {
        print('📦 Using cached posts (offline mode)');
        return cachedPosts.map((json) => Post.fromJson(json)).toList();
      }

      throw Exception('No cached data available and device is offline');
    }

    // Try cache first, then network
    final cachedPosts = await _cacheManager.get<List<dynamic>>(
      _postsKey,
      strategy: CacheStrategy.cacheFirst,
    );

    if (cachedPosts != null) {
      print('📦 Using cached posts, refreshing in background');

      // Return cached data immediately
      final posts = cachedPosts.map((json) => Post.fromJson(json)).toList();

      // Refresh in background
      _refreshInBackground();

      return posts;
    }

    // No cache, fetch from network
    return _fetchFromNetwork();
  }

  Future<List<Post>> _fetchFromNetwork() async {
    final response = await ProfessionalJSONPlaceholderService.getPosts(
      context: RequestContext.userInitiated,
    );

    return switch (response) {
      ApiSuccess<List<Post>>(data: final posts) => () async {
        // Cache the fresh data
        final jsonList = posts.map((post) => post.toJson()).toList();
        await _cacheManager.put(
          _postsKey,
          jsonList,
          ttl: Duration(hours: 2),
        );

        print('✅ Fetched and cached ${posts.length} posts');
        return posts;
      }(),

      ApiError<List<Post>>(message: final message) => () {
        print('❌ Network fetch failed: $message');
        throw Exception(message);
      }(),
    };
  }

  Future<void> _refreshInBackground() async {
    try {
      final posts = await _fetchFromNetwork();

      // Update state with fresh data
      state = AsyncValue.data(posts);
    } catch (e) {
      // Don't update state on background refresh failure
      print('⚠️ Background refresh failed: $e');
    }
  }

  // User-triggered refresh
  Future<void> refresh() async {
    if (_offlineManager.isEffectivelyOffline) {
      throw Exception('Cannot refresh while offline');
    }

    state = const AsyncValue.loading();

    try {
      final posts = await _fetchFromNetwork();
      state = AsyncValue.data(posts);
    } catch (e) {
      // Try to fallback to cache on refresh failure
      final cachedPosts = await _cacheManager.get<List<dynamic>>(_postsKey);
      if (cachedPosts != null) {
        final posts = cachedPosts.map((json) => Post.fromJson(json)).toList();
        state = AsyncValue.data(posts);

        // Show error as snackbar instead of full error state
        throw RefreshFailedException('Refresh failed, showing cached data');
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  // Add post with offline support
  Future<void> addPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    final currentPosts = state.value ?? [];

    // Create temporary post for optimistic update
    final tempPost = Post(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: userId,
      title: title,
      body: body,
    );

    // Optimistic update
    state = AsyncValue.data([...currentPosts, tempPost]);

    if (_offlineManager.isEffectivelyOffline) {
      // Queue for later when online
      await _offlineManager.queueAction(OfflineAction(
        id: tempPost.id.toString(),
        type: OfflineActionType.createPost,
        data: {
          'title': title,
          'body': body,
          'userId': userId,
        },
        createdAt: DateTime.now(),
      ));

      // Update cache with optimistic data
      final updatedList = [...currentPosts, tempPost];
      final jsonList = updatedList.map((post) => post.toJson()).toList();
      await _cacheManager.put(_postsKey, jsonList);

      print('⏳ Post queued for sync when online');
      return;
    }

    // Try to create on server
    try {
      final response = await ProfessionalJSONPlaceholderService.createPost(
        title: title,
        body: body,
        userId: userId,
        context: RequestContext.userInitiated,
      );

      switch (response) {
        case ApiSuccess<Post>(data: final createdPost):
        // Replace temporary post with real post
          final updatedPosts = currentPosts.map((post) {
            return post.id == tempPost.id ? createdPost : post;
          }).toList();

          state = AsyncValue.data(updatedPosts);

          // Update cache
          final jsonList = updatedPosts.map((post) => post.toJson()).toList();
          await _cacheManager.put(_postsKey, jsonList);

        case ApiError<Post>():
        // Revert optimistic update
          state = AsyncValue.data(currentPosts);
          throw Exception('Failed to create post');
      }
    } catch (e) {
      // Revert optimistic update
      state = AsyncValue.data(currentPosts);
      rethrow;
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    await _cacheManager.invalidate(_postsKey);
    print('🗑️ Posts cache cleared');
  }

  // Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return _cacheManager.getStats();
  }
}

class RefreshFailedException implements Exception {
  final String message;
  RefreshFailedException(this.message);

  @override
  String toString() => 'RefreshFailedException: $message';
}

// Updated provider
final cachedPostsProvider = AsyncNotifierProvider<CachedPostsAsyncNotifier, List<Post>>(() {
  return CachedPostsAsyncNotifier();
});
