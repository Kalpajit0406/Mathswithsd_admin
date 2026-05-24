import 'package:flutter_test/flutter_test.dart';
import 'package:mathswithsd_admin/services/latex_extractor_service.dart';

void main() {
  group('LatexExtractorService Tests', () {
    test('cleanContent removes Mathpix HTML artifacts', () {
      const input = '<span class="katex">x^2 + y^2</span> and some text.';
      final result = LatexExtractorService.cleanContent(input);
      expect(result, contains('x^2 + y^2'));
      expect(result, isNot(contains('<span')));
    });

    test('extractQuestions splits multiple questions correctly', () {
      const raw = '1. First question (a) opt1 (b) opt2 (c) opt3 (d) opt4\n2. Second question (a) s1 (b) s2 (c) s3 (d) s4';
      final results = LatexExtractorService.extractQuestions(raw);
      expect(results.length, 2);
      expect(results[0].questionText, contains('First question'));
      expect(results[1].questionText, contains('Second question'));
      expect(results[0].options.length, 4);
    });

    test('extractQuestions splits when there is no space between closing \$ and next question number', () {
      const raw = '11. The probability of getting 11 when an ordinary die is thrown twice is- (A) \$\\frac{1}{18}\$(B)\$\\frac{1}{9}\$(C)\$ \\frac{1}{12}\$(D)\$\\frac{5}{36}\$12. Two events\$A\$and\$B\$are mutually exclusive; if\$P(A)=\\frac{1}{2}\$';
      final results = LatexExtractorService.extractQuestions(raw);
      expect(results.length, 2);
      expect(results[0].questionText, contains('ordinary die is thrown twice'));
      expect(results[1].questionText, contains('Two events'));
    });

    test('extractOptions handles (a) pattern', () {
      const input = '(a) Apple (b) Ball (c) Cat (d) Dog';
      final options = LatexExtractorService.extractOptions(input);
      expect(options, ['Apple', 'Ball', 'Cat', 'Dog']);
    });
  });
}
