import 'package:flutter_test/flutter_test.dart';

import 'package:gouwu/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GouWuApp());
    expect(find.text('购物'), findsOneWidget);
  });
}