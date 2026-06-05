import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlannedExam {
  final String id;
  final String title;
  final int classNo;
  final String chapters;
  final DateTime dateTime;
  final String personalNotes;

  PlannedExam({
    required this.id,
    required this.title,
    required this.classNo,
    required this.chapters,
    required this.dateTime,
    required this.personalNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'classNo': classNo,
        'chapters': chapters,
        'dateTime': dateTime.toIso8601String(),
        'personalNotes': personalNotes,
      };

  factory PlannedExam.fromJson(Map<String, dynamic> json) => PlannedExam(
        id: json['id'],
        title: json['title'],
        classNo: json['classNo'] is int ? json['classNo'] : int.parse(json['classNo'].toString()),
        chapters: json['chapters'],
        dateTime: DateTime.parse(json['dateTime']),
        personalNotes: json['personalNotes'] ?? '',
      );
}

class PlannerProvider with ChangeNotifier {
  List<PlannedExam> _plannedExams = [];
  bool _isLoading = false;

  List<PlannedExam> get plannedExams => _plannedExams;
  bool get isLoading => _isLoading;

  List<PlannedExam> get upcomingExams {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // Include exams scheduled for today or later
    return _plannedExams.where((exam) => exam.dateTime.isAfter(todayStart) || 
        (exam.dateTime.year == now.year && exam.dateTime.month == now.month && exam.dateTime.day == now.day)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<void> loadPlanner() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final plannerData = prefs.getString('test_planner_events');
      if (plannerData != null) {
        final List<dynamic> jsonList = jsonDecode(plannerData);
        _plannedExams = jsonList.map((item) => PlannedExam.fromJson(item)).toList();
      } else {
        _plannedExams = [];
      }
    } catch (e) {
      debugPrint('Error loading planner data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExam(PlannedExam exam) async {
    _plannedExams.add(exam);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> deleteExam(String id) async {
    _plannedExams.removeWhere((e) => e.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_plannedExams.map((e) => e.toJson()).toList());
      await prefs.setString('test_planner_events', jsonString);
    } catch (e) {
      debugPrint('Error saving planner data: $e');
    }
  }
}
