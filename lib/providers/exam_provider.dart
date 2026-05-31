import 'dart:async';
import 'package:flutter/material.dart';
import '../models/exam_model.dart';
import '../models/test_model.dart';
import '../services/api_service.dart';
import '../utils/resource_manager.dart';

enum LoadState { idle, loading, error, loaded }

class ExamProvider with ChangeNotifier, NotifierResourceDisposal {
  final ApiService _apiService = ApiService();
  
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _currentAttemptId;
  
  // Attempt State
  int _currentQuestionIndex = 0;
  Map<String, String> _userAnswers = {}; // questionId -> answer
  int _remainingSeconds = 0;
  Timer? _timer;

  // Added states for announcements and scheduled tests
  List<Announcement> _announcements = [];
  LoadState _announcementsState = LoadState.idle;
  String? _announcementsError;

  List<TestConfig> _scheduledTests = [];
  LoadState _testsState = LoadState.idle;

  List<Exam> get exams => _exams;
  bool get isLoading => _isLoading;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, String> get userAnswers => _userAnswers;
  int get remainingSeconds => _remainingSeconds;

  List<Announcement> get announcements => _announcements;
  LoadState get announcementsState => _announcementsState;
  String? get announcementsError => _announcementsError;

  List<TestConfig> get scheduledTests => _scheduledTests;
  LoadState get testsState => _testsState;

  Future<void> loadAnnouncements({String? targetClass}) async {
    _announcementsState = LoadState.loading;
    _announcementsError = null;
    notifyListeners();
    try {
      _announcements = await _apiService.getAnnouncements(targetClass: targetClass);
      _announcementsState = LoadState.loaded;
    } catch (e) {
      _announcementsError = 'Failed to load announcements';
      _announcementsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> bulkDeleteAnnouncements(List<String> ids, {String? targetClass}) async {
    try {
      await _apiService.bulkDeleteAnnouncements(ids);
      await loadAnnouncements(targetClass: targetClass);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> loadTests() async {
    _testsState = LoadState.loading;
    notifyListeners();
    try {
      _scheduledTests = await _apiService.getAllTests();
      _testsState = LoadState.loaded;
    } catch (e) {
      _testsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> fetchExams(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      _exams = await _apiService.fetchExams(token);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startExam(String examId, String token) async {
    _currentQuestionIndex = 0;
    _userAnswers = {};
    // Find the exam to get its duration
    final exam = _exams.firstWhere((e) => e.id == examId);
    _remainingSeconds = exam.duration * 60;
    
    try {
      _currentAttemptId = await _apiService.startAttempt(examId, token);
      _startTimer();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = createSafeTimer(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
      }
    });
  }

  void setAnswer(String questionId, String answer) {
    _userAnswers[questionId] = answer;
    notifyListeners();
  }

  void nextQuestion(int totalQuestions) {
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  Future<void> submitExam(List<Map<String, dynamic>> answers, String token) async {
    if (_currentAttemptId == null) return;
    
    _timer?.cancel();
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.submitAnswers(
        attemptId: _currentAttemptId!,
        answers: answers,
        token: token,
      );
      _currentAttemptId = null;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
