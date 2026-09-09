import 'package:flutter_test/flutter_test.dart';
import 'package:demo/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(MyApp), findsOneWidget);
  });
}
