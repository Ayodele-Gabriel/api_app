import 'package:api_app/models/photos.dart';
import 'package:api_app/notifier/photo_notifier.dart';
import 'package:api_app/notifier/post_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered posts provider (derived state)
final filteredPostsProvider = Provider<List<Post>>((ref) {
  final postsAsyncValue = ref.watch(postsProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return switch (postsAsyncValue) {
    AsyncData(value: final posts) => () {
      if (searchQuery.isEmpty) return posts;

      final lowercaseQuery = searchQuery.toLowerCase();
      return posts.where((post) {
        return post.title.toLowerCase().contains(lowercaseQuery) ||
            post.body.toLowerCase().contains(lowercaseQuery);
      }).toList();
    }(),
    _ => <Post>[],
  };
});

// Posts count by user provider
final postsCountByUserProvider = Provider<Map<int, int>>((ref) {
  final postsAsyncValue = ref.watch(postsProvider);

  return switch (postsAsyncValue) {
    AsyncData(value: final posts) => () {
      final countMap = <int, int>{};
      for (final post in posts) {
        countMap[post.userId] = (countMap[post.userId] ?? 0) + 1;
      }
      return countMap;
    }(),
    _ => <int, int>{},
  };
});

// User posts provider (posts by specific user)
final userPostsProvider = Provider.family<List<Post>, int>((ref, userId) {
  final postsAsyncValue = ref.watch(postsProvider);

  return switch (postsAsyncValue) {
    AsyncData(value: final posts) =>
        posts.where((post) => post.userId == userId).toList(),
    _ => <Post>[],
  };
});
