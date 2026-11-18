import 'package:cane_nav/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen offers the three roles', (tester) async {
    await tester.pumpWidget(const CaneNavApp());
    expect(find.text('研究人員 Wizard'), findsOneWidget);
    expect(find.text('受試者 Participant'), findsOneWidget);
    expect(find.text('紀錄檔 Logs'), findsOneWidget);
  });
}
