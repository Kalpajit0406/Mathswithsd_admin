import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/question_model.dart';
import '../models/test_model.dart';
import '../models/exam_model.dart' as exam;
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiService {
  static VoidCallback? onUnauthorized;
  // Static value from build-time env; resolved at runtime by _getBaseUrl
  final String _staticBaseUrl = AppConstants.baseUrl;
  String? _resolvedBaseUrl;

  String get baseUrl => _resolvedBaseUrl ?? _staticBaseUrl;

  Future<String> _getBaseUrl() async {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    // Check for a manual override stored in secure storage
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      if (override != null && override.isNotEmpty) {
        final overrideResolved = await _probeBaseUrl(override);
        if (overrideResolved) {
          _resolvedBaseUrl = override;
          debugPrint('[ApiService] Using stored base URL override: $override');
          return override;
        }
        debugPrint(
          '[ApiService] Stored base URL override is unreachable, rediscovering: $override',
        );
      }
    } catch (e) {
      debugPrint('[ApiService] Error reading base URL override: $e');
    }

    final candidates = <String>[
      'http://10.0.2.2:5000', // Android emulator
      'http://localhost:5000', // Desktop
    ];
    for (final c in candidates) {
      try {
        if (await _probeBaseUrl(c)) {
          _resolvedBaseUrl = c;
          await AuthStorageService.saveBaseUrlOverride(c);
          debugPrint('[ApiService] Resolved base URL to $c via health probe');
          return c;
        }
      } catch (e) {
        debugPrint('[ApiService] Probe failed for $c -> $e');
      }
    }

    // Try LAN subnet discovery as a final fallback for physical devices.
    try {
      final discovered = await _discoverLanBackendBaseUrl();
      if (discovered != null && discovered.isNotEmpty) {
        _resolvedBaseUrl = discovered;
        await AuthStorageService.saveBaseUrlOverride(discovered);
        debugPrint(
          '[ApiService] Resolved base URL via LAN discovery to $discovered',
        );
        return discovered;
      }
    } catch (e) {
      debugPrint('[ApiService] LAN discovery failed: $e');
    }

    debugPrint('[ApiService] Falling back to static base URL: $_staticBaseUrl');
    _resolvedBaseUrl = _staticBaseUrl;
    return _staticBaseUrl;
  }

  Future<bool> _probeBaseUrl(String baseUrl) async {
    try {
      final probeUri = Uri.parse('$baseUrl/health');
      final isRemote = baseUrl.startsWith('https://');
      final timeoutMs = isRemote ? 8000 : 1500;
      final resp = await http
          .get(probeUri)
          .timeout(Duration(milliseconds: timeoutMs));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _discoverLanBackendBaseUrl() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final candidates = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final octets = address.address.split('.');
        if (octets.length != 4) continue;

        final prefix = '${octets[0]}.${octets[1]}.${octets[2]}';
        final lastOctet = int.tryParse(octets[3]);
        final commonHosts = <int>{
          1,
          2,
          3,
          4,
          5,
          10,
          11,
          20,
          50,
          100,
          101,
          110,
          111,
          120,
          125,
          150,
          200,
          254,
        };
        if (lastOctet != null) commonHosts.remove(lastOctet);

        for (final host in commonHosts) {
          candidates.add('http://$prefix.$host:5000');
        }

        // Full /24 scan
        for (var host = 1; host <= 254; host++) {
          if (lastOctet == host) continue;
          candidates.add('http://$prefix.$host:5000');
        }
      }
    }

    if (candidates.isEmpty) return null;

    final candidateList = candidates.toList();
    String? foundUrl;

    const batchSize = 40;
    for (var i = 0; i < candidateList.length; i += batchSize) {
      final end = (i + batchSize < candidateList.length)
          ? i + batchSize
          : candidateList.length;
      final batch = candidateList.sublist(i, end);

      await Future.wait(
        batch.map((url) async {
          if (foundUrl != null) return;
          final ok = await _probeBaseUrl(url);
          if (ok) {
            foundUrl = url;
          }
        }),
      );

      if (foundUrl != null) {
        return foundUrl;
      }
    }

    return null;
  }

  Future<Uri> _uri(String endpoint) async {
    final base = await _getBaseUrl();
    return Uri.parse('$base$endpoint');
  }

  Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (includeAuth) {
      final token = await AuthStorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<void> _handleUnauthorized() async {
    debugPrint('[ApiService] 401 Unauthorized - clearing all stored data');
    await AuthStorageService.clearAll();
    onUnauthorized?.call();
  }

  Future<String> _requireAuthToken() async {
    final token = await AuthStorageService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw ApiException('Session expired. Please login again.', 401);
    }
    return token.trim();
  }

  /// Check if the backend server is reachable.
  Future<bool> isBackendHealthy() async {
    try {
      final base = await _getBaseUrl();
      final candidates = [
        Uri.parse('$base/api/health'),
        Uri.parse('$base/health'),
        Uri.parse('$base/api/v1/health'),
      ];
      for (final uri in candidates) {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] Backend health check failed: $e');
      return false;
    }
  }

  /// Check if the OCR service is operational.
  Future<bool> isOcrHealthy() async {
    try {
      final base = await _getBaseUrl();
      final candidates = [
        Uri.parse('$base/api/v1/admin/ocr/health'),
        Uri.parse('$base/api/v1/ocr/health'),
        Uri.parse('$base/api/health'),
      ];
      for (final uri in candidates) {
        final response = await http
            .get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] OCR health check failed: $e');
      return false;
    }
  }

  /// Returns the currently resolved base URL.
  Future<String> getConfiguredBaseUrl() async => _getBaseUrl();

  dynamic _processResponse(http.Response response) {
    debugPrint(
      '[ApiService] Response: ${response.statusCode} (${response.request?.url})',
    );

    // Handle 401 unauthorized
    if (response.statusCode == 401) {
      _handleUnauthorized();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        debugPrint('[ApiService] Empty response body');
        return {};
      }
      try {
        final decoded = jsonDecode(response.body);
        debugPrint(
          '[ApiService] Response body (truncated): ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}',
        );
        return decoded;
      } catch (e) {
        debugPrint('[ApiService] JSON decode error: $e');
        throw ApiException('Invalid JSON response: $e', response.statusCode);
      }
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {
      debugPrint('[ApiService] Error response body: ${response.body}');
    }
    debugPrint('[ApiService] Error: $message');
    throw ApiException(message, response.statusCode);
  }

  Future<void> _logRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
  ) async {
    debugPrint('[ApiService] Request: $method ${uri.path}');
    if (headers != null) {
      final sanitized = Map<String, String>.from(headers);
      if (sanitized.containsKey('Authorization')) {
        sanitized['Authorization'] = sanitized['Authorization']!.replaceAll(
          RegExp(r'.{20}'),
          'X',
        );
      }
      debugPrint('[ApiService] Headers: $sanitized');
    }
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final uri = await _uri(AppConstants.loginEndpoint);
    final headers = await _headers(includeAuth: false);
    await _logRequest('POST', uri, headers);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'studentPhone': phone, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<http.Response> register(Map<String, dynamic> data) async {
    return await http
        .post(
          await _uri(AppConstants.registerEndpoint),
          headers: await _headers(includeAuth: false),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<bool> validateSession() async {
    try {
      final response = await http
          .get(await _uri('/api/v1/student/me'), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) return true;
      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }
      return true;
    } catch (_) {
      // Network/server issue: keep existing session state, don't force logout.
      return true;
    }
  }

  // ─── Questions ────────────────────────────────────────────────────────────────

  Future<List<Question>> getQuestions({
    int? classNo,
    String? language,
    String? chapter,
    String? search,
    int? page,
    int? pageSize,
  }) async {
    final params = <String, String>{};
    if (classNo != null) params['classNo'] = classNo.toString();
    if (language != null) params['language'] = language;
    if (chapter != null && chapter.isNotEmpty) params['chapter'] = chapter;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['pageSize'] = pageSize.toString();

    final uri = (await _uri(
      AppConstants.questionsEndpoint,
    )).replace(queryParameters: params);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((q) => Question.fromJson(q)).toList();
  }

  Future<Question> createQuestion(Question question) async {
    final response = await http
        .post(
          await _uri(AppConstants.createQuestionEndpoint),
          headers: await _headers(),
          body: jsonEncode(question.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }

  Future<String> uploadImage(File imageFile) async {
    final token = await _requireAuthToken();
    final client = http.Client();
    final request = http.MultipartRequest(
      'POST',
      await _uri(AppConstants.uploadImageEndpoint),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    final bytes = await imageFile.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.path.split('/').last,
      ),
    );

    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final data = _processResponse(response);
      return data['data']['url'];
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> processOcrImage(File file) async {
    final client = http.Client();
    try {
      debugPrint("[ApiService] processOcrImage file path: ${file.path}");
      final bool exists = await file.exists();
      if (!exists) {
        throw ApiException(
          'Image file does not exist at path: ${file.path}',
          400,
        );
      }

      final int length = await file.length();
      debugPrint("[ApiService] File length: $length bytes");
      if (length == 0) {
        throw ApiException(
          'Captured image is empty (0 bytes). Please try taking the photo again.',
          400,
        );
      }

      final token = await AuthStorageService.getToken();
      if (token == null || token.trim().isEmpty) {
        throw ApiException('Session expired. Please login again.', 401);
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${await _getBaseUrl()}${AppConstants.processOcrEndpoint}'),
      );

      request.headers['Authorization'] = 'Bearer ${token.trim()}';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      debugPrint('[ApiService] Multipart OCR request headers set with auth');

      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.path.split('/').last,
        ),
      );

      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      final data = _processResponse(response);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } on SocketException {
      throw ApiException(
        'Network unreachable. Ensure your server is running.',
        503,
      );
    } on TimeoutException {
      throw ApiException('OCR request timed out. Try a smaller crop.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('OCR upload failed: ${e.toString()}', 500);
    } finally {
      client.close();
    }
  }

  // ─── Tests ────────────────────────────────────────────────────────────────────

  Future<TestConfig> createTest(Map<String, dynamic> testData) async {
    final response = await http
        .post(
          await _uri(AppConstants.createTestEndpoint),
          headers: await _headers(),
          body: jsonEncode(testData),
        )
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return TestConfig.fromJson(data['data'] ?? data);
  }

  Future<List<TestConfig>> getAllTests() async {
    final response = await http
        .get(await _uri(AppConstants.testsEndpoint), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((t) => TestConfig.fromJson(t)).toList();
  }

  Future<List<exam.Exam>> fetchExams(String token) async {
    final response = await http
        .get(await _uri(AppConstants.testsEndpoint), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<String> startAttempt(String examId, String token) async {
    final response = await http
        .post(
          await _uri(AppConstants.startAttemptEndpoint),
          headers: await _headers(),
          body: jsonEncode({'examId': examId}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return data['data']?['id'] ?? data['data']?['_id'] ?? '';
  }

  Future<Map<String, dynamic>> submitAnswers({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
    required String token,
  }) async {
    final Map<String, dynamic> bodyData = {
      'attemptId': attemptId,
      'responses': answers
          .where((a) => a['questionId'] != null)
          .map(
            (a) => {
              'questionId': a['questionId'],
              'userAnswer': a['answer'] ?? a['selectedOption'],
            },
          )
          .toList(),
    };

    final response = await http
        .post(
          await _uri(AppConstants.submitAttemptEndpoint),
          headers: await _headers(),
          body: jsonEncode(bodyData),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String examId) async {
    final response = await http
        .get(
          await _uri('/api/v1/testResponse/leaderboard/$examId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }

  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements({String? targetClass}) async {
    final params = <String, String>{};
    if (targetClass != null) params['targetClass'] = targetClass;

    final uri = (await _uri(
      AppConstants.announcementsEndpoint,
    )).replace(queryParameters: params);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((a) => Announcement.fromJson(a)).toList();
  }

  Future<Announcement> createAnnouncement(Map<String, dynamic> data) async {
    final response = await http
        .post(
          await _uri('${AppConstants.announcementsEndpoint}/admin'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));
    final responseData = _processResponse(response);
    return Announcement.fromJson(responseData['data'] ?? responseData);
  }

  Future<void> bulkDeleteAnnouncements(List<String> ids) async {
    final response = await http
        .post(
          await _uri(AppConstants.bulkDeleteAnnouncementsEndpoint),
          headers: await _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  // ─── Students ─────────────────────────────────────────────────────────────────

  Future<Map<String, List<StudentUser>>> getAllStudents() async {
    final response = await http
        .get(
          await _uri(AppConstants.studentsEndpoint),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final payload = data['data'] ?? {};

    List<StudentUser> mapList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((u) => StudentUser.fromJson(u)).toList();
    }

    return {
      'unverified': mapList(payload['unverified']),
      'verified': mapList(payload['verified']),
      'rejected': mapList(payload['rejected']),
    };
  }

  Future<void> acceptStudent(String id) async {
    final response = await http
        .post(
          await _uri(AppConstants.acceptStudentEndpoint),
          headers: await _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<void> rejectStudent(String id) async {
    final response = await http
        .post(
          await _uri(AppConstants.rejectStudentEndpoint),
          headers: await _headers(),
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<void> bulkAcceptStudents(List<String> ids) async {
    final response = await http
        .post(
          await _uri(AppConstants.bulkAcceptStudentsEndpoint),
          headers: await _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  Future<void> bulkRejectStudents(List<String> ids) async {
    final response = await http
        .post(
          await _uri(AppConstants.bulkRejectStudentsEndpoint),
          headers: await _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  Future<void> bulkDeleteStudents(List<String> ids) async {
    final response = await http
        .post(
          await _uri(AppConstants.bulkDeleteStudentsEndpoint),
          headers: await _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  Future<void> approveProfileEdit(String studentId, bool approve) async {
    final response = await http
        .post(
          await _uri(AppConstants.approveProfileEditEndpoint),
          headers: await _headers(),
          body: jsonEncode({'id': studentId, 'approve': approve}),
        )
        .timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<Question> createQuestionResilient(
    Question question, {
    File? diagramFile,
  }) async {
    final token = await _requireAuthToken();
    final client = http.Client();
    final request = http.MultipartRequest(
      'POST',
      await _uri(AppConstants.createQuestionEndpoint),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    // Add text fields
    request.fields['question'] = question.questionText;
    request.fields['options'] = jsonEncode(question.options);
    request.fields['correctAnswer'] = question.correctAnswer;
    request.fields['classNo'] = question.classNo.toString();
    request.fields['chapter'] = question.chapter;
    request.fields['language'] = question.language;

    // Add diagram if present
    if (diagramFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('diagram', diagramFile.path),
      );
    }

    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final data = _processResponse(response);
      return Question.fromJson(data['data']);
    } finally {
      client.close();
    }
  }

  Future<Question> updateQuestion(
    String id,
    Map<String, dynamic> updateData, {
    File? diagramFile,
  }) async {
    final token = await _requireAuthToken();
    final client = http.Client();
    final request = http.MultipartRequest(
      'PUT',
      await _uri('/api/v1/question/update/$id'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    // Add text fields
    updateData.forEach((key, value) {
      if (key == 'options') {
        request.fields[key] = jsonEncode(value);
      } else {
        request.fields[key] = value.toString();
      }
    });

    if (diagramFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('diagram', diagramFile.path),
      );
    }

    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final data = _processResponse(response);
      return Question.fromJson(data['data']);
    } finally {
      client.close();
    }
  }

  Future<void> deleteQuestion(String id) async {
    final response = await http
        .delete(
          await _uri('/api/v1/question/delete/$id'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    _processResponse(response);
  }

  // ─── OCR Verification Sessions ─────────────────────────────────────────────

  Future<Map<String, dynamic>> startOcrSession(File imageFile) async {
    final client = http.Client();
    try {
      debugPrint("[ApiService] startOcrSession file path: ${imageFile.path}");
      final bool exists = await imageFile.exists();
      if (!exists) {
        throw ApiException(
          'Image file does not exist at path: ${imageFile.path}',
          400,
        );
      }

      final int length = await imageFile.length();
      debugPrint("[ApiService] startOcrSession File length: $length bytes");
      if (length == 0) {
        throw ApiException(
          'Captured image is empty (0 bytes). Please try taking the photo again.',
          400,
        );
      }

      final token = await _requireAuthToken();
      final request = http.MultipartRequest(
        'POST',
        await _uri('/api/v1/admin/ocr/session/start'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      final bytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.path.split('/').last,
        ),
      );

      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'OCR request timed out. The image may be too large or the server is slow.',
        408,
      );
    } on SocketException catch (e) {
      final baseUrl = await getConfiguredBaseUrl();
      throw ApiException(
        'Cannot reach OCR server at $baseUrl. Is the backend running?\nError: ${e.message}',
        503,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('OCR session start failed: $e', 500);
    } finally {
      client.close();
    }
  }

  /// Start OCR session with automatic retries and health checks
  Future<Map<String, dynamic>> startOcrSessionWithRetry(
    File imageFile, {
    int maxAttempts = 3,
  }) async {
    // First check if backend is healthy
    final isHealthy = await isBackendHealthy();
    if (!isHealthy) {
      final baseUrl = await getConfiguredBaseUrl();
      throw ApiException(
        'Backend server unreachable at $baseUrl.\n\nPlease check:\n'
        '1. Backend server is running\n'
        '2. Device is on the same WiFi network\n'
        '3. IP address is correct',
        503,
      );
    }

    // Check OCR service specifically
    final ocrHealthy = await isOcrHealthy();
    if (!ocrHealthy) {
      throw ApiException(
        'OCR service is not responding. Please try again.',
        503,
      );
    }

    int attempt = 0;
    Duration delay = const Duration(seconds: 2);

    while (attempt < maxAttempts) {
      try {
        return await startOcrSession(imageFile);
      } on ApiException {
        rethrow;
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) {
          throw ApiException(
            'OCR session failed after $maxAttempts attempts: $e',
            500,
          );
        }
        debugPrint(
          '[ApiService] OCR attempt $attempt failed, retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2); // exponential backoff
      }
    }
    throw ApiException('OCR session failed after $maxAttempts attempts', 500);
  }

  Future<Map<String, dynamic>> getOcrSession(String sessionId) async {
    final response = await http
        .get(
          await _uri('/api/v1/admin/ocr/session/$sessionId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> updateOcrSessionItem(
    String sessionId,
    int index, {
    String? questionText,
    List<String>? options,
    String? questionNumber,
    bool? verified,
  }) async {
    final body = <String, dynamic>{};
    if (questionText != null) body['questionText'] = questionText;
    if (options != null) body['options'] = options;
    if (questionNumber != null) body['questionNumber'] = questionNumber;
    if (verified != null) body['verified'] = verified;

    final response = await http
        .put(
          await _uri('/api/v1/admin/ocr/session/$sessionId/item/$index'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> deleteOcrSessionItem(
    String sessionId,
    int index,
  ) async {
    final response = await http
        .delete(
          await _uri('/api/v1/admin/ocr/session/$sessionId/item/$index'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> verifyOcrSessionItem(
    String sessionId,
    int index, {
    required String chapter,
    required int classNo,
    required String correctAnswer,
    required String language,
    String? questionText,
    List<String>? options,
    File? diagramFile,
  }) async {
    final token = await _requireAuthToken();
    final client = http.Client();
    final request = http.MultipartRequest(
      'POST',
      await _uri('/api/v1/admin/ocr/session/$sessionId/item/$index/verify'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    request.fields['chapter'] = chapter;
    request.fields['classNo'] = classNo.toString();
    request.fields['correctAnswer'] = correctAnswer;
    request.fields['language'] = language;
    if (questionText != null) request.fields['questionText'] = questionText;
    if (options != null) request.fields['options'] = jsonEncode(options);

    if (diagramFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('diagram', diagramFile.path),
      );
    }

    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> setCurrentOcrSessionIndex(
    String sessionId,
    int index,
  ) async {
    final response = await http
        .post(
          await _uri('/api/v1/admin/ocr/session/$sessionId/index'),
          headers: await _headers(),
          body: jsonEncode({'index': index}),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> nextOcrSessionItem(String sessionId) async {
    final response = await http
        .post(
          await _uri('/api/v1/admin/ocr/session/$sessionId/next'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> prevOcrSessionItem(String sessionId) async {
    final response = await http
        .post(
          await _uri('/api/v1/admin/ocr/session/$sessionId/prev'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  // ─── Retry Methods ───────────────────────────────────────────────────────────

  /// Process OCR image with exponential backoff retry
  /// Includes longer timeout (60s) and 3 retry attempts
  Future<Map<String, dynamic>> processOcrImageWithRetry(File file) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await processOcrImage(file);
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException(
      'OCR processing failed after $maxAttempts attempts',
      500,
    );
  }

  /// Create question with retry logic
  Future<Question> createQuestionWithRetry(Question question) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await createQuestion(question);
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException(
      'Create question failed after $maxAttempts attempts',
      500,
    );
  }

  /// Login with retry
  Future<Map<String, dynamic>> loginWithRetry(
    String phone,
    String password,
  ) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await login(phone, password);
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Login failed after $maxAttempts attempts', 500);
  }

  /// Get questions with retry
  Future<List<Question>> getQuestionsWithRetry({
    int? classNo,
    String? language,
    String? chapter,
    String? search,
    int? page,
    int? pageSize,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getQuestions(
          classNo: classNo,
          language: language,
          chapter: chapter,
          search: search,
          page: page,
          pageSize: pageSize,
        );
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Get questions failed after $maxAttempts attempts', 500);
  }

  /// Get all tests/exams with retry
  Future<List<TestConfig>> getAllTestsWithRetry() async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getAllTests();
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Get tests failed after $maxAttempts attempts', 500);
  }

  /// Get students with retry
  Future<Map<String, List<StudentUser>>> getAllStudentsWithRetry() async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getAllStudents();
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Get students failed after $maxAttempts attempts', 500);
  }

  // ─── PDF PROCESSING ──────────────────────────────────────────────────────────

  /// Upload PDF file and extract questions
  /// Sends multipart request with file and options
  Future<Map<String, dynamic>?> uploadPdfAndExtractQuestions(
    File pdfFile, {
    Function(double)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(
        '${await _getBaseUrl()}/api/v1/pdf/extract-questions',
      );
      final request = MultipartRequestWithProgress(
        'POST',
        uri,
        onProgress: (bytes, total) {
          if (onProgress != null && total > 0) {
            onProgress(bytes / total);
          }
        },
      );

      // Add headers
      final headers = await _headers();
      request.headers.addAll(headers);

      // Add file
      request.files.add(
        http.MultipartFile(
          'file',
          pdfFile.readAsBytes().asStream(),
          await pdfFile.length(),
          filename: pdfFile.path.split('/').last,
        ),
      );

      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      final data = _processResponse(response);
      return data;
    } catch (e) {
      throw ApiException('PDF upload failed: $e', 500);
    } finally {
      client.close();
    }
  }

  /// Submit PDF by URL for processing
  /// Initiates async processing on backend
  Future<Map<String, dynamic>?> submitPdfByUrl(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse('${await _getBaseUrl()}/api/v1/pdf/scan-url'),
            headers: await _headers(),
            body: jsonEncode({
              'url': url,
              'options': {
                'conversionFormats': {'docx': true, 'latex': true},
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to submit PDF URL: $e', 500);
    }
  }

  /// Check PDF processing status
  /// Returns status, progress, and estimated time
  Future<Map<String, dynamic>> getPdfStatus(String pdfId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${await _getBaseUrl()}/api/v1/pdf/status/$pdfId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to get PDF status: $e', 500);
    }
  }

  /// Download PDF result in specific format
  /// Formats: mmd, docx, html, latex, lines_json
  Future<List<int>?> downloadPdfResult(String pdfId, String format) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${await _getBaseUrl()}/api/v1/pdf/download/$pdfId/$format',
            ),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      throw ApiException('Failed to download PDF result', response.statusCode);
    } catch (e) {
      throw ApiException('PDF download error: $e', 500);
    }
  }

  /// Extract questions from already-processed PDF
  /// Pass the PDF ID that was returned from submitPdfByUrl
  Future<Map<String, dynamic>?> extractQuestionsFromPdfId(String pdfId) async {
    try {
      final response = await http
          .post(
            Uri.parse('${await _getBaseUrl()}/api/v1/pdf/extract-questions'),
            headers: await _headers(),
            body: jsonEncode({'pdfId': pdfId}),
          )
          .timeout(const Duration(seconds: 60));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to extract questions from PDF: $e', 500);
    }
  }

  /// Delete PDF results from Mathpix
  /// WARNING: This is permanent
  Future<Map<String, dynamic>?> deletePdf(String pdfId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${await _getBaseUrl()}/api/v1/pdf/$pdfId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete PDF: $e', 500);
    }
  }

  /// Stream PDF pages in real-time (Server-Sent Events)
  /// Returns event stream of page results as they complete
  Stream<Map<String, dynamic>> streamPdfPages(String pdfId) async* {
    try {
      final uri = Uri.parse('${await _getBaseUrl()}/api/v1/pdf/stream/$pdfId');
      final headers = await _headers();

      final request = http.StreamedRequest('GET', uri);
      request.headers.addAll(headers);

      final response = await request.send();

      if (response.statusCode != 200) {
        throw ApiException(
          'Stream failed with status ${response.statusCode}',
          response.statusCode,
        );
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final jsonStr = line.substring(6);
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield data;
          } catch (e) {
            // Skip malformed lines
          }
        }
      }
    } catch (e) {
      throw ApiException('PDF streaming error: $e', 500);
    }
  }
}

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytes, int totalBytes)? onProgress;

  MultipartRequestWithProgress(super.method, super.url, {this.onProgress});

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytesUploaded = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesUploaded += data.length;
        onProgress!(bytesUploaded, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
