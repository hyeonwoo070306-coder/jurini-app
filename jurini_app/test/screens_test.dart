import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

// 실제 데이터로 모든 상세 화면·탭을 열어 빈 숫자(null) 때문에 깨지는 곳이 없는지 확인한다.
void main() {
  setUpAll(() {
    J read(String f) => jsonDecode(File('assets/$f').readAsStringSync());
    data = read('companies.json');
    sp500 = read('sp500.json');
    terms = read('glossary.json')['terms'];
    news = read('news.json');
    kr = read('kr.json');
    G = {for (final t in terms) t['id'] as String: t};
    companies = mergeCompanies(data['companies'], sp500['companies']);
  });

  testWidgets('자세한 기업 50곳: 모든 탭과 실적 지표가 열린다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final full = companies.where((c) => isFull(c)).toList();
    expect(full.length, 50);
    expect(full.where((c) => news['companies'][c['ticker']] == null), isEmpty); // 50곳 모두 뉴스가 있어야 함
    for (final c in full) {
      await tester.pumpWidget(MaterialApp(home: DetailPage(c, key: ValueKey(c['id']))));
      expect(find.text('최근 뉴스'), findsOneWidget, reason: c['ticker']);
      for (final t in tabs.values) {
        await tester.ensureVisible(find.text(t));
        await tester.tap(find.text(t));
        await tester.pump();
        if (t == '실적') {
          for (final m in metrics.values) {
            await tester.tap(find.text(m.$1).first);
            await tester.pump();
          }
        }
      }
      expect(tester.takeException(), isNull, reason: c['ticker']);
    }
  });

  testWidgets('기본 카드 기업도 열린다', (tester) async {
    for (final c in companies.where((c) => !isFull(c)).take(60)) {
      await tester.pumpWidget(MaterialApp(home: DetailPage(c, key: ValueKey(c['id']))));
      expect(tester.takeException(), isNull, reason: c['ticker']);
    }
  });

  testWidgets('용어사전: 분야 칩과 시장 영향 팝업', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsPage()));
    await tester.enterText(find.byType(TextField), 'cpi');
    await tester.pump();
    await tester.ensureVisible(find.text('금리·물가·경기 (시장 흐름)').first);
    await tester.pump();
    await tester.tap(find.text('금리·물가·경기 (시장 흐름)').first);
    await tester.pump();
    expect(find.text('PER(주가수익비율)'), findsNothing);
    await tester.tap(find.text('소비자물가지수(CPI)'));
    await tester.pumpAndSettle();
    expect(find.text('시장에 주는 영향'), findsOneWidget);
  });

  testWidgets('한국 회사 기본 카드도 열린다', (tester) async {
    final List ks = kr['companies'];
    expect(ks.length, greaterThan(2000));
    for (final c in [...ks.take(30), ...ks.where((c) => c['name_ko'] == '삼성전자')]) {
      await tester.pumpWidget(MaterialApp(home: DetailPage(c, key: ValueKey(c['id']))));
      expect(tester.takeException(), isNull, reason: c['name_ko']);
    }
  });
}
