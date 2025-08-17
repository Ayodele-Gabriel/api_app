import 'cache_layer.dart';

class SmartMemoryCache {
  final Map<String, CacheEntry> _cache = {};
  final int maxSizeBytes;
  final int maxEntries;
  int _currentSizeBytes = 0;

  SmartMemoryCache({
    this.maxSizeBytes = 50 * 1024 * 1024, // 50MB
    this.maxEntries = 1000,
  });

  // Store data with intelligent eviction
  Future<void> put<T>(
      String key,
      T data, {
        Duration? ttl,
        CacheStrategy strategy = CacheStrategy.cacheFirst,
      }) async {
    final sizeBytes = _calculateSize(data);

    // Check if we need to make space
    if (_needsEviction(sizeBytes)) {
      await _evictLeastValuable(sizeBytes);
    }

    final metadata = CacheMetadata(
      createdAt: DateTime.now(),
      lastAccessed: DateTime.now(),
      expiresAt: ttl != null
          ? DateTime.now().add(ttl)
          : DateTime.now().add(Duration(hours: 24)),
      accessCount: 1,
      etag: _generateETag(data),
      sizeBytes: sizeBytes,
      strategy: strategy,
    );

    final entry = CacheEntry(
      key: key,
      data: data,
      metadata: metadata,
    );

    _cache[key] = entry;
    _currentSizeBytes += sizeBytes;

    print('💾 Memory cached: $key (${_formatBytes(sizeBytes)}, total: ${_formatBytes(_currentSizeBytes)})');
  }

  // Retrieve data with usage tracking
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check if expired
    if (!entry.isValid) {
      remove(key);
      return null;
    }

    // Update access metadata
    _cache[key] = CacheEntry(
      key: entry.key,
      data: entry.data,
      metadata: entry.metadata.withAccess(),
    );

    print('💾 Memory hit: $key (accessed ${entry.metadata.accessCount + 1} times)');
    return entry.data as T;
  }

  bool _needsEviction(int newItemSize) {
    return _cache.length >= maxEntries ||
        _currentSizeBytes + newItemSize > maxSizeBytes;
  }

  // Smart eviction using LRU + size + access frequency
  Future<void> _evictLeastValuable(int neededBytes) async {
    final entries = _cache.values.toList();

    // Sort by value score (lower = less valuable)
    entries.sort((a, b) {
      final scoreA = _calculateValueScore(a);
      final scoreB = _calculateValueScore(b);
      return scoreA.compareTo(scoreB);
    });

    int freedBytes = 0;
    final keysToRemove = <String>[];

    for (final entry in entries) {
      keysToRemove.add(entry.key);
      freedBytes += entry.metadata.sizeBytes;

      if (freedBytes >= neededBytes) break;
    }

    for (final key in keysToRemove) {
      remove(key);
    }

    print('🗑️ Evicted ${keysToRemove.length} entries, freed ${_formatBytes(freedBytes)}');
  }

  // Calculate value score for eviction decisions
  double _calculateValueScore(CacheEntry entry) {
    final age = entry.metadata.age.inMinutes;
    final accessCount = entry.metadata.accessCount;
    final size = entry.metadata.sizeBytes;
    final timeSinceAccess = DateTime.now().difference(entry.metadata.lastAccessed).inMinutes;

    // Higher score = more valuable (keep longer)
    // Lower score = less valuable (evict first)
    return (accessCount * 10) - (age * 0.1) - (timeSinceAccess * 0.5) - (size / 1024);
  }

  void remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.metadata.sizeBytes;
    }
  }

  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
    print('🗑️ Memory cache cleared');
  }

  // Cache statistics
  CacheStats get stats {
    final now = DateTime.now();
    int expiredCount = 0;
    int staleCount = 0;

    for (final entry in _cache.values) {
      if (entry.metadata.isExpired) expiredCount++;
      if (entry.metadata.isStale) staleCount++;
    }

    return CacheStats(
      totalEntries: _cache.length,
      totalSizeBytes: _currentSizeBytes,
      expiredEntries: expiredCount,
      staleEntries: staleCount,
      hitRate: 0.0, // Would need to track hits/misses
    );
  }

  int _calculateSize(dynamic data) {
    // Simplified size calculation
    if (data is String) return data.length * 2; // UTF-16
    if (data is List) return data.length * 100; // Rough estimate
    if (data is Map) return data.length * 200; // Rough estimate
    return 1024; // Default 1KB
  }

  String _generateETag(dynamic data) {
    return data.hashCode.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class CacheStats {
  final int totalEntries;
  final int totalSizeBytes;
  final int expiredEntries;
  final int staleEntries;
  final double hitRate;

  const CacheStats({
    required this.totalEntries,
    required this.totalSizeBytes,
    required this.expiredEntries,
    required this.staleEntries,
    required this.hitRate,
  });
}
