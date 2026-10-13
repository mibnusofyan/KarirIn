import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/widgets/career_widgets.dart';

Future<void> _pump(WidgetTester tester, String company) =>
    tester.pumpWidget(MaterialApp(home: Center(child: CompanyAvatar(company: company))));

void main() {
  testWidgets('perusahaan nyata memakai logo resmi', (tester) async {
    await _pump(tester, 'Bank BCA');
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/logos/bca.png');
    expect(find.text('BB'), findsNothing);
  });

  testWidgets('perusahaan tanpa logo tetap memakai inisial', (tester) async {
    await _pump(tester, 'PT Sinar Mandiri Abadi');
    expect(find.byType(Image), findsNothing);
    expect(find.text('SM'), findsOneWidget);
  });
}
