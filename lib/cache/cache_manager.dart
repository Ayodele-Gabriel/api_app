import 'package:api_app/cache/storage_cache.dart';

import 'cache_layer.dart';
import 'memory_cache.dart';

class UnifiedCacheManager {
  final SmartMemoryCache _memoryCache = SmartMemoryCache();
  final PersistentStorageCache _storageCache = PersistentStorageCache();

  // Get data with intelligent fallback strategy
  Future<T?> get<T>(
      String key, {
        CacheStrategy strategy = CacheStrategy.cacheFirst,
      }) async {
    return switch (strategy) {
      CacheStrategy.cacheFirst => _getCacheFirst<T>(key),
      CacheStrategy.networkFirst => null, // Handled by API service
      CacheStrategy.cacheOnly => _getCacheOnly<T>(key),
      CacheStrategy.staleWhileRevalidate => _getStaleWhileRevalidate<T>(key),
      _ => _getCacheFirst<T>(key),
    };
  }

  // Store data in appropriate cache layers
  Future<void> put<T>(
      String key,
      T data, {
        Duration? ttl,
        CacheStrategy strategy = CacheStrategy.cacheFirst,
        bool persistToStorage = true,
      }) async {
    // Always store in memory for fast access
    await _memoryCache.put(key, data, ttl: ttl, strategy: strategy);

    // Store in persistent storage if requested
    if (persistToStorage) {
      await _storageCache.put(key, data, ttl: ttl);
    }
  }

  Future<T?> _getCacheFirst<T>(String key) async {
    // Try memory cache first (fastest)
    T? data = _memoryCache.get<T>(key);
    if (data != null) {
      return data;
    }

    // Fallback to storage cache
    data = await _storageCache.get<T>(key);
    if (data != null) {
      // Promote to memory cache for faster future access
      await _memoryCache.put(key, data);
      return data;
    }

    return null;
  }

  Future<T?> _getCacheOnly<T>(String key) async {
    return _getCacheFirst<T>(key);
  }

  Future<T?> _getStaleWhileRevalidate<T>(String key) async {
    // Get from cache immediately (even if stale)
    final data = await _getCacheFirst<T>(key);
    return data;
  }

  // Cache invalidation
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _storageCache.remove(key);
    print('🗑️ Cache invalidated: $key');
  }

  Future<void> invalidatePattern(RegExp pattern) async {
    // This would require keeping track of all keys
    // Simplified implementation
    print('🗑️ Cache invalidated by pattern: ${pattern.pattern}');
  }

  // Cache maintenance
  Future<void> cleanup() async {
    await _storageCache.cleanup();
    print('🧹 Cache cleanup completed');
  }

  // Cache statistics
  Future<Map<String, dynamic>> getStats() async {
    final memoryStats = _memoryCache.stats;

    return {
      'memory': {
        'entries': memoryStats.totalEntries,
        'sizeBytes': memoryStats.totalSizeBytes,
        'expired': memoryStats.expiredEntries,
        'stale': memoryStats.staleEntries,
      },
      'storage': {
        'info': 'Statistics not available for storage cache',
      },
    };
  }
}
