import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

J l(String from, String to, [String kind = 'supply']) =>
    {'from': from, 'to': to, 'kind': kind, 'what': '$from-$to', 'if_from': '$from 탓 $to', 'if_to': '$to 탓 $from', 'source': 's', 'url': 'https://x'};

void main() {
  group('dominoWaves', () {
    final ls = [l('A', 'B'), l('C', 'A', 'compete'), l('B', 'D'), l('C', 'D'), l('D', 'E'), l('A', 'B', 'partner')];

    test('1단계·2단계, 영향 글은 흔들린 쪽에 맞게, 중복·시작 회사 없음', () {
      final w = dominoWaves('A', ls);
      expect(w.length, 2);
      expect([for (final x in w[0]) x.id], ['B', 'C']);
      expect(w[0][0].effect, 'A 탓 B'); // A가 from → if_from
      expect(w[0][1].effect, 'A 탓 C'); // A가 to → if_to
      expect(w[0][1].via, 'A');
      expect([for (final x in w[1]) x.id], ['D']); // D는 B·C 둘 다와 이어졌지만 한 번만
      expect(w[1][0].via, 'B');
      expect(w[1][0].effect, 'B 탓 D');
    });

    test('한 단계 최대 개수, 깊이 1', () {
      final star = [for (var i = 0; i < 12; i++) l('S', 'N$i')];
      expect(dominoWaves('S', star).single.length, 8);
      expect(dominoWaves('S', star, maxPerWave: 3).single.length, 3);
      expect(dominoWaves('A', ls, depth: 1).length, 1);
      expect(dominoWaves('Z', ls), isEmpty);
    });
  });

  group('화면', () {
    setUpAll(() {
      J read(String f) => jsonDecode(File('assets/$f').readAsStringSync());
      data = read('companies.json');
      sp500 = read('sp500.json');
      terms = read('glossary.json')['terms'];
      news = read('news.json');
      links = read('links.json');
      kr = read('kr.json');
      G = {for (final t in terms) t['id'] as String: t};
      companies = mergeCompanies(data['companies'], [...sp500['companies'], ...read('us_more.json')['companies']]);
    });

    testWidgets('흔들어 보기 → 파동이 끝나면 단계별 목록, 행을 누르면 그 회사로 다시 시작', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 6000); // 360dp 폭
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: DominoPage('NVDA')));
      final w = dominoWaves('NVDA', links['links']);
      expect(find.textContaining(kt('1단계')), findsWidgets);
      await tester.tap(find.text('흔들어 보기'));
      await tester.pumpAndSettle();
      expect(find.text('다시 흔들기'), findsOneWidget);
      expect(find.textContaining(kt(w[0][0].effect)), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining(kt('실제로 꼭 이렇게 된다는 뜻은 아니에요')), 300);
      expect(tester.takeException(), isNull);

      final next = w[0][0].id;
      await tester.scrollUntilVisible(find.byKey(ValueKey('row-$next')), -300);
      await tester.tap(find.byKey(ValueKey('row-$next')));
      await tester.pumpAndSettle();
      expect(find.text('흔들어 보기'), findsOneWidget);
      expect(find.textContaining(kt(dominoWaves(next, links['links'])[0][0].effect)), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('애니메이션 줄이기면 누르자마자 최종 상태, 연결 많은 회사 모두 360dp에서 깨지지 않음', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final id in linkedIds().take(10)) {
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(size: Size(360, 2000), disableAnimations: true),
                child: DominoPage(id, key: ValueKey(id)))));
        await tester.tap(find.text('흔들어 보기'));
        await tester.pump();
        expect(find.text('다시 흔들기'), findsOneWidget, reason: id);
        // 1단계 회사는 바로 완전히 밝다 (파동을 기다리지 않음)
        expect(tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity == 1), isNotEmpty, reason: id);
        expect(tester.takeException(), isNull, reason: id);
      }
    });
  });
}
