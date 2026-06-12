import 'package:flutter/foundation.dart';
import '../models/question_model.dart';

class ExtractedQuestion {
  final int questionNumber;
  final String question;
  final List<String> options;
  final String type;

  ExtractedQuestion({
    required this.questionNumber,
    required this.question,
    required this.options,
    required this.type,
  });
}

class LatexExtractorService {
  // Process Mathpix content - preserves mathematical symbols and cleans artifacts
  static String cleanContent(String text) {
    String cleaned = text;

    // Remove specific Mathpix HTML artifacts while preserving math content
    cleaned = cleaned.replaceAllMapped(RegExp(r'<span[^>]*class="katex[^"]*"[^>]*>(.*?)</span>', dotAll: true), (m) => m[1] ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'<math[^>]*>(.*?)</math>', dotAll: true), (m) => m[1] ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'<asciimath[^>]*>(.*?)</asciimath>', dotAll: true), (m) => m[1] ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'<latex[^>]*>(.*?)</latex>', dotAll: true), (m) => m[1] ?? '');
    cleaned = cleaned.replaceAll(RegExp(r'=<span.*?</span>', dotAll: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'=<spanclass="katex−display">.*?</span>', dotAll: true), '');

    // Remove HTML attributes but preserve content
    cleaned = cleaned.replaceAll(RegExp(r'class="[^"]*"'), '');
    cleaned = cleaned.replaceAll(RegExp(r'style="[^"]*"'), '');
    cleaned = cleaned.replaceAll(RegExp(r'display:\s*none;?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'aria−hidden="true"'), '');
    cleaned = cleaned.replaceAll(RegExp(r'mathbackground="[^"]*"'), '');
    cleaned = cleaned.replaceAll(RegExp(r'width="[^"]*"'), '');
    cleaned = cleaned.replaceAll(RegExp(r'height="[^"]*"'), '');

    // Preserve mathematical inequalities before removing HTML
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\$[^$]*)<([^$]*\$)'), (m) => '${m[1]}LESS_THAN${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\$[^$]*)>([^$]*\$)'), (m) => '${m[1]}GREATER_THAN${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w+|\d+)\s*&lt;\s*(\w+|\d+)'), (m) => '${m[1]} LESS_THAN ${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w+|\d+)\s*&gt;\s*(\w+|\d+)'), (m) => '${m[1]} GREATER_THAN ${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w+|\d+)\s*<\s*(\w+|\d+)'), (m) => '${m[1]} LESS_THAN ${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w+|\d+)\s*>\s*(\w+|\d+)'), (m) => '${m[1]} GREATER_THAN ${m[2]}');
    
    // Convert \[...\] to $...$
    cleaned = cleaned.replaceAllMapped(RegExp(r'\\\[(.*?)\\\]', dotAll: true), (m) => r'$' + (m[1] ?? '') + r'$');

    // Remove HTML tags (selective)
    cleaned = cleaned.replaceAll(RegExp(r'</?(?:div|span|p|br|hr|table|tr|td|th)[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<(?!/?(b|i|u|strong|em|sub|sup)\b)[^>]*>', caseSensitive: false), '');

    // Restore mathematical symbols
    cleaned = cleaned.replaceAll('LESS_THAN', '<');
    cleaned = cleaned.replaceAll('GREATER_THAN', '>');

    // Clean HTML entities
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&#39;', "'");

    // Fix spacing
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w)(\$\vec\{)'), (m) => '${m[1]} ${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\w)(\$[^$]*\$)'), (m) => '${m[1]} ${m[2]}');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\$[^$]*\$)(\w)'), (m) => '${m[1]} ${m[2]}');

    // Normalize math delimiters
    cleaned = cleaned.replaceAll(RegExp(r'\$\s*\$\s*'), ' ');
    
    // Fix OCR errors
    cleaned = cleaned.replaceAll('−', '-');
    // Replace spaces and tabs with single space, but preserve newlines
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    // Collapse consecutive newlines (3 or more) to a maximum of 2 newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return cleaned.trim();
  }

  static List<String> extractOptions(String text) {
    List<String> options = [];

    // Pattern 1: (a) option (b) option (Most common in Mathpix)
    final pattern1 = RegExp(r'\(([abcdABCD1234])\)\s*([^()]*?)(?=\s*\([abcdABCD1234]\)|$)');
    final matches1 = pattern1.allMatches(text);
    if (matches1.length >= 4) {
      for (var m in matches1.take(4)) {
        options.add(m.group(2)!.trim());
      }
      return options;
    }

    // Pattern 2: [a] option [b] option
    final pattern2 = RegExp(r'\[([abcdABCD1234])\]\s*([^\[\]]*?)(?=\s*\[[abcdABCD1234]\]|$)');
    final matches2 = pattern2.allMatches(text);
    if (matches2.length >= 4) {
      for (var m in matches2.take(4)) {
        options.add(m.group(2)!.trim());
      }
      return options;
    }

    // Pattern 3: Line separated a. option
    final lines = text.split(RegExp(r'\n+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final optionLines = lines.where((l) => 
      RegExp(r'^\s*\([abcdABCD1234]\)', caseSensitive: false).hasMatch(l) || 
      RegExp(r'^\s*[abcdABCD1234][\.\)]', caseSensitive: false).hasMatch(l)
    ).toList();

    if (optionLines.length >= 4) {
      for (var l in optionLines.take(4)) {
        options.add(l.replaceFirst(RegExp(r'^\s*[\(\[]?[abcdABCD1234][\.\)\]]\s*', caseSensitive: false), '').trim());
      }
      return options;
    }

    // Pattern 4: Broad scan for a) b) c) d)
    final pattern4 = RegExp(r'([abcdABCD1234])[\)\.]\s*([^.\n]+?)(?=\s*[abcdABCD1234][\)\.]|$)');
    final matches4 = pattern4.allMatches(text);
    if (matches4.length >= 4) {
      for (var m in matches4.take(4)) {
        options.add(m.group(2)!.trim());
      }
      return options;
    }

    return [];
  }

  static Map<String, dynamic> separateQuestionFromOptions(String text) {
    String cleaned = cleanContent(text);
    // Remove question number
    String textWithoutNumber = cleaned.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');

    // Try to find where options start
    final optionStartPatterns = [
      RegExp(r'\n\s*\([abcdABCD]\)', caseSensitive: false),
      RegExp(r'\([abcdABCD]\)\s+', caseSensitive: false),
      RegExp(r'\n\s*[abcdABCD][\.\)]', caseSensitive: false),
      RegExp(r'[^a-zA-Z][abcdABCD][\.\)]\s', caseSensitive: false),
    ];

    int splitIndex = -1;
    for (var p in optionStartPatterns) {
      final match = p.firstMatch(textWithoutNumber);
      if (match != null) {
        if (splitIndex == -1 || match.start < splitIndex) {
          splitIndex = match.start;
        }
      }
    }

    if (splitIndex != -1 && splitIndex > 0) {
      final questionPart = textWithoutNumber.substring(0, splitIndex).trim();
      final optionsPart = textWithoutNumber.substring(splitIndex).trim();
      final options = extractOptions(optionsPart);
      return {'question': questionPart, 'options': options};
    }

    // Fallback: extract options from entire text
    final options = extractOptions(textWithoutNumber);
    if (options.isNotEmpty) {
      String questionText = textWithoutNumber;
      for (var opt in options) {
        questionText = questionText.replaceAll(opt, '').trim();
      }
      // Very basic cleaning of the remaining question text
      questionText = questionText.replaceAll(RegExp(r'[\(\)][abcdABCD][\.\)]', caseSensitive: false), '').trim();
      return {'question': questionText, 'options': options};
    }

    return {'question': textWithoutNumber, 'options': <String>[]};
  }

  static List<ScanData> extractQuestions(String rawText) {
    final List<ScanData> results = [];
    
    try {
      // Improved split pattern: Handles '1.', '1)', '(1)', and numbered lines at the start of newlines
      final splitPattern = RegExp(r'\n(?=\s*\d+[\.\)](?!\d))|(?<=\n)\s*(?=\d+[\.\)](?!\d))|(?<=\$)\s*(?=\d+[\.\)](?!\d))');
      final sections = rawText.split(splitPattern);
      
      for (var section in sections) {
        if (section.trim().isEmpty) continue;
        
        try {
          final parsed = separateQuestionFromOptions(section);
          String questionText = parsed['question'];
          List<String> options = List<String>.from(parsed['options']);
          
          // Ensure 4 options
          while (options.length < 4) {
            options.add('');
          }
          if (options.length > 4) {
            options = options.sublist(0, 4);
          }

          results.add(ScanData(
            questionText: questionText,
            options: options,
            correctAnswer: '',
            rawText: section.trim()
          ));
        } catch (e) {
          if (kDebugMode) debugPrint('[LatexExtractorService] Error parsing question section: $e');
          // Fallback for this specific section
          results.add(ScanData(
            questionText: cleanContent(section),
            options: ['', '', '', ''],
            correctAnswer: '',
            rawText: section.trim()
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LatexExtractorService] Critical error in extractQuestions: $e');
    }

    if (results.isEmpty && rawText.trim().isNotEmpty) {
      results.add(ScanData(
        questionText: cleanContent(rawText),
        options: ['', '', '', ''],
        correctAnswer: '',
        rawText: rawText.trim()
      ));
    }

    return results;
  }
}
