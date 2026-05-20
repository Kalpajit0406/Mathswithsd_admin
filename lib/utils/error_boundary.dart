import 'dart:ui';
import 'package:flutter/material.dart';

/// Global error handler for uncaught exceptions
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final VoidCallback? onError;

  const ErrorBoundary({
    required this.child,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    
    // Catch all Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _hasError = true;
        _errorDetails = details;
      });
      debugPrint('Flutter Error: ${details.exceptionAsString()}\n'
          'Error: ${details.exception}\n'
          'StackTrace: ${details.stack}');
      widget.onError?.call();
    };

    // Catch platform channel errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Platform Error: $error\nStackTrace: $stack');
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Error Occurred'),
            centerTitle: true,
          ),
          body: Center(
            child: ErrorDisplayWidget(
              error: _errorDetails?.exceptionAsString() ?? 'Unknown error',
              onRetry: () => setState(() => _hasError = false),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Displays error with retry option
class ErrorDisplayWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final String? suggestion;

  const ErrorDisplayWidget({
    required this.error,
    required this.onRetry,
    this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red[900],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (suggestion != null) ...[
            const SizedBox(height: 16),
            Text(
              suggestion!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider-level error handler
class ErrorNotifier extends ChangeNotifier {
  String? _lastError;
  DateTime? _lastErrorTime;

  String? get lastError => _lastError;
  bool get hasError => _lastError != null;

  void setError(String error) {
    _lastError = error;
    _lastErrorTime = DateTime.now();
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    _lastErrorTime = null;
    notifyListeners();
  }

  bool shouldShowError() {
    if (_lastErrorTime == null) return false;
    // Don't show same error twice within 2 seconds
    return DateTime.now().difference(_lastErrorTime!).inSeconds > 2;
  }
}

/// Wrapper for safe async operations
extension SafeAsync on Future {
  Future<T?> safeExecute<T>({
    required BuildContext context,
    required ErrorNotifier errorNotifier,
    String? operationName,
  }) async {
    try {
      return await this as T;
    } catch (e) {
      final message = '$operationName failed: ${e.toString()}';
      errorNotifier.setError(message);
      
      // Show snackbar if context still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () => errorNotifier.clearError(),
            ),
          ),
        );
      }
      return null;
    }
  }
}
