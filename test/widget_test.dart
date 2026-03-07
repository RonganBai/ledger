import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/data/db/app_database.dart';
import 'package:ledger_app/app/app.dart';

void main() {
  testWidgets('app builds', (tester) async {
    final db = AppDatabase();
    addTearDown(() => db.close());

    await tester.pumpWidget(MyApp(db: db));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ledger'), findsWidgets);
  });
}