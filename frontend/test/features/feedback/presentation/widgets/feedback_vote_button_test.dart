import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_vote_button.dart';

void main() {
  Widget buildButton({
    required int voteCount,
    required bool hasVoted,
    required VoidCallback onToggle,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FeedbackVoteButton(
          voteCount: voteCount,
          hasVoted: hasVoted,
          onToggle: onToggle,
        ),
      ),
    );
  }

  group('FeedbackVoteButton', () {
    testWidgets('shows vote count', (tester) async {
      await tester.pumpWidget(buildButton(
        voteCount: 42,
        hasVoted: false,
        onToggle: () {},
      ));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows outline heart when not voted', (tester) async {
      await tester.pumpWidget(buildButton(
        voteCount: 5,
        hasVoted: false,
        onToggle: () {},
      ));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('shows filled heart when voted', (tester) async {
      await tester.pumpWidget(buildButton(
        voteCount: 5,
        hasVoted: true,
        onToggle: () {},
      ));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildButton(
        voteCount: 10,
        hasVoted: false,
        onToggle: () => tapped = true,
      ));

      await tester.tap(find.byType(FeedbackVoteButton));
      expect(tapped, true);
    });
  });
}
