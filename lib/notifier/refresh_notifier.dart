import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../network/api/api_response.dart';

class AutoRefreshPostsNotifier extends AsyncNotifier<List<Post>> {
  Timer? _refreshTimer;

  @override
  Future<List<Post>> build() async {
    // Start auto-refresh timer
    _startAutoRefresh();

    // Setup cleanup
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    return _fetchPosts();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (state.hasValue && !state.isLoading) {
        refresh();
      }
    });
  }

  Future<List<Post>> _fetchPosts() async {
    final response = await ModernJSONPlaceholderService.getPosts();

    return switch (response) {
      ApiSuccess(data: final posts) => posts,
      ApiError(message: final message) => throw Exception(message),
    };
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _fetchPosts());
  }
}

final autoRefreshPostsProvider = AsyncNotifierProvider<AutoRefreshPostsNotifier, List<Post>>(() {
  return AutoRefreshPostsNotifier();
});
