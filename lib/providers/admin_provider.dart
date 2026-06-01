import 'package:flutter/material.dart';
import '../models/test_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Students
  List<StudentUser> _pendingStudents = [];
  List<StudentUser> _verifiedStudents = [];
  List<StudentUser> _rejectedStudents = [];
  LoadState _studentsState = LoadState.idle;
  String? _studentsError;

  // Tests
  List<TestConfig> _tests = [];
  LoadState _testsState = LoadState.idle;
  String? _testsError;
  bool _isCreatingTest = false;
  String? _createTestError;
  bool _createTestSuccess = false;

  // Announcements
  List<Announcement> _announcements = [];
  LoadState _announcementsState = LoadState.idle;
  String? _announcementsError;
  bool _isCreatingAnnouncement = false;
  String? _createAnnouncementError;
  bool _createAnnouncementSuccess = false;

  // ─── Getters ──────────────────────────────────────────────────────────────────

  List<StudentUser> get pendingStudents => _pendingStudents;
  List<StudentUser> get verifiedStudents => _verifiedStudents;
  List<StudentUser> get rejectedStudents => _rejectedStudents;
  LoadState get studentsState => _studentsState;
  String? get studentsError => _studentsError;

  List<TestConfig> get tests => _tests;
  LoadState get testsState => _testsState;
  String? get testsError => _testsError;
  bool get isCreatingTest => _isCreatingTest;
  String? get createTestError => _createTestError;
  bool get createTestSuccess => _createTestSuccess;

  List<Announcement> get announcements => _announcements;
  LoadState get announcementsState => _announcementsState;
  String? get announcementsError => _announcementsError;
  bool get isCreatingAnnouncement => _isCreatingAnnouncement;
  String? get createAnnouncementError => _createAnnouncementError;
  bool get createAnnouncementSuccess => _createAnnouncementSuccess;

  // ─── Students ─────────────────────────────────────────────────────────────────

  Future<void> loadStudents() async {
    _studentsState = LoadState.loading;
    _studentsError = null;
    notifyListeners();

    try {
      final data = await _apiService.getAllStudents();
      _pendingStudents = data['unverified'] ?? [];
      _verifiedStudents = data['verified'] ?? [];
      _rejectedStudents = data['rejected'] ?? [];
      _studentsState = LoadState.loaded;
    } on ApiException catch (e) {
      _studentsError = e.message;
      _studentsState = LoadState.error;
    } catch (e) {
      _studentsError = 'Failed to load students.';
      _studentsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> acceptStudent(String id) async {
    try {
      await _apiService.acceptStudent(id);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectStudent(String id) async {
    try {
      await _apiService.rejectStudent(id);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> bulkAcceptStudents(List<String> ids) async {
    try {
      await _apiService.bulkAcceptStudents(ids);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> bulkRejectStudents(List<String> ids) async {
    try {
      await _apiService.bulkRejectStudents(ids);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> bulkDeleteStudents(List<String> ids) async {
    try {
      await _apiService.bulkDeleteStudents(ids);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resolveProfileEdit(String studentId, bool approve) async {
    try {
      await _apiService.approveProfileEdit(studentId, approve);
      await loadStudents();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Tests ────────────────────────────────────────────────────────────────────

  Future<void> loadTests() async {
    _testsState = LoadState.loading;
    _testsError = null;
    notifyListeners();

    try {
      _tests = await _apiService.getAllTests();
      _testsState = LoadState.loaded;
    } on ApiException catch (e) {
      _testsError = e.message;
      _testsState = LoadState.error;
    } catch (e) {
      _testsError = 'Failed to load tests.';
      _testsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> createTest({
    required String date,
    required String time,
    required int classNo,
    required String language,
    required int totalQuestions,
    required int totalTime,
    double negativeMarking = 0.0,
    double marksPerQuestion = 1.0,
    List<String> chapters = const [],
  }) async {
    _isCreatingTest = true;
    _createTestError = null;
    _createTestSuccess = false;
    notifyListeners();

    try {
      final test = await _apiService.createTest({
        'date': date,
        'time': time,
        'classNo': classNo,
        'language': language,
        'totalQuestions': totalQuestions,
        'totalTime': totalTime,
        'negativeMarking': negativeMarking,
        'marksPerQuestion': marksPerQuestion,
        'chapters': chapters,
      });
      _tests.insert(0, test);
      _createTestSuccess = true;
    } on ApiException catch (e) {
      _createTestError = e.message;
    } catch (e) {
      _createTestError = 'Failed to create test. Check your connection.';
    }

    _isCreatingTest = false;
    notifyListeners();
    return _createTestSuccess;
  }

  void resetTestCreationStatus() {
    _createTestError = null;
    _createTestSuccess = false;
    notifyListeners();
  }

  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<void> loadAnnouncements({String? targetClass}) async {
    _announcementsState = LoadState.loading;
    _announcementsError = null;
    notifyListeners();

    try {
      _announcements = await _apiService.getAnnouncements(targetClass: targetClass);
      _announcementsState = LoadState.loaded;
    } on ApiException catch (e) {
      _announcementsError = e.message;
      _announcementsState = LoadState.error;
    } catch (e) {
      _announcementsError = 'Failed to load announcements.';
      _announcementsState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> createAnnouncement({
    required String title,
    required String message,
    String? imageUrl,
    required String targetClass,
  }) async {
    _isCreatingAnnouncement = true;
    _createAnnouncementError = null;
    _createAnnouncementSuccess = false;
    notifyListeners();

    try {
      final ann = await _apiService.createAnnouncement({
        'title': title,
        'message': message,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
        'targetClass': targetClass,
      });
      _announcements.insert(0, ann);
      _createAnnouncementSuccess = true;
    } on ApiException catch (e) {
      _createAnnouncementError = e.message;
    } catch (e) {
      _createAnnouncementError = 'Failed to create announcement.';
    }

    _isCreatingAnnouncement = false;
    notifyListeners();
    return _createAnnouncementSuccess;
  }

  void resetAnnouncementCreationStatus() {
    _createAnnouncementError = null;
    _createAnnouncementSuccess = false;
    notifyListeners();
  }
}
