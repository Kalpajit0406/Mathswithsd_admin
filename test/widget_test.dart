import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathswithsd_admin/providers/auth_provider.dart';
import 'package:mathswithsd_admin/providers/admin_provider.dart';
import 'package:mathswithsd_admin/providers/exam_provider.dart';
import 'package:mathswithsd_admin/providers/question_provider.dart';
import 'package:mathswithsd_admin/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
          ChangeNotifierProvider(create: (_) => ExamProvider()),
          ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ],
        child: const MathsWithSDApp(),
      ),
    );

    // Verify we load the login page
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
