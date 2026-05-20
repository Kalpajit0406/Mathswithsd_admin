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
  final String _baseUrl = AppConstants.baseUrl;

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

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.loginEndpoint}'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode({'studentPhone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<http.Response> register(Map<String, dynamic> data) async {
    return await http.post(
      Uri.parse('$_baseUrl${AppConstants.registerEndpoint}'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
  }

  // ─── Questions ────────────────────────────────────────────────────────────────

  Future<List<Question>> getQuestions({int? classNo, String? language}) async {
    final params = <String, String>{};
    if (classNo != null) params['classNo'] = classNo.toString();
    if (language != null) params['language'] = language;

    final uri = Uri.parse('$_baseUrl${AppConstants.questionsEndpoint}')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((q) => Question.fromJson(q)).toList();
  }

  Future<Question> createQuestion(Question question) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.createQuestionEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(question.toJson()),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }

  Future<String> uploadImage(File imageFile) async {
    final token = await AuthStorageService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl${AppConstants.uploadImageEndpoint}'),
    );
    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      bytes,
      filename: imageFile.path.split('/').last,
    ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    final data = _processResponse(response);
    return data['data']['url'];
  }

  Future<Map<String, dynamic>> processOcrImage(File file) async {
    try {
      debugPrint("[ApiService] processOcrImage file path: ${file.path}");
      final bool exists = await file.exists();
      if (!exists) {
        throw ApiException('Image file does not exist at path: ${file.path}', 400);
      }
      
      final int length = await file.length();
      debugPrint("[ApiService] File length: $length bytes");
      if (length == 0) {
        throw ApiException('Captured image is empty (0 bytes). Please try taking the photo again.', 400);
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl${AppConstants.processOcrEndpoint}'),
      );

      final headers = await _headers();
      // Boundary is set automatically by http package, so we remove manual Content-Type
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      
      // Use fromPath for better memory efficiency and reliability
      request.files.add(await http.MultipartFile.fromPath(
        'image', 
        file.path,
      ));

      // 60 second timeout for OCR processing which can be slow
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      final data = _processResponse(response);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } on SocketException {
      throw ApiException('Network unreachable. Ensure your server is running.', 503);
    } on TimeoutException {
      throw ApiException('OCR request timed out. Try a smaller crop.', 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('OCR upload failed: ${e.toString()}', 500);
    }
  }


  // ─── Tests ────────────────────────────────────────────────────────────────────

  Future<TestConfig> createTest(Map<String, dynamic> testData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.createTestEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(testData),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return TestConfig.fromJson(data['data'] ?? data);
  }

  Future<List<TestConfig>> getAllTests() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((t) => TestConfig.fromJson(t)).toList();
  }

  Future<List<exam.Exam>> fetchExams(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<String> startAttempt(String examId, String token) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.startAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'examId': examId}),
    ).timeout(const Duration(seconds: 15));
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
          .map((a) => {
                'questionId': a['questionId'],
                'userAnswer': a['answer'] ?? a['selectedOption'],
              })
          .toList(),
    };

    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.submitAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(bodyData),
    ).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String examId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/testResponse/leaderboard/$examId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }


  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements({String? targetClass}) async {
    final params = <String, String>{};
    if (targetClass != null) params['targetClass'] = targetClass;
    
    final uri = Uri.parse('$_baseUrl${AppConstants.announcementsEndpoint}').replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((a) => Announcement.fromJson(a)).toList();
  }

  Future<Announcement> createAnnouncement(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.announcementsEndpoint}/admin'),
      headers: await _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    final responseData = _processResponse(response);
    return Announcement.fromJson(responseData['data'] ?? responseData);
  }

  // ─── Students ─────────────────────────────────────────────────────────────────

  Future<Map<String, List<StudentUser>>> getAllStudents() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.studentsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
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
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.acceptStudentEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'id': id}),
    ).timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<void> rejectStudent(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.rejectStudentEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'id': id}),
    ).timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<Question> createQuestionResilient(Question question, {File? diagramFile}) async {
    final token = await AuthStorageService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl${AppConstants.createQuestionEndpoint}'),
    );

    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
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
      request.files.add(await http.MultipartFile.fromPath('diagram', diagramFile.path));
    }

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }

  Future<Question> updateQuestion(String id, Map<String, dynamic> updateData, {File? diagramFile}) async {
    final token = await AuthStorageService.getToken();
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/api/v1/question/update/$id'),
    );

    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
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
      request.files.add(await http.MultipartFile.fromPath('diagram', diagramFile.path));
    }

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }

  Future<void> deleteQuestion(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/question/delete/$id'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    _processResponse(response);
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
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('OCR processing failed after $maxAttempts attempts', 500);
  }

  /// Create question with retry logic
  Future<Question> createQuestionWithRetry(Question question) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await createQuestion(question);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Create question failed after $maxAttempts attempts', 500);
  }

  /// Login with retry
  Future<Map<String, dynamic>> loginWithRetry(String phone, String password) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await login(phone, password);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Login failed after $maxAttempts attempts', 500);
  }

  /// Get questions with retry
  Future<List<Question>> getQuestionsWithRetry({int? classNo, String? language}) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getQuestions(classNo: classNo, language: language);
      } on ApiException catch (e) {
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
      } on ApiException catch (e) {
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
      } on ApiException catch (e) {
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
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/pdf/extract-questions');
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

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      final data = _processResponse(response);
      return data;
    } catch (e) {
      throw ApiException('PDF upload failed: $e', 500);
    }
  }

  /// Submit PDF by URL for processing
  /// Initiates async processing on backend
  Future<Map<String, dynamic>?> submitPdfByUrl(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/pdf/scan-url'),
        headers: await _headers(),
        body: jsonEncode({
          'url': url,
          'options': {
            'conversionFormats': {
              'docx': true,
              'latex': true,
            }
          }
        }),
      ).timeout(const Duration(seconds: 30));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to submit PDF URL: $e', 500);
    }
  }

  /// Check PDF processing status
  /// Returns status, progress, and estimated time
  Future<Map<String, dynamic>> getPdfStatus(String pdfId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/pdf/status/$pdfId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to get PDF status: $e', 500);
    }
  }

  /// Download PDF result in specific format
  /// Formats: mmd, docx, html, latex, lines_json
  Future<List<int>?> downloadPdfResult(String pdfId, String format) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/pdf/download/$pdfId/$format'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 60));

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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/pdf/extract-questions'),
        headers: await _headers(),
        body: jsonEncode({
          'pdfId': pdfId,
        }),
      ).timeout(const Duration(seconds: 60));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to extract questions from PDF: $e', 500);
    }
  }

  /// Delete PDF results from Mathpix
  /// WARNING: This is permanent
  Future<Map<String, dynamic>?> deletePdf(String pdfId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/pdf/$pdfId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } catch (e) {
      throw ApiException('Failed to delete PDF: $e', 500);
    }
  }

  /// Stream PDF pages in real-time (Server-Sent Events)
  /// Returns event stream of page results as they complete
  Stream<Map<String, dynamic>> streamPdfPages(String pdfId) async* {
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/pdf/stream/$pdfId');
      final headers = await _headers();

      final request = http.StreamedRequest('GET', uri);
      request.headers.addAll(headers);

      final response = await request.send();

      if (response.statusCode != 200) {
        throw ApiException('Stream failed with status ${response.statusCode}', response.statusCode);
      }

      await for (final line in response.stream
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

  MultipartRequestWithProgress(
    String method,
    Uri url, {
    this.onProgress,
  }) : super(method, url);

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

