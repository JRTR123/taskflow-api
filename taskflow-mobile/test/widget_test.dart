import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_mobile/main.dart';

void main() {
  testWidgets('renders Taskflow title', (tester) async {
    await tester.pumpWidget(const TaskflowApp());
    expect(find.text('Taskflow'), findsOneWidget);
  });
}
