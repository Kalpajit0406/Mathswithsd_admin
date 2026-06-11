import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' show ClientException;
import '../services/api_service.dart';

/// Converts raw exceptions and status codes into user-friendly messages.
String friendlyNetworkError(dynamic error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The server encountered an issue. Please try again in a few moments.';
      default:
        if (error.message.isNotEmpty) return error.message;
        return 'An unexpected error occurred (${error.statusCode}). Please try again.';
    }
  }
  if (error is SocketException) {
    return 'Unable to connect to the server. Please check your internet connection.';
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please check your connection and try again.';
  }
  if (error is ClientException) {
    return 'A network error occurred. Please check your connection and try again.';
  }
  if (error is FormatException) {
    return 'Received an unexpected response from the server. Please try again.';
  }
  final msg = error?.toString() ?? '';
  if (msg.toLowerCase().contains('socket') ||
      msg.toLowerCase().contains('network')) {
    return 'A network error occurred. Please check your internet connection.';
  }
  return 'An unexpected error occurred. Please try again.';
}
