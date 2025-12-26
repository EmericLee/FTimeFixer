// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/time_analyzer.dart';

void main() {
  // testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  //   // Build our app navigator to demo page and trigger a frame.
  //   await tester.pumpWidget(const MyApp());

  //   // Verify that our counter starts at 0.
  //   expect(find.text('0'), findsOneWidget);
  //   expect(find.text('1'), findsNothing);

  //   // Tap the '+' icon and trigger a frame.
  //   await tester.tap(find.byIcon(Icons.add));
  //   await tester.pump();

  //   // Verify that our counter has incremented.
  //   expect(find.text('0'), findsNothing);
  //   expect(find.text('1'), findsOneWidget);
  // });

  group('extractFromName tests', () {
    test('should extract date from YYYY/MM/DD HH:MM:SS format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/2023/06/05/2023/06/05 10:15:30.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 10);
      expect(result?.minute, 15);
      expect(result?.second, 30);
    });

    test('should extract date from YYYY-MM-DD HH:MM:SS format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/2023-06-05 10:15:30.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 10);
      expect(result?.minute, 15);
      expect(result?.second, 30);
    });

    test('should extract date from YYYYMMDD HH:MM:SS format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/20230605 10:15:30.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 10);
      expect(result?.minute, 15);
      expect(result?.second, 30);
    });

    test('should extract date from YYYYMMDD_HHMMSS format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/20230605_101530.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 10);
      expect(result?.minute, 15);
      expect(result?.second, 30);
    });

    test('should extract date from YYYYMMDDHHMMSS format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/20230605101530.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 10);
      expect(result?.minute, 15);
      expect(result?.second, 30);
    });

    test('should extract date from YYYYMMDD format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/20230605.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 0);
      expect(result?.minute, 0);
      expect(result?.second, 0);
    });

    test('should extract date from YYYY-MM-DD format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/2023-06-05.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 0);
      expect(result?.minute, 0);
      expect(result?.second, 0);
    });

    test('should extract date from YYYY/MM/DD format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/2023/06/05.jpg');
      expect(result, isNotNull);
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 0);
      expect(result?.minute, 0);
      expect(result?.second, 0);
    });

    test('should extract date from 10-digit Unix timestamp', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/1685955357.jpg');
      expect(result, isNotNull);
      // 1685955357 对应的时间是 2023-06-05 10:15:57
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 16);
      expect(result?.minute, 55);
      expect(result?.second, 57);
    });

    test('should extract date from 13-digit Unix timestamp', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/1685955357378.jpg');
      expect(result, isNotNull);
      // 1685955357378 对应的时间是 2023-06-05 10:15:57.378
      expect(result?.year, 2023);
      expect(result?.month, 6);
      expect(result?.day, 5);
      expect(result?.hour, 16);
      expect(result?.minute, 55);
      expect(result?.second, 57);
      expect(result?.millisecond, 378);
      debugPrint(result.toString());
    });

    test('should return null for filename without date', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/photo.jpg');
      expect(result, isNull);
    });

    test('should return null for invalid date format', () {
      final result = TimeAnalyzer.extractFromName('D:/Photos/2023-13-41.jpg');
      expect(result, isNull);
    });
  });
}
