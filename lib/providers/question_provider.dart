import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import 'dart:io';

enum QuestionLoadState { idle, loading, loaded, error }
enum QueueNavigationMode { sequential, random, skip }

/// Enhanced provider with multi-question queue management
class QuestionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Questions database
  List<Question> _questions = [];
  QuestionLoadState _loadState = QuestionLoadState.idle;
  String? _error;

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

  // ═══════════════════════════════════════════════════════════════════════════
  // QUESTION LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> loadQuestions({int? classNo, String? language}) async {
    _loadState = QuestionLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _questions = await _apiService.getQuestions(classNo: classNo, language: language);
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
      final ocrResult = await _apiService.processOcrImageWithRetry(imageFile);
      _lastOcrResponse = ocrResult;
      
      final rawText = ocrResult['rawText'] as String? ?? '';
      final latex = ocrResult['latex'] as String? ?? '';
      final confidence = ocrResult['confidence'] != null
          ? (ocrResult['confidence'] as num).toDouble() * 100
          : null;
      final hasContent = rawText.trim().isNotEmpty || latex.trim().isNotEmpty;

      if (!hasContent) {
        _creationError = 'Could not extract text from the image. Please ensure the photo is clear and well-lit.';
      } else {
        _populateQueueFromOcr(ocrResult, rawText, latex, confidence);
      }
    } on ApiException catch (e) {
      _creationError = e.message;
    } catch (e) {
      _creationError = 'Scanning failed: ${e.toString()}';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Populate queue from OCR response with enhanced data preservation
  void _populateQueueFromOcr(
    Map<String, dynamic> ocrResult,
    String rawText,
    String latex,
    double? confidence,
  ) {
    _questionQueue.clear();

    if (ocrResult.containsKey('parsedQuestions') && ocrResult['parsedQuestions'] != null) {
      final List<dynamic> parsedList = ocrResult['parsedQuestions'];

      for (var parsedItem in parsedList) {
        final parsed = Map<String, dynamic>.from(parsedItem);

        // Extract question text
        final String parsedQuestion = parsed['question'] ?? '';
        final List<dynamic> rawOptions = parsed['options'] ?? [];

        // Normalize options to List<String>
        List<String> options = [];
        for (var opt in rawOptions) {
          if (opt is Map) {
            options.add(opt['text']?.toString() ?? '');
          } else {
            options.add(opt.toString());
          }
        }

        // Ensure exactly 4 options
        while (options.length < 4) options.add('');
        if (options.length > 4) options = options.sublist(0, 4);

        // Use parsed question if available, otherwise full image text
        final String finalQuestionText = parsedQuestion.trim().isNotEmpty
            ? parsedQuestion
            : (latex.trim().isNotEmpty ? latex : rawText);

        // Create ScanData with enhanced data preservation
        _questionQueue.add(
          ScanData(
            questionText: finalQuestionText,
            options: options,
            correctAnswer: '',
            latex: latex,
            rawText: rawText,
            confidence: confidence,
            
            // NEW: Raw OCR preservation
            rawOcrData: parsed['rawOcrData'] ?? {
              'sourceUsed': ocrResult['detectionQuality']?['source'] ?? 'unknown',
              'rawText': rawText,
              'rawLatex': latex,
              'confidence': confidence,
            },
            questionNumber: parsed['questionNumber'],
            detectionOrder: parsed['detectionOrder'],
            verified: false,
          ),
        );
      }
    }

    // Fallback: If no structured questions were found, create single entry
    if (_questionQueue.isEmpty) {
      final questionText = latex.trim().isNotEmpty ? latex : rawText;
      _questionQueue.add(
        ScanData(
          questionText: questionText,
          options: ['', '', '', ''],
          correctAnswer: '',
          latex: latex,
          rawText: rawText,
          confidence: confidence,
          detectionOrder: 1,
          verified: false,
        ),
      );
    }

    print('[QuestionProvider] Queue populated: ${_questionQueue.length} questions');
    _currentQueueIndex = 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUEUE NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Move to next question in queue
  bool nextQuestion() {
    if (hasNextQuestion) {
      _currentQueueIndex++;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Move to previous question in queue
  bool previousQuestion() {
    if (hasPreviousQuestion) {
      _currentQueueIndex--;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Jump to specific index in queue
  bool jumpToIndex(int index) {
    if (index >= 0 && index < _questionQueue.length) {
      _currentQueueIndex = index;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Remove current question from queue
  bool removeCurrentQuestion() {
    if (_currentQueueIndex < _questionQueue.length) {
      _questionQueue.removeAt(_currentQueueIndex);
      if (_currentQueueIndex >= _questionQueue.length && _currentQueueIndex > 0) {
        _currentQueueIndex--;
      }
      notifyListeners();
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
      notifyListeners();
    }
  }

  /// Pop first question from queue and move to next (backward compatibility)
  void popQuestionFromQueue() {
    if (_questionQueue.isNotEmpty) {
      _verificationHistory.add(_questionQueue[0]);
      _questionQueue.removeAt(0);
      _currentQueueIndex = 0;
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
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update current question in queue
  void updateCurrentQuestion(ScanData updatedData) {
    if (_currentQueueIndex < _questionQueue.length) {
      _questionQueue[_currentQueueIndex] = updatedData;
      notifyListeners();
    }
  }

  /// Clear entire queue and reset
  void clearQueue() {
    _questionQueue.clear();
    _currentQueueIndex = 0;
    _verificationHistory.clear();
    _lastOcrResponse = null;
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
      final saved = await _apiService.createQuestionResilient(question, diagramFile: diagramFile);
      _questions.insert(0, saved);
      
      // Mark current queue item as verified if it exists
      if (_currentQueueIndex < _questionQueue.length) {
        markCurrentAsVerified(moveNext: true);
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
        
        // Store session ID for later reference
        _queueSessionId = data['queueSessionId'];
        
        // Populate queue from extracted questions
        await _populateQueueFromOcr(data);
        
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
        _queueSessionId = data['queueSessionId'];
        await _populateQueueFromOcr(data);
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
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final scanData = ScanData(
          questionText: q['questionText'] ?? q['question'] ?? '',
          options: q['options'] ?? [],
          format: q['format'] ?? 'mcq',
          language: q['language'] ?? 'English',
          questionNumber: q['questionNumber']?.toString(),
          detectionOrder: q['detectionOrder'] ?? i,
          rawOcrData: q['rawOcrData'] ?? q,
          verified: false,
        );
        scanDataList.add(scanData);
      }

      // Clear existing queue and populate
      _questionQueue = scanDataList;
      _currentQueueIndex = 0;
      _verificationHistory.clear();
      _lastOcrResponse = ocrData;

      notifyListeners();
    } catch (error) {
      throw Exception('Failed to populate queue: $error');
    }
  }
}
