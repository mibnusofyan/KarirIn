import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/catalog_extra.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/widgets/career_widgets.dart';

void main() {
  test('setiap perusahaan di katalog dan lamaran contoh punya logo yang berkasnya ada', () {
    final companies = {for (final j in [...jobs, ...extraJobs]) j.company, for (final a in initialApplications) a.company};
    for (final c in companies) {
      final slug = companyLogos[c];
      expect(slug, isNotNull, reason: c);
      expect(File('assets/images/logos/$slug.svg').existsSync(), isTrue, reason: '$c → $slug.svg');
    }
  });

  testWidgets('logo dipakai bila ada, inisial untuk perusahaan lain', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(children: [CompanyAvatar(company: 'PT Banyumas Net Media'), CompanyAvatar(company: 'PT Contoh Baru')]),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('CB'), findsOneWidget);
  });
}
