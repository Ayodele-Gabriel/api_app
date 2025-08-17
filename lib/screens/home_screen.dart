import 'package:api_app/models/photos.dart';
import 'package:api_app/notifier/photo_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../network/api/api_response.dart';
import '../network/errors/error_widget.dart';
import '../notifier/post_notifier.dart';
import '../notifier/provider.dart';
import '../widgets/modern_post_card.dart';

class ModernPostsScreen extends ConsumerWidget {
  const ModernPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(postsProvider);
    final photosAsyncValue = ref.watch(photosProvider);
    final filteredPosts = ref.watch(filteredPostsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Modern Posts'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              // Trigger refresh using the notifier
              try {
                await ref.read(postsProvider.notifier).refresh();
                await ref.read(photosProvider.notifier).refresh();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Refreshed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Failed to refresh: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          IconButton(icon: Icon(Icons.add), onPressed: () => _showAddPostDialog(context, ref)),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Search posts...',
                prefixIcon: Icon(Icons.search),
                suffixIcon:
                    searchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                        : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Posts content
          Expanded(
            child: postsAsyncValue.when(
              data: (posts) => photosAsyncValue.when(
                data: (photos) => _buildPostsList(context, ref, filteredPosts, photos),
                loading: () => _buildLoadingState(),
                error: (error, stackTrace) => _buildErrorState(context, ref, error),
              ),
              loading: () => _buildLoadingState(),
              error: (error, stackTrace) => _buildErrorState(context, ref, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(BuildContext context, WidgetRef ref, List<Post> posts, List<Photos> photos) {
    if (posts.isEmpty) {
      final searchQuery = ref.watch(searchQueryProvider);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.article_outlined : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              searchQuery.isEmpty ? 'No posts available' : 'No posts found for "$searchQuery"',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(searchQueryProvider.notifier).state = '';
                },
                child: Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(postsProvider.notifier).refresh();
        await ref.read(photosProvider.notifier).refresh();
      },
      child: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final photo = (index < photos.length) ? photos[index] : null;
          return ModernPostCard(post: post, photos: photo!);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('🧠 Loading posts...'),
          SizedBox(height: 8),
          Text('This usually takes just a moment', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return ModernErrorWidget(
      error: ApiError(message: error.toString(), type: NetworkErrorType.unknown),
      onRetry: () async {
        try {
          await ref.read(postsProvider.notifier).refresh();
          await ref.read(photosProvider.notifier).refresh();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to retry: $e')));
          }
        }
      },
    );
  }

  void _showAddPostDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('✍️ Create New Post'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: bodyController,
                  decoration: InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Please enter a title')));
                    return;
                  }

                  try {
                    await ref
                        .read(postsProvider.notifier)
                        .addPost(
                          title: titleController.text.trim(),
                          body: bodyController.text.trim(),
                          userId: 1, // Default user
                        );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Post created successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to create post: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text('Create'),
              ),
            ],
          ),
    );
  }
}
