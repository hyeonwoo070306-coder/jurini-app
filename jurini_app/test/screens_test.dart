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
    surprise = read('surprise.json');
    links = read('links.json');
    calendar = read('calendar.json');
    kr = read('kr.json');
    G = {for (final t in terms) t['id'] as String: t};
    final usMore = read('us_more.json');
    companies = mergeCompanies(data['companies'], [...sp500['companies'], ...usMore['companies']]);
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
    for (final c in [...companies.where((c) => !isFull(c)).take(60), ...companies.where((c) => ['ASML', 'MELI', 'CRWV'].contains(c['ticker']))]) {
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
      for (final m in metrics.values) {
        if (find.text(m.$1).evaluate().isEmpty) break; // 재무가 없는 회사
        await tester.tap(find.text(m.$1).first);
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: c['name_ko']);
    }
  });

  testWidgets('뉴스 탭: AI 요약 카드를 보여주고, 호재·악재 필터와 미국/한국 버튼이 줄여 준다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NewsPage()));
    int rows() => (find.byType(ListView).evaluate().single.widget as ListView).childrenDelegate.estimatedChildCount!;
    final total = [for (final l in (news['companies'] as Map).values) ...l].length;
    expect(find.text('${news['asof']} 정리'), findsOneWidget);
    expect(find.textContaining('회사에 주는 영향'), findsWidgets);
    expect(rows(), greaterThan(total)); // 모든 회사 뉴스가 한 목록에
    final before = rows();
    await tester.tap(find.widgetWithText(ChoiceChip, '악재'));
    await tester.pump();
    expect(rows(), lessThan(before));
    final bad = rows();
    await tester.tap(find.text('한국'));
    await tester.pump();
    expect(rows(), lessThan(bad));
    expect(find.text('찾는 뉴스가 없어요.'), findsNothing); // 한국 회사 악재도 있음
    expect(tester.takeException(), isNull);
  });

  testWidgets('퀴즈: 시작 → 보기 선택 → 다음 → 결과까지', (tester) async {
    tester.view.physicalSize = const Size(1080, 8000); // 한 화면에 문제 전체가 보이게
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: QuizPage()));
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    for (var k = 0; k < 10; k++) {
      expect(find.text('${k + 1} / 10'), findsOneWidget);
      await tester.tap(find.byType(InkWell).first); // 첫 번째 보기 고르기
      await tester.pump();
      final next = find.text(k < 9 ? '다음 문제' : '결과 보기');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
    }
    expect(find.textContaining('10문제 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연결: 회사 고르기 → 둘레 회사 누르기 → 다른 회사로 바꾸기', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LinksPage()));
    final ids = linkedIds();
    expect(find.textContaining('이어진 회사 ${linksOf(ids.first).length}곳'), findsOneWidget);
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    for (final id in ids.skip(1).take(6)) {
      await tester.enterText(find.byType(TextField), nodeName(id));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, nodeName(id)).first);
      await tester.pump();
      expect(find.textContaining('이어진 회사 ${linksOf(id).length}곳'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  test('연결 데이터: 모든 회사 id를 찾을 수 있고, 각 연결에 출처 주소가 있다', () {
    for (final J l in links['links']) {
      for (final id in [l['from'], l['to']]) {
        expect(appCompany(id) != null || links['nodes'][id] != null, true, reason: id);
      }
      expect((l['url'] as String).startsWith('https://'), true);
    }
  });

  testWidgets('일정: 뉴스 탭에서 일정으로 바꾸고 종류를 고를 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.reset);
    final today = DateTime.now();
    String day(int n) => today.add(Duration(days: n)).toIso8601String().substring(0, 10);
    calendar = {
      'asof': day(0),
      'note': '테스트',
      'events': [
        {'date': day(1), 'kst': '${day(1)} 04:00', 'type': 'macro', 'kind': 'fomc', 'title': '미국 금리 결정(FOMC)'},
        {'date': day(3), 'kst': null, 'type': 'earnings', 'kind': 'earnings', 'ticker': 'NVDA', 'when': 'after', 'title': '엔비디아 실적 발표'},
        {'date': day(-2), 'kst': null, 'type': 'macro', 'kind': 'us_cpi', 'title': '지난 일정'},
        {'date': day(-1), 'kst': null, 'type': 'macro', 'kind': 'kr_cpi', 'title': '한국 물가 발표',
         'result': {'summary': '물가 2.1% 상승', 'impact': '예상과 비슷했어요.', 'source': '국가데이터처', 'url': 'https://x.kr'}},
        {'date': day(0), 'kst': '${day(0)} 22:30', 'type': 'macro', 'kind': 'us_cpi', 'title': '오늘 미국 물가'},
      ],
    };
    await tester.pumpWidget(const MaterialApp(home: NewsPage()));
    await tester.tap(find.text('일정'));
    await tester.pump();
    expect(find.textContaining(kt('엔비디아 실적 발표')), findsOneWidget);
    expect(find.text('내일'), findsOneWidget);
    expect(find.textContaining(kt('지난 일정')), findsNothing); // 결과 없는 지난 일정은 숨김
    expect(find.text('오늘의 주요 일정'), findsOneWidget);
    expect(find.textContaining(kt('오늘 미국 물가')), findsOneWidget);
    expect(find.textContaining(kt('물가 2.1% 상승')), findsOneWidget); // 지난 일정 결과 요약
    await tester.tap(find.text('경제 지표'));
    await tester.pump();
    expect(find.textContaining(kt('엔비디아 실적 발표')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연결: 검색하면 회사가 좁혀지고 업종 묶음을 펼쳐 고른다', (tester) async {
    tester.view.physicalSize = const Size(1080, 8000);
    addTearDown(tester.view.reset);
    expect(linkedBySector().values.expand((x) => x).toSet(), linkedIds().toSet());
    await tester.pumpWidget(const MaterialApp(home: LinksPage()));
    await tester.enterText(find.byType(TextField), '엔비');
    await tester.pump();
    expect(find.widgetWithText(ChoiceChip, '엔비디아'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '애플'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    final tile = find.byType(ExpansionTile).first;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final chip = find.descendant(of: tile, matching: find.byType(ChoiceChip)).first;
    final name = ((tester.widget<ChoiceChip>(chip).label) as Text).data!;
    await tester.tap(chip);
    await tester.pump();
    expect(find.textContaining('$name와 이어진 회사'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
