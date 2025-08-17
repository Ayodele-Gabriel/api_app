// Modern cache architecture with multiple layers
enum CacheLayer {
  memory,      // Fastest - RAM cache
  storage,     // Fast - Local device storage
  network,     // Slowest - Remote server
}

enum CacheStrategy {
  cacheFirst,     // Check cache first, then network
  networkFirst,   // Check network first, fallback to cache
  cacheOnly,      // Only use cache (offline mode)
  networkOnly,    // Always use network (critical fresh data)
  staleWhileRevalidate, // Use cache immediately, update in background
}

// Cache metadata for intelligent decisions
class CacheMetadata {
  final DateTime createdAt;
  final DateTime lastAccessed;
  final DateTime expiresAt;
  final int accessCount;
  final String etag;
  final int sizeBytes;
  final CacheStrategy strategy;

  const CacheMetadata({
    required this.createdAt,
    required this.lastAccessed,
    required this.expiresAt,
    required this.accessCount,
    required this.etag,
    required this.sizeBytes,
    required this.strategy,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isStale => DateTime.now().isAfter(lastAccessed.add(Duration(hours: 1)));
  Duration get age => DateTime.now().difference(createdAt);

  CacheMetadata withAccess() {
    return CacheMetadata(
      createdAt: createdAt,
      lastAccessed: DateTime.now(),
      expiresAt: expiresAt,
      accessCount: accessCount + 1,
      etag: etag,
      sizeBytes: sizeBytes,
      strategy: strategy,
    );
  }
}

// Generic cache entry with metadata
class CacheEntry<T> {
  final String key;
  final T data;
  final CacheMetadata metadata;

  const CacheEntry({
    required this.key,
    required this.data,
    required this.metadata,
  });

  bool get isValid => !metadata.isExpired;
  bool get shouldRefresh => metadata.isStale;
}
