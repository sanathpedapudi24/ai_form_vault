import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_form_vault/shared/widgets/badges.dart';
import 'package:ai_form_vault/shared/widgets/empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ConfidenceBadge', () {
    testWidgets('shows High for confidence >= 0.85', (tester) async {
      await tester.pumpWidget(_wrap(const ConfidenceBadge(confidence: 0.9)));
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('shows Medium for confidence between 0.6 and 0.85', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ConfidenceBadge(confidence: 0.7)));
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('shows Low for confidence below 0.6', (tester) async {
      await tester.pumpWidget(_wrap(const ConfidenceBadge(confidence: 0.3)));
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('compact mode renders a dot with no label', (tester) async {
      await tester.pumpWidget(
        _wrap(const ConfidenceBadge(confidence: 0.9, compact: true)),
      );
      expect(find.text('High'), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title, message and optional action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'Your vault is empty',
            message: 'Scan a document to get started.',
            actionLabel: 'Scan document',
            onAction: () => tapped = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your vault is empty'), findsOneWidget);
      expect(find.text('Scan a document to get started.'), findsOneWidget);

      await tester.tap(find.text('Scan document'));
      expect(tapped, isTrue);
    });
  });
}
