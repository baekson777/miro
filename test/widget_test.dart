import 'package:blind_weekly_maze/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows brand title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindWeeklyMazeApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('미로미로해'), findsOneWidget);
  });
}
