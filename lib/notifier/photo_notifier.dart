// Modern AsyncNotifier for Posts
import 'package:api_app/models/photos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api/api_response.dart';

class PhotoAsyncNotifier extends AsyncNotifier<List<Photos>> {
  // Cache for offline support
  List<Photos>? _cachedPhotos;
  DateTime? _lastFetch;

  @override
  Future<List<Photos>> build() async {
    print('🧠 PhotoAsyncNotifier: Initializing...');

    // Check if we have recent cached data
    if (_cachedPhotos != null && _lastFetch != null) {
      final cacheAge = DateTime.now().difference(_lastFetch!);
      if (cacheAge.inMinutes < 5) {
        print('📦 Using cached photos (${cacheAge.inSeconds}s old)');
        return _cachedPhotos!;
      }
    }

    return _fetchPhotos();
  }

  // Private method to fetch photos
  Future<List<Photos>> _fetchPhotos() async {
    print('🌐 Fetching fresh photos from API...');

    final response = await ModernJSONPlaceholderService.getPhotos();

    return switch (response) {
      ApiSuccess<List<Photos>>(data: final photos) => () {
        _cachedPhotos = photos;
        _lastFetch = DateTime.now();
        print('✅ Successfully loaded ${photos.length} photos');
        return photos;
      }(),

      ApiError<List<Photos>>(message: final message, type: final type) => () {
        print('❌ Failed to load photos: $message');

        // Try to use cached data if available
        if (_cachedPhotos != null) {
          print('📦 Falling back to cached data');
          return _cachedPhotos!;
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
    state = await AsyncValue.guard(() => _fetchPhotos());
  }
}

// Create the provider using AsyncNotifierProvider
final photosProvider = AsyncNotifierProvider<PhotoAsyncNotifier, List<Photos>>(() {
  return PhotoAsyncNotifier();
});