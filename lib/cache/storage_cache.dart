import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'cache_layer.dart';

class PersistentStorageCache {
  static const String _cachePrefix = 'app_cache_';
  static const String _metadataPrefix = 'cache_meta_';

  // Store data to device storage with compression
  Future<void> put<T>(
      String key,
      T data, {
        Duration? ttl,
        bool compress = true,
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Serialize data
      String serializedData;
      if (data is String) {
        serializedData = data;
      } else if (data is Map || data is List) {
        serializedData = json.encode(data);
      } else {
        serializedData = data.toString();
      }

      // Compress if requested and beneficial
      if (compress && serializedData.length > 1024) {
        final bytes = utf8.encode(serializedData);
        final compressed = gzip.encode(bytes);

        if (compressed.length < bytes.length * 0.8) {
          // Only use compression if it saves at least 20%
          await prefs.setString('${_cachePrefix}compressed_$key', base64.encode(compressed));
          await _storeMetadata(key, serializedData.length, compressed.length, true, ttl);
          print('💾 Storage cached (compressed): $key (${bytes.length} → ${compressed.length} bytes)');
          return;
        }
      }

      // Store uncompressed
      await prefs.setString('$_cachePrefix$key', serializedData);
      await _storeMetadata(key, serializedData.length, serializedData.length, false, ttl);

      print('💾 Storage cached: $key (${serializedData.length} bytes)');

    } catch (e) {
      print('❌ Storage cache put failed for $key: $e');
    }
  }

  // Retrieve data from device storage
  Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = await _getMetadata(key);

      // Check if expired
      if (metadata != null && metadata.isExpired) {
        await remove(key);
        return null;
      }

      // Try compressed version first
      String? data = prefs.getString('${_cachePrefix}compressed_$key');
      bool wasCompressed = false;

      if (data != null) {
        // Decompress
        try {
          final compressed = base64.decode(data);
          final decompressed = gzip.decode(compressed);
          data = utf8.decode(decompressed);
          wasCompressed = true;
        } catch (e) {
          print('❌ Decompression failed for $key: $e');
          data = null;
        }
      }

      // Fallback to uncompressed
      data ??= prefs.getString('$_cachePrefix$key');

      if (data == null) return null;

      // Update access time
      if (metadata != null) {
        await _updateAccessTime(key);
      }

      print('💾 Storage hit: $key${wasCompressed ? ' (decompressed)' : ''}');

      // Parse based on expected type
      if (T == String) return data as T;
      if (T == List || T.toString().startsWith('List')) {
        return json.decode(data) as T;
      }
      if (T == Map || T.toString().startsWith('Map')) {
        return json.decode(data) as T;
      }

      // Try JSON decode as fallback
      try {
        return json.decode(data) as T;
      } catch (e) {
        return data as T;
      }

    } catch (e) {
      print('❌ Storage cache get failed for $key: $e');
      return null;
    }
  }

  Future<void> _storeMetadata(
      String key,
      int originalSize,
      int storedSize,
      bool compressed,
      Duration? ttl,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final metadata = {
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
      'expiresAt': ttl != null
          ? DateTime.now().add(ttl).millisecondsSinceEpoch
          : DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch,
      'originalSize': originalSize,
      'storedSize': storedSize,
      'compressed': compressed,
      'accessCount': 1,
    };

    await prefs.setString('$_metadataPrefix$key', json.encode(metadata));
  }

  Future<CacheMetadata?> _getMetadata(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString('$_metadataPrefix$key');
      if (metadataJson == null) return null;

      final metadata = json.decode(metadataJson) as Map<String, dynamic>;

      return CacheMetadata(
        createdAt: DateTime.fromMillisecondsSinceEpoch(metadata['createdAt']),
        lastAccessed: DateTime.fromMillisecondsSinceEpoch(metadata['lastAccessed']),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(metadata['expiresAt']),
        accessCount: metadata['accessCount'] ?? 1,
        etag: '',
        sizeBytes: metadata['storedSize'] ?? 0,
        strategy: CacheStrategy.cacheFirst,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateAccessTime(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final metadataJson = prefs.getString('$_metadataPrefix$key');
    if (metadataJson == null) return;

    try {
      final metadata = json.decode(metadataJson) as Map<String, dynamic>;
      metadata['lastAccessed'] = DateTime.now().millisecondsSinceEpoch;
      metadata['accessCount'] = (metadata['accessCount'] ?? 0) + 1;

      await prefs.setString('$_metadataPrefix$key', json.encode(metadata));
    } catch (e) {
      print('❌ Failed to update access time for $key: $e');
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$key');
    await prefs.remove('${_cachePrefix}compressed_$key');
    await prefs.remove('$_metadataPrefix$key');
    print('🗑️ Storage cache removed: $key');
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
            (key) => key.startsWith(_cachePrefix) || key.startsWith(_metadataPrefix)
    ).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    print('🗑️ Storage cache cleared (${keys.length} entries)');
  }

  // Clean up expired entries
  Future<void> cleanup() async {
    final prefs = await SharedPreferences.getInstance();
    final metadataKeys = prefs.getKeys()
        .where((key) => key.startsWith(_metadataPrefix))
        .toList();

    int removedCount = 0;

    for (final metadataKey in metadataKeys) {
      final key = metadataKey.substring(_metadataPrefix.length);
      final metadata = await _getMetadata(key);

      if (metadata != null && metadata.isExpired) {
        await remove(key);
        removedCount++;
      }
    }

    print('🧹 Storage cache cleanup: removed $removedCount expired entries');
  }
}
