import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api/api_response.dart';
import '../network/api/api_service.dart';
import '../network/retry/retry_manager.dart';

// Offline state management
class OfflineManager {
  static const String _offlineModeKey = 'offline_mode_enabled';
  static const String _pendingActionsKey = 'pending_offline_actions';

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  final StreamController<bool> _offlineModeController = StreamController<bool>.broadcast();

  bool _isConnected = true;
  bool _isOfflineModeEnabled = false;
  Timer? _connectivityTimer;

  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<bool> get offlineModeStream => _offlineModeController.stream;

  bool get isConnected => _isConnected;
  bool get isOfflineModeEnabled => _isOfflineModeEnabled;
  bool get isEffectivelyOffline => !_isConnected || _isOfflineModeEnabled;

  Future<void> initialize() async {
    await _loadOfflineMode();
    _startConnectivityMonitoring();
    print('🌐 OfflineManager initialized');
  }

  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isOfflineModeEnabled = prefs.getBool(_offlineModeKey) ?? false;
    _offlineModeController.add(_isOfflineModeEnabled);
  }

  void _startConnectivityMonitoring() {
    _connectivityTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      final wasConnected = _isConnected;
      _isConnected = await _checkConnectivity();

      if (wasConnected != _isConnected) {
        _connectivityController.add(_isConnected);

        if (_isConnected) {
          print('🌐 Connection restored');
          await _processPendingActions();
        } else {
          print('📵 Connection lost');
        }
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      ).timeout(Duration(seconds: 3));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> enableOfflineMode() async {
    _isOfflineModeEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, true);
    _offlineModeController.add(true);
    print('📴 Offline mode enabled');
  }

  Future<void> disableOfflineMode() async {
    _isOfflineModeEnabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, false);
    _offlineModeController.add(false);
    await _processPendingActions();
    print('🌐 Offline mode disabled');
  }

  // Queue actions for later when offline
  Future<void> queueAction(OfflineAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final existingActions = prefs.getStringList(_pendingActionsKey) ?? [];

    existingActions.add(json.encode(action.toJson()));
    await prefs.setStringList(_pendingActionsKey, existingActions);

    print('⏳ Queued offline action: ${action.type} ${action.id}');
  }

  Future<void> _processPendingActions() async {
    if (isEffectivelyOffline) return;

    final prefs = await SharedPreferences.getInstance();
    final actionJsonList = prefs.getStringList(_pendingActionsKey) ?? [];

    if (actionJsonList.isEmpty) return;

    print('🔄 Processing ${actionJsonList.length} pending actions');

    final successfulActions = <String>[];

    for (final actionJson in actionJsonList) {
      try {
        final actionMap = json.decode(actionJson) as Map<String, dynamic>;
        final action = OfflineAction.fromJson(actionMap);

        final success = await _executeAction(action);
        if (success) {
          successfulActions.add(actionJson);
        }
      } catch (e) {
        print('❌ Failed to process action: $e');
      }
    }

    // Remove successful actions from queue
    if (successfulActions.isNotEmpty) {
      final remainingActions = actionJsonList
          .where((action) => !successfulActions.contains(action))
          .toList();

      await prefs.setStringList(_pendingActionsKey, remainingActions);
      print('✅ Processed ${successfulActions.length} actions, ${remainingActions.length} remaining');
    }
  }

  Future<bool> _executeAction(OfflineAction action) async {
    return switch (action.type) {
      OfflineActionType.createPost => _executeCreatePost(action),
      OfflineActionType.updatePost => _executeUpdatePost(action),
      OfflineActionType.deletePost => _executeDeletePost(action),
      _ => false,
    };
  }

  Future<bool> _executeCreatePost(OfflineAction action) async {
    try {
      final response = await ProfessionalJSONPlaceholderService.createPost(
        title: action.data['title'],
        body: action.data['body'],
        userId: action.data['userId'],
        context: RequestContext.background,
      );

      return switch (response) {
        ApiSuccess() => true,
        ApiError() => false,
      };
    } catch (e) {
      return false;
    }
  }

  Future<bool> _executeUpdatePost(OfflineAction action) async {
    // Implementation for update
    return true; // Placeholder
  }

  Future<bool> _executeDeletePost(OfflineAction action) async {
    // Implementation for delete
    return true; // Placeholder
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
    _offlineModeController.close();
  }
}

class OfflineAction {
  final String id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  const OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory OfflineAction.fromJson(Map<String, dynamic> json) {
    return OfflineAction(
      id: json['id'],
      type: OfflineActionType.values.byName(json['type']),
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }
}

enum OfflineActionType { createPost, updatePost, deletePost }
