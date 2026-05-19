import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import 'dart:io';

enum QuestionLoadState { idle, loading, loaded, error }

class QuestionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Question> _questions = [];
  QuestionLoadState _loadState = QuestionLoadState.idle;
  String? _error;

  // Question creation / OCR state
  List<ScanData> _questionQueue = [];
  bool _isScanning = false;
  bool _isSaving = false;
  String? _creationError;

  // Getters
  List<Question> get questions => _questions;
  QuestionLoadState get loadState => _loadState;
  String? get error => _error;
  List<ScanData> get questionQueue => _questionQueue;
  bool get isScanning => _isScanning;
  bool get isSaving => _isSaving;
  String? get creationError => _creationError;

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

  Future<void> scanImage(File imageFile) async {
    _isScanning = true;
    _creationError = null;
    notifyListeners();

    try {
      // Stream OCR with rich preprocessed results from server pipeline
      final ocrResult = await _apiService.processOcrImageWithRetry(imageFile);
      final rawText = ocrResult['rawText'] as String? ?? '';
      final latex = ocrResult['latex'] as String? ?? '';
      final confidence = ocrResult['confidence'] != null
          ? (ocrResult['confidence'] as num).toDouble() * 100
          : null;
      final hasContent = rawText.trim().isNotEmpty || latex.trim().isNotEmpty;

      if (!hasContent) {
        _creationError = 'Could not extract text from the image. Please ensure the photo is clear and well-lit.';
      } else {
        _questionQueue.clear();

        if (ocrResult.containsKey('parsedQuestions') && ocrResult['parsedQuestions'] != null) {
          final List<dynamic> parsedList = ocrResult['parsedQuestions'];
          
          for (var parsedItem in parsedList) {
            final parsed = Map<String, dynamic>.from(parsedItem);
            
            // Because we pass latex to the detector, 'question' is already latex-formatted
            final String parsedQuestion = parsed['question'] ?? '';
            final List<dynamic> rawOptions = parsed['options'] ?? [];
            
            List<String> options = [];
            for (var opt in rawOptions) {
              if (opt is Map) {
                options.add(opt['text']?.toString() ?? '');
              } else {
                options.add(opt.toString());
              }
            }
            
            // Ensure exactly 4 options are populated
            while (options.length < 4) {
              options.add('');
            }
            if (options.length > 4) {
              options = options.sublist(0, 4);
            }
            
            // We use parsedQuestion if available, otherwise fall back to the full image text
            final String finalQuestionText = parsedQuestion.trim().isNotEmpty 
                ? parsedQuestion 
                : (latex.trim().isNotEmpty ? latex : rawText);
                
            _questionQueue.add(
              ScanData(
                questionText: finalQuestionText,
                options: options,
                correctAnswer: '',
                latex: latex, // Keep full original image latex for reference/debugging
                rawText: rawText, // Keep full original image text for reference/debugging
                confidence: confidence,
              )
            );
          }
        }
        
        // Fallback: If no structured questions were found, create a single entry
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
            )
          );
        }
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

  void popQuestionFromQueue() {
    if (_questionQueue.isNotEmpty) {
      _questionQueue.removeAt(0);
    }
    notifyListeners();
  }

  Future<bool> saveQuestion(Question question, {File? diagramFile}) async {
    _isSaving = true;
    _creationError = null;
    notifyListeners();

    try {
      final saved = await _apiService.createQuestionResilient(question, diagramFile: diagramFile);
      _questions.insert(0, saved);
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

  void clearQueue() {
    _questionQueue = [];
    notifyListeners();
  }
}
