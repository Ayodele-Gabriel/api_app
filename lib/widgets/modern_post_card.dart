import 'package:api_app/models/photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../notifier/post_notifier.dart';
import '../notifier/user_notifier.dart';

class ModernPostCard extends ConsumerWidget {
  final Post post;
  final Photos photos;

  const ModernPostCard({super.key, required this.post, required this.photos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider(post.userId));
    final photoAsyncValue = ref.watch(userProvider(photos.albumId));
    final fallbackUrl = 'https://picsum.photos/100?random=${photos.id}';
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author section
            userAsyncValue.when(
              data:
                  (user) => Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (newContext) {
                              return AlertDialog(
                                title: Text('Image Details'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ImageDetailTile(
                                      title: 'AlbumID: ',
                                      photos: photos.albumId.toString(),
                                    ),
                                    ImageDetailTile(title: 'ID: ', photos: photos.id.toString()),
                                    ImageDetailTile(title: 'Title: ', photos: photos.title),
                                    ImageDetailTile(title: 'Url: ', photos: photos.url),
                                    ImageDetailTile(
                                      title: 'ThumbnailUrl: ',
                                      photos: photos.thumbnailUrl,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Image.network(
                          photos.url,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              fallbackUrl,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'delete':
                              await ref.read(postsProvider.notifier).removePost(post.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('🗑️ Post removed')));
                              }
                              break;
                          }
                        },
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
              loading:
                  () => Row(
                    children: [
                      CircleAvatar(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Loading author...'),
                    ],
                  ),
              error:
                  (error, _) => Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Unknown Author'),
                    ],
                  ),
            ),

            SizedBox(height: 16),

            // Post content
            Text(
              post.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
            ),

            SizedBox(height: 8),

            Text(post.body, style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey[700])),

            SizedBox(height: 16),

            // Post metadata
            Row(
              children: [
                Icon(Icons.article, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('Post #${post.id}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Spacer(),
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('User ${post.userId}', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ImageDetailTile extends StatelessWidget {
  const ImageDetailTile({super.key, required this.title, required this.photos});

  final String title;
  final String photos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
        Text(photos, style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
