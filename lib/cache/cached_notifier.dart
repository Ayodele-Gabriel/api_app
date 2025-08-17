import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import '../network/api/api_response.dart';

class CachedPostsNotifier extends AsyncNotifier<List<Post>> {
  static const String _cacheKey = 'cached_posts';
  static const Duration _cacheExpiry = Duration(hours: 1);

  @override
  Future<List<Post>> build() async {
    // Try to load from cache first
    final cachedData = await _loadFromCache();
    if (cachedData != null) {
      // Return cached data immediately, then refresh in background
      Future.microtask(() => _refreshIfNeeded());
      return cachedData;
    }

    return _fetchAndCache();
  }

  Future<List<Post>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt('${_cacheKey}_time');

      if (cachedJson != null && cacheTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (cacheAge < _cacheExpiry.inMilliseconds) {
          final List<dynamic> jsonList = json.decode(cachedJson);
          return jsonList.map((item) => Post.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('❌ Failed to load from cache: $e');
    }

    return null;
  }

  Future<List<Post>> _fetchAndCache() async {
    final response = await ModernJSONPlaceholderService.getPosts();

    return switch (response) {
      ApiSuccess(data: final posts) => () async {
        await _saveToCache(posts);
        return posts;
      }(),
      ApiError(message: final message) => throw Exception(message),
    };
  }

  Future<void> _saveToCache(List<Post> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(posts.map((post) => post.toJson()).toList());

      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt('${_cacheKey}_time', DateTime.now().millisecondsSinceEpoch);

      print('💾 Cached ${posts.length} posts');
    } catch (e) {
      print('❌ Failed to save to cache: $e');
    }
  }

  Future<void> _refreshIfNeeded() async {
    try {
      final posts = await _fetchAndCache();
      state = AsyncValue.data(posts);
    } catch (e) {
      // Don't update state on background refresh failure
      print('❌ Background refresh failed: $e');
    }
  }
}
