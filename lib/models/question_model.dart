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
      classNo: json['classNo'] ?? 10,
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
  final double? confidence;  // OCR confidence score (0-100)
  final double? difficulty;  // Question difficulty estimate (1-5)
  
  // NEW: Raw OCR preservation for recovery/debugging
  final Map<String, dynamic>? rawOcrData;  // Original raw OCR response
  final String? questionNumber;             // Detected question number
  final int? detectionOrder;                // Order in multi-question extraction
  final bool verified;                      // Whether teacher has verified this
  final DateTime? verifiedAt;               // When it was verified
  final String? verificationNotes;          // Any notes from verification

  ScanData({
    required this.questionText,
    required this.options,
    this.correctAnswer,
    this.latex,
    this.rawText,
    this.confidence,
    this.difficulty,
    this.rawOcrData,
    this.questionNumber,
    this.detectionOrder,
    this.verified = false,
    this.verifiedAt,
    this.verificationNotes,
  });

  factory ScanData.fromJson(Map<String, dynamic> json) {
    // Safely extract options: handles both List<String> and List<Map> formats
    final rawOptions = json['options'] as List? ?? [];
    final List<String> parsedOptions = [];
    for (var opt in rawOptions) {
      if (opt is Map) {
        parsedOptions.add(opt['text']?.toString() ?? '');
      } else {
        parsedOptions.add(opt?.toString() ?? '');
      }
    }
    // Ensure exactly 4 options
    while (parsedOptions.length < 4) {
      parsedOptions.add('');
    }

    return ScanData(
      questionText: json['questionText'] ?? json['question'] ?? '',
      options: parsedOptions.sublist(0, 4),
      correctAnswer: json['correctAnswer'],
      latex: json['latex'],
      rawText: json['rawText'],
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : null,
      difficulty: json['difficulty'] != null ? (json['difficulty'] as num).toDouble() : null,
      rawOcrData: json['rawOcrData'] as Map<String, dynamic>?,
      questionNumber: json['questionNumber'],
      detectionOrder: json['detectionOrder'],
      verified: json['verified'] ?? false,
      verifiedAt: json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt']) : null,
      verificationNotes: json['verificationNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionText': questionText,
      'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      if (latex != null) 'latex': latex,
      if (rawText != null) 'rawText': rawText,
      if (confidence != null) 'confidence': confidence,
      if (difficulty != null) 'difficulty': difficulty,
      if (rawOcrData != null) 'rawOcrData': rawOcrData,
      if (questionNumber != null) 'questionNumber': questionNumber,
      if (detectionOrder != null) 'detectionOrder': detectionOrder,
      'verified': verified,
      if (verifiedAt != null) 'verifiedAt': verifiedAt?.toIso8601String(),
      if (verificationNotes != null) 'verificationNotes': verificationNotes,
    };
  }

  /// Create a copy of ScanData with modifications
  ScanData copyWith({
    String? questionText,
    List<String>? options,
    String? correctAnswer,
    String? latex,
    String? rawText,
    double? confidence,
    double? difficulty,
    Map<String, dynamic>? rawOcrData,
    String? questionNumber,
    int? detectionOrder,
    bool? verified,
    DateTime? verifiedAt,
    String? verificationNotes,
  }) {
    return ScanData(
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      latex: latex ?? this.latex,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
      difficulty: difficulty ?? this.difficulty,
      rawOcrData: rawOcrData ?? this.rawOcrData,
      questionNumber: questionNumber ?? this.questionNumber,
      detectionOrder: detectionOrder ?? this.detectionOrder,
      verified: verified ?? this.verified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationNotes: verificationNotes ?? this.verificationNotes,
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
