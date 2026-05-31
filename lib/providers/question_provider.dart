import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import 'dart:io';

enum QuestionLoadState { idle, loading, loaded, error }
enum QueueNavigationMode { sequential, random, skip }

/// Enhanced provider with multi-question queue management
class QuestionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  static const String _queuePrefsKey = 'ocr_question_queue_state_v1';
  static const int _maxQueueSize = 100;

  // Questions database
  List<Question> _questions = [];
  QuestionLoadState _loadState = QuestionLoadState.idle;
  String? _error;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 10;

  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  // ═══════════════════════════════════════════════════════════════════════════
  // ENHANCED QUEUE SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Queue of ScanData items extracted from OCR
  List<ScanData> _questionQueue = [];
  
  /// Current position in queue (0-based index)
  int _currentQueueIndex = 0;
  
  /// Navigation mode for queue (sequential, random, skip)
  QueueNavigationMode _queueNavigationMode = QueueNavigationMode.sequential;
  
  /// Verification history for undo/recovery
  final List<ScanData> _verificationHistory = [];
  
  /// Original OCR response for recovery
  Map<String, dynamic>? _lastOcrResponse;

  // UI state
  bool _isScanning = false;
  bool _isSaving = false;
  String? _creationError;
  
  /// Session ID for server-side queue management (if implemented)
  String? _queueSessionId;

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<Question> get questions => _questions;
  QuestionLoadState get loadState => _loadState;
  String? get error => _error;
  
  // Queue-related getters
  List<ScanData> get questionQueue => _questionQueue;
  int get queueLength => _questionQueue.length;
  int get currentQueueIndex => _currentQueueIndex;
  
  /// Get current question from queue (or null if queue empty)
  ScanData? get currentQueueItem => 
      _currentQueueIndex < _questionQueue.length 
          ? _questionQueue[_currentQueueIndex]
          : null;
  
  /// Queue progress: "3 of 7"
  String get queueProgress => 
      _questionQueue.isEmpty 
          ? '0 of 0'
          : '${_currentQueueIndex + 1} of ${_questionQueue.length}';
  
  /// Whether there's a next question
  bool get hasNextQuestion => _currentQueueIndex < _questionQueue.length - 1;
  
  /// Whether there's a previous question
  bool get hasPreviousQuestion => _currentQueueIndex > 0;
  
  /// How many questions remain
  int get remainingQuestions => 
      _questionQueue.length - _currentQueueIndex;
  
  bool get isScanning => _isScanning;
  bool get isSaving => _isSaving;
  String? get creationError => _creationError;
  bool get isQueueEmpty => _questionQueue.isEmpty;
  bool get isQueueActive => _questionQueue.isNotEmpty;
  int get verificationHistoryLength => _verificationHistory.length;

  Future<void> _persistQueueState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'queueSessionId': _queueSessionId,
        'currentQueueIndex': _currentQueueIndex,
        'items': _questionQueue.map((item) => item.toJson()).toList(),
        'lastOcrResponse': _lastOcrResponse,
      };
      await prefs.setString(_queuePrefsKey, jsonEncode(state));
    } catch (_) {
      // Queue persistence is best-effort; scanning should continue even if disk write fails.
    }
  }

  Future<void> restoreQueueState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queuePrefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final items = decoded['items'] as List?;
      _queueSessionId = decoded['queueSessionId']?.toString();
      _currentQueueIndex = (decoded['currentQueueIndex'] as num?)?.toInt() ?? 0;
      
      if (items != null) {
        final cappedItems = items.take(_maxQueueSize);
        _questionQueue = cappedItems
            .whereType<Map>()
            .map((item) => ScanData.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (items.length > _maxQueueSize) {
          debugPrint('OCR queue capped at $_maxQueueSize items during restore.');
        }
        if (_questionQueue.isNotEmpty && _currentQueueIndex >= _questionQueue.length) {
          _currentQueueIndex = _questionQueue.length - 1;
        }
      }
      _lastOcrResponse = decoded['lastOcrResponse'] is Map
          ? Map<String, dynamic>.from(decoded['lastOcrResponse'] as Map)
          : null;
      notifyListeners();

      // Sync and restore from backend if sessionId is present
      if (_queueSessionId != null && _queueSessionId!.isNotEmpty) {
        try {
          final response = await _apiService.getOcrSession(_queueSessionId!);
          if (response['success'] == true && response['data'] != null) {
            final sessionData = response['data'] as Map<String, dynamic>;
            await _populateQueueFromOcrSession(sessionData);
          }
        } catch (e) {
          debugPrint('Failed to sync queue state with backend, using local cache: $e');
        }
      }
    } catch (_) {
      // Ignore corrupted local state
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUESTION LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> loadQuestions({int? classNo, String? language, bool clearCache = true}) async {
    if (clearCache) {
      _loadState = QuestionLoadState.loading;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
      _questions = [];
      notifyListeners();
    }

    try {
      final newQuestions = await _apiService.getQuestions(
        classNo: classNo,
        language: language,
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      if (clearCache) {
        _questions = newQuestions;
      } else {
        _questions.addAll(newQuestions);
      }
      
      _hasMore = newQuestions.length >= _pageSize;
      _loadState = QuestionLoadState.loaded;
    } on ApiException catch (e) {
      _error = e.message;
      _loadState = QuestionLoadState.error;
    } catch (e) {
      _error = 'Failed to load questions. Check your connection.';
      _loadState = QuestionLoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadMoreQuestions({int? classNo, String? language}) async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final newQuestions = await _apiService.getQuestions(
        classNo: classNo,
        language: language,
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      _questions.addAll(newQuestions);
      _hasMore = newQuestions.length >= _pageSize;
    } catch (e) {
      _currentPage--;
      debugPrint('Failed to load more questions: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OCR SCANNING & QUEUE POPULATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scanImage(File imageFile) async {
    _isScanning = true;
    _creationError = null;
    _currentQueueIndex = 0;
    _verificationHistory.clear();
    notifyListeners();

    try {
      final response = await _apiService.startOcrSessionWithRetry(imageFile);
      if (response['success'] == true && response['data'] != null) {
        final sessionData = response['data'] as Map<String, dynamic>;
        await _populateQueueFromOcrSession(sessionData);
      } else {
        _creationError = 'Failed to start OCR session';
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _creationError = 'Session expired. Please login again.';
      } else if (e.statusCode == 504 || e.statusCode == 408) {
        _creationError = 'OCR timed out. Try a clearer/smaller image and retry.';
      } else {
        _creationError = e.message;
      }
    } catch (e) {
      _creationError = 'OCR Error: ${e.toString()}';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUEUE NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Move to next question in queue
  bool nextQuestion() {
    if (hasNextQuestion) {
      _currentQueueIndex++;
      _persistQueueState();
      if (_queueSessionId != null) {
        _apiService.setCurrentOcrSessionIndex(_queueSessionId!, _currentQueueIndex).catchError((e) {
          debugPrint('Failed to sync index with backend: $e');
        });
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Move to previous question in queue
  bool previousQuestion() {
    if (hasPreviousQuestion) {
      _currentQueueIndex--;
      _persistQueueState();
      if (_queueSessionId != null) {
        _apiService.setCurrentOcrSessionIndex(_queueSessionId!, _currentQueueIndex).catchError((e) {
          debugPrint('Failed to sync index with backend: $e');
        });
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Jump to specific index in queue
  bool jumpToIndex(int index) {
    if (index >= 0 && index < _questionQueue.length) {
      _currentQueueIndex = index;
      _persistQueueState();
      if (_queueSessionId != null) {
        _apiService.setCurrentOcrSessionIndex(_queueSessionId!, _currentQueueIndex).catchError((e) {
          debugPrint('Failed to sync index with backend: $e');
        });
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Remove current question from queue
  bool removeCurrentQuestion() {
    if (_currentQueueIndex < _questionQueue.length) {
      final indexToDelete = _currentQueueIndex;
      _questionQueue.removeAt(indexToDelete);
      if (_currentQueueIndex >= _questionQueue.length && _currentQueueIndex > 0) {
        _currentQueueIndex--;
      }
      
      _persistQueueState();
      notifyListeners();

      if (_queueSessionId != null) {
        _apiService.deleteOcrSessionItem(_queueSessionId!, indexToDelete).catchError((e) {
          debugPrint('Failed to delete queue item on backend: $e');
        });
      }
      return true;
    }
    return false;
  }

  /// Mark current question as verified and optionally move to next
  void markCurrentAsVerified({bool moveNext = true}) {
    if (_currentQueueIndex < _questionQueue.length) {
      final item = _questionQueue[_currentQueueIndex];
      _questionQueue[_currentQueueIndex] = item.copyWith(
        verified: true,
        verifiedAt: DateTime.now(),
      );
      _verificationHistory.add(_questionQueue[_currentQueueIndex]);
      
      if (moveNext) nextQuestion();
      _persistQueueState();
      notifyListeners();
    }
  }

  /// Pop first question from queue and move to next (backward compatibility)
  void popQuestionFromQueue() {
    if (_questionQueue.isNotEmpty) {
      _verificationHistory.add(_questionQueue[0]);
      _questionQueue.removeAt(0);
      _currentQueueIndex = 0;
      _persistQueueState();
      notifyListeners();
    }
  }

  /// Skip current question without marking as verified
  bool skipCurrentQuestion() {
    return nextQuestion();
  }

  /// Restore last question from verification history
  bool undoLastVerification() {
    if (_verificationHistory.isNotEmpty) {
      final restored = _verificationHistory.removeLast();
      _questionQueue.insert(0, restored);
      _currentQueueIndex = 0;
      _persistQueueState();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update current question in queue
  void updateCurrentQuestion(ScanData updatedData) {
    if (_currentQueueIndex < _questionQueue.length) {
      _questionQueue[_currentQueueIndex] = updatedData;
      _persistQueueState();
      notifyListeners();

      if (_queueSessionId != null) {
        _apiService.updateOcrSessionItem(
          _queueSessionId!,
          _currentQueueIndex,
          questionText: updatedData.questionText,
          options: updatedData.options,
          questionNumber: updatedData.questionNumber,
          verified: updatedData.verified,
        ).catchError((e) {
          debugPrint('Failed to update queue item on backend: $e');
        });
      }
    }
  }

  /// Clear entire queue and reset
  void clearQueue() {
    _questionQueue.clear();
    _currentQueueIndex = 0;
    _verificationHistory.clear();
    _lastOcrResponse = null;
    _queueSessionId = null;
    _persistQueueState();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUESTION SAVING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> saveQuestion(Question question, {File? diagramFile}) async {
    _isSaving = true;
    _creationError = null;
    notifyListeners();

    try {
      Question saved;
      if (_queueSessionId != null && _currentQueueIndex < _questionQueue.length) {
        final response = await _apiService.verifyOcrSessionItem(
          _queueSessionId!,
          _currentQueueIndex,
          chapter: question.chapter,
          classNo: question.classNo,
          correctAnswer: question.correctAnswer,
          language: question.language,
          questionText: question.questionText,
          options: question.options,
          diagramFile: diagramFile,
        );
        if (response['success'] == true && response['data'] != null) {
          saved = Question.fromJson(response['data']);
        } else {
          throw ApiException('Verification failed: ${response['message'] ?? 'Unknown error'}', 400);
        }
      } else {
        saved = await _apiService.createQuestionResilient(question, diagramFile: diagramFile);
      }

      _questions.insert(0, saved);
      
      // Mark current queue item as verified if it exists
      if (_currentQueueIndex < _questionQueue.length) {
        markCurrentAsVerified(moveNext: true);
      }
      _persistQueueState();
      
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _creationError = 'Session expired. Please login again.';
      } else {
        _creationError = e.message;
      }
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      _creationError = 'Failed to save question. Check your connection.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuestion(String id, Map<String, dynamic> updateData, {File? diagramFile}) async {
    _isSaving = true;
    _creationError = null;
    notifyListeners();

    try {
      final updated = await _apiService.updateQuestion(id, updateData, diagramFile: diagramFile);
      final index = _questions.indexWhere((q) => q.id == id);
      if (index != -1) {
        _questions[index] = updated;
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _creationError = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      _creationError = 'Failed to update question.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuestion(String id) async {
    try {
      await _apiService.deleteQuestion(id);
      _questions.removeWhere((q) => q.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete question.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> bulkDeleteQuestions(List<String> ids) async {
    try {
      final results = await Future.wait(ids.map((id) => deleteQuestion(id)));
      return results.every((res) => res == true);
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF DOCUMENT PROCESSING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Upload PDF file and extract questions
  /// 
  /// Workflow:
  /// 1. Upload PDF file to backend
  /// 2. Backend processes via Mathpix PDF API
  /// 3. Extract questions using multi-question detection
  /// 4. Populate queue with extracted questions
  /// 5. Return results
  Future<Map<String, dynamic>?> uploadPdfAndExtractQuestions(
    File pdfFile, {
    Function(double)? onProgress,
  }) async {
    try {
      _isScanning = true;
      _creationError = null;
      notifyListeners();

      // Upload PDF and extract questions
      final response = await _apiService.uploadPdfAndExtractQuestions(
        pdfFile,
        onProgress: onProgress,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'];
        
        // Populate queue from extracted questions
        await _populateQueueFromOcrSession(data);
        
        _isScanning = false;
        _creationError = null;
        notifyListeners();
        
        return data;
      } else {
        throw Exception('Failed to extract questions from PDF');
      }
    } catch (error) {
      _isScanning = false;
      _creationError = 'PDF extraction error: $error';
      notifyListeners();
      return null;
    }
  }

  /// Check PDF processing status
  /// Used for polling the backend about PDF progress
  Future<Map<String, dynamic>> getPdfStatus(String pdfId) async {
    try {
      final response = await _apiService.getPdfStatus(pdfId);
      return response['data'] ?? {};
    } catch (error) {
      throw Exception('Failed to get PDF status: $error');
    }
  }

  /// Download PDF result in specific format
  /// Formats: mmd (markdown), docx, html, latex, lines_json
  Future<List<int>?> downloadPdfResult(String pdfId, String format) async {
    try {
      return await _apiService.downloadPdfResult(pdfId, format);
    } catch (error) {
      _creationError = 'Failed to download PDF result: $error';
      notifyListeners();
      return null;
    }
  }

  /// Submit PDF by URL for processing
  /// Useful for cloud storage URLs or remote documents
  Future<String?> submitPdfByUrl(String url, {
    bool extractQuestions = true,
  }) async {
    try {
      _isScanning = true;
      notifyListeners();

      final response = await _apiService.submitPdfByUrl(url);

      if (response != null && response['success'] == true) {
        final pdfId = response['data']['pdfId'];

        if (extractQuestions) {
          // Wait for processing and extract questions
          await _waitForPdfCompletion(pdfId);
          await _extractQuestionsFromPdfId(pdfId);
        }

        _isScanning = false;
        notifyListeners();
        return pdfId;
      }

      throw Exception('Failed to submit PDF by URL');
    } catch (error) {
      _isScanning = false;
      _creationError = 'Error: $error';
      notifyListeners();
      return null;
    }
  }

  /// Wait for PDF processing to complete
  /// Polls status until complete
  Future<void> _waitForPdfCompletion(String pdfId, {
    int maxWaitSeconds = 120,
    int pollIntervalSeconds = 2,
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      try {
        final status = await getPdfStatus(pdfId);
        
        if (status['status'] == 'completed') {
          return;
        }

        await Future.delayed(Duration(seconds: pollIntervalSeconds));
      } catch (error) {
        // Continue polling despite errors
        await Future.delayed(Duration(seconds: pollIntervalSeconds));
      }
    }

    throw Exception('PDF processing timeout after $maxWaitSeconds seconds');
  }

  /// Extract questions from already-processed PDF
  Future<void> _extractQuestionsFromPdfId(String pdfId) async {
    try {
      final response = await _apiService.extractQuestionsFromPdfId(pdfId);
      
      if (response != null && response['success'] == true) {
        final data = response['data'];
        await _populateQueueFromOcrSession(data);
      }
    } catch (error) {
      throw Exception('Failed to extract questions: $error');
    }
  }

  /// Delete PDF results from Mathpix
  /// WARNING: This is permanent
  Future<bool> deletePdf(String pdfId) async {
    try {
      final response = await _apiService.deletePdf(pdfId);
      return response?['success'] == true;
    } catch (error) {
      _creationError = 'Failed to delete PDF: $error';
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER: POPULATE QUEUE FROM OCR RESPONSE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Helper to populate queue from OCR API response
  /// Called after both image and PDF OCR to populate the question queue
  Future<void> _populateQueueFromOcr(Map<String, dynamic> ocrData) async {
    try {
      final questions = ocrData['questions'] as List?;
      if (questions == null || questions.isEmpty) {
        return;
      }

      // Convert to ScanData objects
      final scanDataList = <ScanData>[];
      final limit = questions.length > _maxQueueSize ? _maxQueueSize : questions.length;
      
      const int chunkSize = 15;
      for (int i = 0; i < limit; i += chunkSize) {
        final end = (i + chunkSize < limit) ? i + chunkSize : limit;
        for (int j = i; j < end; j++) {
          final q = questions[j];
          if (q is Map) {
            final List<String> extractedOptions = [];
            final rawOptions = q['options'];
            if (rawOptions is List) {
              for (var opt in rawOptions) {
                if (opt is Map) {
                  extractedOptions.add(opt['text']?.toString() ?? '');
                } else {
                  extractedOptions.add(opt?.toString() ?? '');
                }
              }
            }
            
            // Ensure exactly 4 options
            while (extractedOptions.length < 4) {
              extractedOptions.add('');
            }
            
            final scanData = ScanData(
              questionText: q['questionText'] ?? q['question'] ?? '',
              options: extractedOptions.sublist(0, 4),
              questionNumber: q['questionNumber']?.toString(),
              detectionOrder: (q['detectionOrder'] as num?)?.toInt() ?? j,
              rawOcrData: q['rawOcrData'] is Map ? Map<String, dynamic>.from(q['rawOcrData'] as Map) : null,
              verified: false,
            );
            scanDataList.add(scanData);
          }
        }
        // Yield execution to the event loop so the UI remains fluid
        await Future.delayed(Duration.zero);
      }

      if (questions.length > _maxQueueSize) {
        debugPrint('OCR queue capped at $_maxQueueSize items during OCR import.');
      }

      // Clear existing queue and populate
      _questionQueue = scanDataList;
      _currentQueueIndex = 0;
      _verificationHistory.clear();

      // OPTIMIZATION: Do not persist the bulky questions/detailed_info field to SharedPreferences.
      // This saves significant memory, serialization overhead, and disk IO time.
      _lastOcrResponse = Map<String, dynamic>.from(ocrData)
        ..remove('questions')
        ..remove('detailed_info');

      _persistQueueState();
      notifyListeners();
    } catch (error) {
      throw Exception('Failed to populate queue: $error');
    }
  }

  /// Helper to populate queue from OCR API session response
  Future<void> _populateQueueFromOcrSession(Map<String, dynamic> sessionData) async {
    try {
      _queueSessionId = (sessionData['sessionId'] ?? sessionData['queueSessionId'])?.toString();
      _currentQueueIndex = (sessionData['currentIndex'] as num?)?.toInt() ?? 0;
      
      final items = sessionData['items'] as List?;
      if (items == null || items.isEmpty) {
        _questionQueue = [];
        _currentQueueIndex = 0;
        _persistQueueState();
        notifyListeners();
        return;
      }

      final scanDataList = <ScanData>[];
      final limit = items.length > _maxQueueSize ? _maxQueueSize : items.length;

      const int chunkSize = 15;
      for (int i = 0; i < limit; i += chunkSize) {
        final end = (i + chunkSize < limit) ? i + chunkSize : limit;
        for (int j = i; j < end; j++) {
          final item = items[j];
          if (item is Map) {
            if (item['isDeleted'] == true) continue;
            
            final List<String> extractedOptions = [];
            final rawOptions = item['options'];
            if (rawOptions is List) {
              for (var opt in rawOptions) {
                if (opt is Map) {
                  extractedOptions.add(opt['text']?.toString() ?? '');
                } else {
                  extractedOptions.add(opt?.toString() ?? '');
                }
              }
            }
            
            while (extractedOptions.length < 4) {
              extractedOptions.add('');
            }
            
            final scanData = ScanData(
              questionText: item['questionText'] ?? item['question'] ?? '',
              options: extractedOptions.sublist(0, 4),
              questionNumber: item['questionNumber']?.toString(),
              detectionOrder: (item['detectionOrder'] as num?)?.toInt() ?? j,
              rawOcrData: item['rawOcrData'] is Map ? Map<String, dynamic>.from(item['rawOcrData'] as Map) : null,
              verified: item['verified'] ?? false,
              verifiedAt: item['verifiedAt'] != null ? DateTime.tryParse(item['verifiedAt'].toString()) : null,
            );
            scanDataList.add(scanData);
          }
        }
        // Yield execution to the event loop so the UI remains fluid
        await Future.delayed(Duration.zero);
      }

      if (items.length > _maxQueueSize) {
        debugPrint('OCR queue capped at $_maxQueueSize items during session restore.');
      }

      _questionQueue = scanDataList;
      if (_currentQueueIndex >= _questionQueue.length) {
        _currentQueueIndex = _questionQueue.isEmpty ? 0 : _questionQueue.length - 1;
      }
      _persistQueueState();
      notifyListeners();
    } catch (error) {
      throw Exception('Failed to populate queue from session: $error');
    }
  }
}
