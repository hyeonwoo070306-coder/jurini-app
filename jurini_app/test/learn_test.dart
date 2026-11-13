import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 배우기 진도 계산 (화면 없이)
void main() {
  late J course;
  setUpAll(() => course = jsonDecode(File('assets/lessons.json').readAsStringSync()));
  final allIds = () => [for (final st in course['stages']) for (final l in st['lessons']) l['id'] as String];

  test('진도: 비었거나 깨진 저장값이면 처음부터', () {
    expect(Progress.fromJson(null).done, isEmpty);
    expect(Progress.fromJson('{깨짐').done, isEmpty);
    expect(Progress.fromJson('[1,2]').learned, isEmpty);
  });

  test('다음 수업: 처음엔 s1l1, 하나 끝내면 s1l2, 다 끝내면 없음', () {
    final p = Progress.fromJson(null);
    expect(nextLesson(course, p)!['id'], 's1l1');
    p.done.add('s1l1');
    expect(nextLesson(course, p)!['id'], 's1l2');
    p.done.addAll(allIds());
    expect(nextLesson(course, p), isNull);
  });

  test('이번 주 공부한 날: 같은 날은 하루, 월요일부터 셈', () {
    final wed = DateTime(2026, 11, 18); // 수요일
    final p = Progress.fromJson(null)..days.addAll({'2026-11-15', '2026-11-16', '2026-11-18'}); // 지난 일요일, 월, 수
    expect(weekDays(p, wed), 2);
    final q = Progress.fromJson(null);
    finishLesson(q, course['stages'][0]['lessons'][0], [], wed);
    finishLesson(q, course['stages'][0]['lessons'][1], [], wed);
    expect(weekDays(q, wed), 1);
  });

  test('복습: 틀린 용어가 먼저, 배운 게 없으면 빈 목록', () {
    final g = {for (final id in ['per', 'pbr', 'roe', 'eps']) id: {'id': id, 'term': id, 'definition': 'd', 'category': 'c', 'example': 'e'}};
    expect(reviewTerms(Progress.fromJson(null), g, Random(1)), isEmpty);
    final p = Progress.fromJson(null)
      ..learned.addAll(['per', 'pbr', 'roe', 'eps'])
      ..wrong['roe'] = 1;
    final r = reviewTerms(p, g, Random(1));
    expect(r.length, 3);
    expect(r.first['id'], 'roe');
  });

  test('수업 끝내기: 진도·배운 용어·틀린 용어 갱신, 저장값 왕복', () {
    final p = Progress.fromJson(null)..wrong['stock'] = 2;
    final l = course['stages'][0]['lessons'][0]; // s1l1, terms: [stock]
    finishLesson(p, l, ['market_cap'], DateTime(2026, 11, 18));
    expect(p.done, contains('s1l1'));
    expect(p.learned, contains('stock'));
    expect(p.wrong.containsKey('stock'), isFalse); // 이번엔 맞힘
    expect(p.wrong['market_cap'], 1);
    expect(p.days, contains('2026-11-18'));
    final back = Progress.fromJson(p.toJson());
    expect(back.done, p.done);
    expect(back.wrong, p.wrong);
    expect(back.days, p.days);
  });

  group('배우기 화면', () {
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
      usMore = read('us_more.json');
      lessons = course;
      G = {for (final t in terms) t['id'] as String: t};
      companies = mergeCompanies(data['companies'], [...sp500['companies'], ...usMore['companies']]);
    });
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      calendar = {'asof': 'x', 'note': 'n', 'events': []};
      news = {...news}..remove('market');
    });
    String today() => DateTime.now().toIso8601String().substring(0, 10);
    void tall(WidgetTester t) {
      t.view.physicalSize = const Size(1080, 8000);
      addTearDown(t.view.reset);
    }

    testWidgets('첫 화면은 배우기 탭, 퀴즈 탭은 없음', (t) async {
      tall(t);
      await t.pumpWidget(const MaterialApp(home: Shell()));
      await t.pumpAndSettle();
      expect(find.text('오늘의 10분'), findsOneWidget);
      final labels = t.widget<NavigationBar>(find.byType(NavigationBar)).destinations.map((d) => (d as NavigationDestination).label).toList();
      expect(labels, ['배우기', '기업', '연결', '용어사전', '뉴스']);
    });

    testWidgets('오늘의 시장 한눈에: 일정·시장 뉴스가 있으면 보이고, 없으면 칸이 사라짐', (t) async {
      tall(t);
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      expect(find.text('오늘의 시장 한눈에'), findsNothing);
      calendar = {'asof': 'x', 'note': 'n', 'events': [{'date': today(), 'kst': '${today()} 22:30', 'type': 'macro', 'kind': 'us_cpi', 'title': '미국 소비자물가지수(CPI)'}]};
      news = {...news, 'market': [{'date': today(), 'type': 'watch', 'title': '물가 발표를 앞두고 시장이 조심스러워요', 'impact': 'i', 'source': 's', 'url': 'https://x.com', 'terms': ['cpi'], 'learn': 'CPI는 생활 물가예요.'}]};
      await t.pumpWidget(const MaterialApp(home: LearnPage(key: ValueKey(2))));
      await t.pumpAndSettle();
      expect(find.text('오늘의 시장 한눈에'), findsOneWidget);
      expect(find.textContaining(kt('미국 소비자물가지수(CPI)')), findsOneWidget);
      expect(find.textContaining(kt('물가 발표를 앞두고 시장이 조심스러워요')), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('오늘의 수업: 카드 → 퀴즈 3문제 → 끝내면 다음 수업으로', (t) async {
      tall(t);
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('주식은 회사의 조각')), findsWidgets);
      await t.tap(find.byKey(const ValueKey('today-lesson')));
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('다음'));
        await t.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const ValueKey('option-0')));
        await t.pumpAndSettle();
        await t.tap(find.text(i < 2 ? '다음 문제' : '결과 보기'));
        await t.pumpAndSettle();
      }
      await t.tap(find.text('수업 끝내기'));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('주가는 왜 매일 바뀔까')), findsWidgets);
      expect(Progress.fromJson((await SharedPreferences.getInstance()).getString('progress_v1')).done, contains('s1l1'));
    });

    testWidgets('코스를 다 끝냈고 AI 수업도 없으면 복습 안내', (t) async {
      tall(t);
      final p = Progress.fromJson(null)..done.addAll(allIds());
      SharedPreferences.setMockInitialValues({'progress_v1': p.toJson()});
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('오늘은 복습만 해요')), findsOneWidget);
    });

    testWidgets('자유 퀴즈 버튼은 기존 퀴즈 화면으로', (t) async {
      tall(t);
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      await t.tap(find.text('자유 퀴즈'));
      await t.pumpAndSettle();
      expect(find.text('시작하기'), findsOneWidget);
    });
  });
}
