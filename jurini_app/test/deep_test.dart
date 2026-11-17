import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

// 가짜 깊이 노트 1개로 기업 상세의 새 구성(핵심 기술·비전·경쟁사·투자 포인트·출처)을 확인한다.
void main() {
  final note = {
    'asof': '2026-11-18',
    'summary': '테스트 회사는 반도체 설계와 소프트웨어로 돈을 벌어요.',
    'tech': [
      {'name': '가속 칩 설계', 'what': '그림 계산을 빨리 하는 칩이에요.', 'why': '인공지능 학습에 꼭 필요해요.', 'edge': '경쟁사보다 소프트웨어 도구가 많아요.'},
      {'name': '개발 도구 묶음', 'what': '프로그래머가 칩을 쓰는 도구예요.', 'why': '한번 익히면 바꾸기 어려워요.', 'edge': '수백만 명이 이미 써요.'},
    ],
    'vision': {
      'goal': '회사는 모든 데이터센터를 인공지능 공장으로 바꾸겠다고 밝혔어요.',
      'milestones': [
        {'when': '2025', 'what': '새 칩 출시', 'status': 'done'},
        {'when': '2027', 'what': '다음 세대 칩', 'status': 'planned'},
      ],
    },
    'rivals': [
      {'name': '가짜경쟁사', 'diff': '가짜경쟁사는 값이 싸지만 도구가 적어요.'},
    ],
    'bull': [
      {'point': '데이터센터 매출이 빠르게 늘어요', 'evidence': '2025 회계연도 공시에서 크게 늘었어요.'},
    ],
    'bear': [
      {'point': '큰 고객 몇 곳에 기대요', 'evidence': '상위 고객 비중이 높다고 공시했어요.'},
    ],
    'watch': ['분기마다 데이터센터 매출이 계속 느는지'],
    'terms': ['per', 'no_such_term'],
    'sources': [
      {'title': '가짜 10-K 공시', 'url': 'https://www.sec.gov/'},
    ],
  };

  setUpAll(() {
    J read(String f) => jsonDecode(File('assets/$f').readAsStringSync());
    data = read('companies.json');
    sp500 = read('sp500.json');
    terms = read('glossary.json')['terms'];
    news = read('news.json');
    kr = read('kr.json');
    surprise = read('surprise.json');
    links = read('links.json');
    calendar = read('calendar.json');
    lessons = read('lessons.json');
    usMore = read('us_more.json');
    G = {for (final t in terms) t['id'] as String: t};
    companies = mergeCompanies(data['companies'], [...sp500['companies'], ...usMore['companies']]);
    deep = {'asof': '2026-11-18', 'companies': {'NVDA': note, 'BAD': {'summary': 3}}};
  });

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 12000);
    addTearDown(t.view.reset);
  }

  J co(String tk) => companies.firstWhere((c) => c['ticker'] == tk);
  Finder ko(String s) => find.textContaining(kt(s));

  test('깨진 노트는 없는 셈 친다', () {
    expect(deepOf(co('NVDA')), isNotNull);
    expect(deepOf({'ticker': 'BAD'}), isNull);
    expect(deepOf(co('AAPL')), isNull);
  });

  testWidgets('깊이 노트가 있으면 상세 화면 가운데에 보인다', (t) async {
    tall(t);
    await t.pumpWidget(MaterialApp(home: DetailPage(co('NVDA'))));
    await t.pumpAndSettle();
    expect(ko('반도체 설계와 소프트웨어'), findsOneWidget);
    expect(ko('핵심 기술'), findsOneWidget);
    expect(ko('경쟁사보다 소프트웨어 도구가 많아요'), findsOneWidget); // 첫 카드는 펼쳐져 있음
    expect(ko('수백만 명이 이미 써요'), findsNothing); // 둘째 카드는 접힘
    await t.tap(ko('개발 도구 묶음'));
    await t.pumpAndSettle();
    expect(ko('수백만 명이 이미 써요'), findsOneWidget);
    expect(ko('인공지능 공장'), findsOneWidget);
    expect(ko('다음 세대 칩'), findsOneWidget);
    expect(ko('가짜경쟁사는 값이 싸지만'), findsOneWidget);
    expect(ko('데이터센터 매출이 빠르게 늘어요'), findsOneWidget);
    expect(ko('큰 고객 몇 곳에 기대요'), findsOneWidget);
    expect(ko('가짜 10-K 공시'), findsOneWidget);
    expect(ko('틀릴 수 있어요'), findsOneWidget);
    expect(find.text('주의할 점'), findsNothing); // 예전 투자 포인트·주의할 점 카드는 숨김
    expect(find.text('최근 뉴스'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('깊이 노트가 없는 회사는 예전 화면 그대로', (t) async {
    tall(t);
    await t.pumpWidget(MaterialApp(home: DetailPage(co('AAPL'))));
    await t.pumpAndSettle();
    expect(find.text('주의할 점'), findsOneWidget);
    expect(ko('핵심 기술'), findsNothing);
  });

  testWidgets('기업 목록에 깊이 노트 표시', (t) async {
    tall(t);
    await t.pumpWidget(const MaterialApp(home: HomePage()));
    await t.pumpAndSettle();
    expect(find.text('깊이 노트'), findsOneWidget);
  });
}
