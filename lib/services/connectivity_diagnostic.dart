import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Diagnostic information about backend connectivity
class ConnectivityDiagnostic {
  final bool isBackendReachable;
  final bool isOcrHealthy;
  final String configuredUrl;
  final String? detectedUrl;
  final List<String> errorMessages;
  final DateTime timestamp;

  ConnectivityDiagnostic({
    required this.isBackendReachable,
    required this.isOcrHealthy,
    required this.configuredUrl,
    this.detectedUrl,
    required this.errorMessages,
    required this.timestamp,
  });

  bool get isHealthy => isBackendReachable && isOcrHealthy;

  String get summary {
    if (isHealthy) {
      return '✔ Backend is healthy\n✔ OCR service is operational';
    }
    return errorMessages.join('\n');
  }
}

/// Service to diagnose backend and OCR connectivity issues
class ConnectivityDiagnosticService {
  /// Run comprehensive connectivity diagnostics
  static Future<ConnectivityDiagnostic> runDiagnostics() async {
    final errors = <String>[];
    bool backendReachable = false;
    bool ocrHealthy = false;
    String? detectedUrl;
    final configuredUrl = AppConstants.baseUrl;

    // Test configured URL
    try {
      final uri = Uri.parse('$configuredUrl/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        backendReachable = true;
        detectedUrl = configuredUrl;
      } else {
        errors.add('❌ Backend responded with status ${response.statusCode}');
      }
    } catch (e) {
      errors.add('❌ Cannot reach configured URL: $configuredUrl\n   Error: $e');
    }

    // Test OCR health if backend is reachable
    if (backendReachable) {
      try {
        final uri = Uri.parse('$configuredUrl/api/v1/admin/ocr/health');
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          ocrHealthy = true;
        } else {
          errors.add('❌ OCR service responded with status ${response.statusCode}');
        }
      } catch (e) {
        errors.add('❌ OCR service unreachable at /api/v1/admin/ocr/health\n   Error: $e');
      }
    }

    // If primary URL failed, surface a clear error — no dev fallbacks in production.
    if (!backendReachable) {
      errors.addAll([
        '\n🔍 Troubleshooting steps:',
        '1. Ensure device has internet connectivity',
        '2. Verify production server is running at: $configuredUrl',
        '3. Check DNS resolves: apiv2.mathswithsd.in',
        '4. For dev builds: flutter run --dart-define=API_BASE_URL=http://localhost:5000',
      ]);
    }

    return ConnectivityDiagnostic(
      isBackendReachable: backendReachable,
      isOcrHealthy: ocrHealthy,
      configuredUrl: configuredUrl,
      detectedUrl: detectedUrl,
      errorMessages: errors,
      timestamp: DateTime.now(),
    );
  }

  /// Quick test for backend connectivity (no OCR)
  static Future<bool> isBackendAvailable() async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Quick test for OCR service
  static Future<bool> isOcrAvailable() async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/api/v1/admin/ocr/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Get human-readable diagnostic report
  static Future<String> getDiagnosticReport() async {
    final diag = await runDiagnostics();
    final buffer = StringBuffer();

    buffer.writeln('╔════════════════════════════════════════════════════════╗');
    buffer.writeln('║           Backend Connectivity Diagnostic             ║');
    buffer.writeln('╚════════════════════════════════════════════════════════╝\n');

    buffer.writeln('Status: ${diag.isHealthy ? '✔ HEALTHY' : '❌ ISSUES DETECTED'}\n');
    
    buffer.writeln('Configuration:');
    buffer.writeln('  Configured URL: ${diag.configuredUrl}');
    if (diag.detectedUrl != null) {
      buffer.writeln('  Detected URL:   ${diag.detectedUrl}');
    }
    
    buffer.writeln('\nConnectivity:');
    buffer.writeln('  Backend:  ${diag.isBackendReachable ? '✔ Reachable' : '❌ Unreachable'}');
    buffer.writeln('  OCR:      ${diag.isOcrHealthy ? '✔ Healthy' : '❌ Unhealthy'}');

    if (diag.errorMessages.isNotEmpty) {
      buffer.writeln('\nMessages:');
      for (final msg in diag.errorMessages) {
        buffer.writeln('  $msg');
      }
    }

    buffer.writeln('\nTimestamp: ${diag.timestamp.toIso8601String()}');

    return buffer.toString();
  }
}
