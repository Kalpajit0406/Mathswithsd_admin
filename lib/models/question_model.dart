class Question {
  final String? id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final int classNo;
  final String language;
  final String chapter;
  final String? diagram;

  Question({
    this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.classNo,
    required this.language,
    required this.chapter,
    this.diagram,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['_id'],
      questionText: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
      classNo: json['classNo'] ?? 0,
      language: json['language'] ?? 'English',
      chapter: json['chapter'] ?? '',
      diagram: json['diagram'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'question': questionText,
      'options': options,
      'correctAnswer': correctAnswer,
      'classNo': classNo,
      'language': language,
      'chapter': chapter,
      if (diagram != null) 'diagram': diagram,
    };
  }
}

// OCR scan result from AI backend
class ScanData {
  final String questionText;
  final List<String> options;
  final String? correctAnswer;
  final String? latex;
  final String? rawText;

  ScanData({
    required this.questionText,
    required this.options,
    this.correctAnswer,
    this.latex,
    this.rawText,
  });

  factory ScanData.fromJson(Map<String, dynamic> json) {
    return ScanData(
      questionText: json['questionText'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'],
      latex: json['latex'],
      rawText: json['rawText'],
    );
  }
}

// For exam taking
class ExamQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final String? diagram;

  ExamQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    this.diagram,
  });

  factory ExamQuestion.fromQuestion(Question q) {
    return ExamQuestion(
      id: q.id ?? '',
      questionText: q.questionText,
      options: q.options,
      diagram: q.diagram,
    );
  }
}

// Answer state during exam
class AnswerState {
  final int selectedOptionIndex; // -1 = unanswered
  final bool markedForReview;

  const AnswerState({
    this.selectedOptionIndex = -1,
    this.markedForReview = false,
  });

  AnswerState copyWith({int? selectedOptionIndex, bool? markedForReview}) {
    return AnswerState(
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      markedForReview: markedForReview ?? this.markedForReview,
    );
  }
}
