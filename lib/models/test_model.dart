class TestConfig {
  final String id;
  final String date;
  final String time;
  final int classNo;
  final String language;
  final int totalQuestions;
  final int totalTime; // in minutes
  final double negativeMarking;
  final double marksPerQuestion;
  final List<String> chapters;

  TestConfig({
    required this.id,
    required this.date,
    required this.time,
    required this.classNo,
    required this.language,
    required this.totalQuestions,
    required this.totalTime,
    this.negativeMarking = 0.0,
    this.marksPerQuestion = 1.0,
    this.chapters = const [],
  });

  factory TestConfig.fromJson(Map<String, dynamic> json) {
    return TestConfig(
      id: json['_id'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      classNo: json['classNo'] ?? 10,
      language: json['language'] ?? 'English',
      totalQuestions: json['totalQuestions'] ?? 0,
      totalTime: json['totalTime'] ?? 0,
      negativeMarking: (json['negativeMarking'] ?? 0.0).toDouble(),
      marksPerQuestion: (json['marksPerQuestion'] ?? 1.0).toDouble(),
      chapters: List<String>.from(json['chapters'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'time': time,
      'classNo': classNo,
      'language': language,
      'totalQuestions': totalQuestions,
      'totalTime': totalTime,
      'negativeMarking': negativeMarking,
      'marksPerQuestion': marksPerQuestion,
      'chapters': chapters,
    };
  }
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final String? image;
  final String targetClass;
  final String createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.image,
    required this.targetClass,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      image: json['image'],
      targetClass: json['targetClass'] ?? 'all',
      createdAt: json['createdAt'] ?? '',
    );
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}
