import 'package:accent/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the empty state when no servers are configured', (
    tester,
  ) async {
    await tester.pumpWidget(const AccentApp());

    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('the add button says so rather than opening a half-built form', (
    tester,
  ) async {
    await tester.pumpWidget(const AccentApp());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Adding a server is not ready yet'), findsOneWidget);
  });
}
