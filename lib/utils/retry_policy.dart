import 'dart:async';
import 'dart:math';

/// Retry policy with exponential backoff for HTTP requests
class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Set<int> retryableStatusCodes;
  final Set<Type> retryableExceptions;

  RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryableExceptions = const {
      SocketException,
      TimeoutException,
      ClientException,
    },
  });

  /// Calculate delay with exponential backoff and jitter
  Duration getDelayForAttempt(int attemptNumber) {
    if (attemptNumber <= 0) return Duration.zero;

    var delay = initialDelay.inMilliseconds *
        pow(backoffMultiplier, attemptNumber - 1).toInt();

    // Add jitter (±20%)
    final jitter = delay * 0.2;
    delay = (delay + (Random().nextInt((jitter * 2).toInt()) - jitter)).toInt();

    // Cap at maxDelay
    return Duration(milliseconds: min(delay, maxDelay.inMilliseconds));
  }

  bool shouldRetry(dynamic error, int statusCode) {
    // Retry if it's a retryable exception type
    if (error != null) {
      for (final retryableType in retryableExceptions) {
        if (error.runtimeType == retryableType) {
          return true;
        }
      }
    }

    // Retry if it's a retryable status code
    if (statusCode > 0 && retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    return false;
  }
}

/// Wrapper for resilient HTTP calls with retries
class ResilientHttpClient {
  final RetryPolicy policy;
  final Duration defaultTimeout;

  ResilientHttpClient({
    RetryPolicy? policy,
    this.defaultTimeout = const Duration(seconds: 30),
  }) : policy = policy ?? RetryPolicy();

  /// Execute a request with automatic retries on failure
  Future<T> executeWithRetry<T>(
    Future<T> Function() request, {
    Duration? timeout,
    String? operationName,
  }) async {
    int attemptNumber = 0;
    dynamic lastError;
    int lastStatusCode = 0;

    while (attemptNumber < policy.maxRetries) {
      attemptNumber++;
      try {
        final effectiveTimeout = timeout ?? defaultTimeout;
        final response = await request().timeout(effectiveTimeout);
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        lastStatusCode = 408; // Treat timeout as 408

        if (!policy.shouldRetry(e, 408) ||
            attemptNumber >= policy.maxRetries) {
          rethrow;
        }

        _logRetryAttempt(
          operationName,
          attemptNumber,
          e,
          0,
          policy.getDelayForAttempt(attemptNumber),
        );

        await Future.delayed(policy.getDelayForAttempt(attemptNumber));
      } on SocketException catch (e) {
        lastError = e;
        lastStatusCode = 0;

        if (!policy.shouldRetry(e, 0) ||
            attemptNumber >= policy.maxRetries) {
          rethrow;
        }

        _logRetryAttempt(
          operationName,
          attemptNumber,
          e,
          0,
          policy.getDelayForAttempt(attemptNumber),
        );

        await Future.delayed(policy.getDelayForAttempt(attemptNumber));
      } catch (e) {
        // For other exceptions (including ApiException), check if retryable
        if (!policy.shouldRetry(e, 0) ||
            attemptNumber >= policy.maxRetries) {
          rethrow;
        }

        lastError = e;
        _logRetryAttempt(
          operationName,
          attemptNumber,
          e,
          0,
          policy.getDelayForAttempt(attemptNumber),
        );

        await Future.delayed(policy.getDelayForAttempt(attemptNumber));
      }
    }

    throw lastError ?? Exception('Request failed after $attemptNumber attempts');
  }

  void _logRetryAttempt(
    String? operationName,
    int attemptNumber,
    dynamic error,
    int statusCode,
    Duration delay,
  ) {
    final op = operationName ?? 'Request';
    debugPrint(
      '[$op] Attempt $attemptNumber failed: $error. '
      'Retrying in ${delay.inMilliseconds}ms...',
    );
  }
}

// Extension for enhanced error handling in ApiService
extension ApiServiceRetry on ApiService {
  /// Get a resilient HTTP client configured for the API service
  ResilientHttpClient getResilientClient() {
    return ResilientHttpClient(
      policy: RetryPolicy(
        maxRetries: 3,
        initialDelay: const Duration(milliseconds: 500),
        backoffMultiplier: 2.0,
      ),
      defaultTimeout: const Duration(seconds: 30),
    );
  }

  /// Execute with retry specifically for OCR operations (longer timeout)
  Future<Map<String, dynamic>> processOcrImageWithRetry(File file) async {
    final resilient = getResilientClient();
    return resilient.executeWithRetry(
      () => processOcrImage(file),
      timeout: const Duration(seconds: 60),
      operationName: 'OCR Processing',
    );
  }

  /// Execute with retry for question submission
  Future<Map<String, dynamic>> submitAnswersWithRetry({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final resilient = getResilientClient();
    return resilient.executeWithRetry(
      () => submitAnswers(attemptId: attemptId, answers: answers),
      timeout: const Duration(seconds: 30),
      operationName: 'Submit Answers',
    );
  }

  /// Execute with retry for login
  Future<Map<String, dynamic>> loginWithRetry(
    String phone,
    String password,
  ) async {
    final resilient = getResilientClient();
    return resilient.executeWithRetry(
      () => login(phone, password),
      timeout: const Duration(seconds: 20),
      operationName: 'Login',
    );
  }

  /// Execute with retry for fetching exams
  Future<List<exam.Exam>> fetchExamsWithRetry() async {
    final resilient = getResilientClient();
    return resilient.executeWithRetry(
      () => fetchExams(),
      timeout: const Duration(seconds: 20),
      operationName: 'Fetch Exams',
    );
  }
}
