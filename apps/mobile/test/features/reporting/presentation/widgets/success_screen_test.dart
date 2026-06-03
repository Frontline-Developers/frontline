import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/presentation/widgets/success_screen.dart';

Widget _harness({
  String token = 'abcd-1234-efgh-5678',
  VoidCallback? onDone,
  VoidCallback? onNewReport,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SuccessScreen(
        token: token,
        onDone: onDone ?? () {},
        onNewReport: onNewReport ?? () {},
      ),
    ),
  ),
);

void main() {
  group('SuccessScreen', () {
    testWidgets('renders token and success heading', (tester) async {
      await tester.pumpWidget(_harness(token: 'abcd-1234-efgh-5678'));
      expect(find.text('Report submitted'), findsOneWidget);
      expect(find.text('abcd-1234-efgh-5678'), findsOneWidget);
    });

    testWidgets('renders without crash when token is empty', (tester) async {
      await tester.pumpWidget(_harness(token: ''));
      expect(find.text('Report submitted'), findsOneWidget);
    });

    testWidgets('Copy token button changes label to Copied after tap', (
      tester,
    ) async {
      // Clipboard.setData uses a platform channel; mock it so the test doesn't throw.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') return null;
          return null;
        },
      );
      await tester.pumpWidget(_harness(token: 'abcd-1234-efgh-5678'));
      expect(find.text('Copy token'), findsOneWidget);
      await tester.tap(find.text('Copy token'));
      await tester.pump(); // let setState(_copied = true) run
      expect(find.text('Copied'), findsOneWidget);
      // Drain the 1500ms reset timer so the test doesn't leak a pending timer.
      await tester.pump(const Duration(milliseconds: 1600));
    });
  });
}
