// Enhanced error widget with pattern matching
import 'package:flutter/material.dart';

import '../api/api_response.dart';

class ModernErrorWidget extends StatelessWidget {
  final ApiError error;
  final VoidCallback? onRetry;

  const ModernErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, suggestions) = switch (error.type) {
      NetworkErrorType.noConnection => (
      Icons.wifi_off,
      Colors.blue,
      'No Internet Connection',
      [
        'Check your WiFi or mobile data',
        'Move to an area with better signal',
        'Try again in a moment',
      ]
      ),

      NetworkErrorType.timeout => (
      Icons.access_time,
      Colors.orange,
      'Request Timed Out',
      [
        'Check your internet speed',
        'Try again with a better connection',
        'The server might be slow',
      ]
      ),

      NetworkErrorType.notFound => (
      Icons.search_off,
      Colors.grey,
      'Content Not Found',
      [
        'The requested content may have been removed',
        'Check if you have the correct information',
        'Try refreshing the page',
      ]
      ),

      NetworkErrorType.unauthorized => (
      Icons.lock,
      Colors.red,
      'Access Denied',
      [
        'You may need to log in',
        'Check your permissions',
        'Contact support if this persists',
      ]
      ),

      NetworkErrorType.serverError => (
      Icons.error_outline,
      Colors.purple,
      'Server Error',
      [
        'The server is experiencing issues',
        'Try again in a few minutes',
        'Contact support if this continues',
      ]
      ),

      NetworkErrorType.parseError => (
      Icons.code_off,
      Colors.amber,
      'Data Format Error',
      [
        'The server returned invalid data',
        'Try refreshing to get fresh data',
        'Report this issue if it persists',
      ]
      ),

      _ => (
      Icons.warning,
      Colors.grey,
      'Something Went Wrong',
      [
        'An unexpected error occurred',
        'Try again later',
        'Contact support if needed',
      ]
      ),
    };

    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          SizedBox(height: 16),

          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 8),
          Text(
            error.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 16),

          // Recovery suggestions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Try these solutions:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...suggestions.map((suggestion) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color)),
                        Expanded(child: Text(suggestion)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          if (onRetry != null)
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}
