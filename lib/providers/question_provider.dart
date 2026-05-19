import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import '../services/latex_extractor_service.dart';
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
      // Memory efficient streaming OCR
      final rawMarkdown = await _apiService.processOcrImage(imageFile);
      
      if (rawMarkdown.trim().isEmpty) {
        _creationError = 'Could not extract text from the image.';
      } else {
        _questionQueue = LatexExtractorService.extractQuestions(rawMarkdown);
      }
    } on ApiException catch (e) {
      _creationError = e.message;
    } catch (e) {
      _creationError = 'Scanning failed. Please try again.';
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
