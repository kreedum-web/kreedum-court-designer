import 'package:flutter_test/flutter_test.dart';
import 'package:kreedum_construction/main.dart';

void main() {
  testWidgets('home screen shows the Kreedum brand', (tester) async {
    await tester.pumpWidget(const KreedumApp());
    await tester.pump();
    expect(find.text('KREEDUM'), findsWidgets);
  });
}
