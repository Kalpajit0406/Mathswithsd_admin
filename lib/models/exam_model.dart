class Exam {
  final String id;
  final String title;
  final int duration;
  final List<Question> questions;

  Exam({
    required this.id,
    required this.title,
    required this.duration,
    required this.questions,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      duration: json['duration'] ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}

class Question {
  final String id;
  final String type; // 'mcq' or 'numeric'
  final String questionText;
  final List<String>? options;
  final String? correctAnswer;

  Question({
    required this.id,
    required this.type,
    required this.questionText,
    this.options,
    this.correctAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      type: json['type'] ?? 'mcq',
      questionText: json['questionText'] ?? '',
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      correctAnswer: json['correctAnswer'],
    );
  }
}
