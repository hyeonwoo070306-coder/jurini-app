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
      resetProgressCache();
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
      resetProgressCache();
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

  group('AI 수업', () {
    J ai([J extra = const {}]) => {
          'id': 'ai-2026-11-14', 'title': '오늘 물가 뉴스 읽기', 'terms': ['cpi'], 'stage': 4, 'date': '2026-11-14',
          'verified': true, 'sources': ['https://www.bls.gov/cpi/'],
          'cards': ['카드1', '카드2', '카드3', '카드4'],
          'quiz': [for (var i = 0; i < 3; i++) {'q': 'q', 'options': ['a', 'b', 'c', 'd'], 'answer': 0, 'explain': 'e'}],
          ...extra,
        };
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      resetProgressCache();
      aiToday = null;
      aiArchive = [];
      lessons = course;
    });

    test('AI 수업 검증: 확인 안 됐거나 형식이 틀리면 거절', () {
      expect(validAiLesson(ai()), isTrue);
      expect(validAiLesson(ai({'verified': false})), isFalse);
      expect(validAiLesson(ai({'sources': []})), isFalse);
      expect(validAiLesson(ai({'stage': 9})), isFalse);
      expect(validAiLesson(ai({'cards': ['하나']})), isFalse);
    });

    test('AI 용어 합치기: 새 용어는 추가, 있는 용어는 덮어쓰지 않음', () {
      final before = G['per'];
      mergeAiGlossary({'terms': [
        {'id': 'per', 'term': '가짜', 'definition': 'd', 'example': 'e', 'category': '주가 수준', 'why': 'w'},
        {'id': 'new_term_x', 'term': '새 용어', 'definition': 'd', 'example': 'e', 'category': '주식 기본', 'why': 'w'},
      ]});
      expect(G['per'], same(before));
      expect(G['new_term_x']['ai'], isTrue);
      expect(terms.where((t) => t['id'] == 'new_term_x').length, 1);
      mergeAiGlossary({'terms': [{'id': 'new_term_x', 'term': '새 용어', 'definition': 'd', 'example': 'e', 'category': '주식 기본', 'why': 'w'}]});
      expect(terms.where((t) => t['id'] == 'new_term_x').length, 1); // 두 번 받아도 한 번만
    });

    testWidgets('AI 용어 팝업에 표시가 붙는다', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      addTearDown(t.view.reset);
      mergeAiGlossary({'terms': [{'id': 'new_term_y', 'term': '새 용어 와이', 'definition': '뜻이에요', 'example': '예시', 'category': '주식 기본', 'why': '이유'}]});
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(onPressed: () => openTerm(c, 'new_term_y'), child: const Text('열기')))));
      await t.tap(find.text('열기'));
      await t.pumpAndSettle();
      expect(find.text('AI가 추가한 용어'), findsOneWidget);
    });

    testWidgets('보너스 수업: 아직 안 배운 단계면 안내, 코스를 끝냈으면 오늘의 수업 자리로', (t) async {
      t.view.physicalSize = const Size(1080, 8000);
      addTearDown(t.view.reset);
      aiToday = ai();
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('오늘 물가 뉴스 읽기')), findsWidgets);
      expect(find.textContaining(kt('4단계 내용이에요')), findsOneWidget);
      final p = Progress.fromJson(null)..done.addAll(allIds());
      SharedPreferences.setMockInitialValues({'progress_v1': p.toJson()});
      resetProgressCache();
      await t.pumpWidget(const MaterialApp(home: LearnPage(key: ValueKey('done'))));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('오늘은 복습만 해요')), findsNothing);
      await t.tap(find.byKey(const ValueKey('today-lesson')));
      await t.pumpAndSettle();
      expect(find.textContaining(kt('AI가 오늘 뉴스로 만든 수업이에요')), findsOneWidget);
    });
  });

  group('뉴스 → 배우기', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      resetProgressCache();
      lessons = course;
    });

    test('용어로 수업 찾기', () {
      expect(lessonForTerm('per')!['id'], 's3l1');
      expect(lessonForTerm('없는용어'), isNull);
    });

    testWidgets('관련 용어가 있는 뉴스엔 칩, 누르면 수업으로 배우기; 예전 뉴스엔 칩 없음', (t) async {
      t.view.physicalSize = const Size(1080, 8000);
      addTearDown(t.view.reset);
      final old = news;
      addTearDown(() => news = old);
      J item(Map<String, dynamic> extra) =>
          {'date': '2026-11-14', 'type': 'good', 'title': '엔비디아 실적이 예상보다 좋았어요', 'impact': '영향', 'source': 's', 'url': 'https://x.com', ...extra};
      news = {'asof': '2026-11-14', 'companies': {'NVDA': [item({'terms': ['per'], 'learn': 'PER은 주가가 이익의 몇 배인지예요.'})]}};
      await t.pumpWidget(const MaterialApp(home: NewsPage()));
      expect(find.text('이 뉴스 이해하기'), findsOneWidget);
      await t.tap(find.widgetWithText(ActionChip, termName(G['per'])));
      await t.pumpAndSettle();
      expect(find.text('수업으로 배우기'), findsOneWidget);
      news = {'asof': '2026-11-14', 'companies': {'NVDA': [item({})]}};
      await t.pumpWidget(const MaterialApp(home: NewsPage(key: ValueKey('old'))));
      await t.pumpAndSettle();
      expect(find.text('이 뉴스 이해하기'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('최종 검토 수정', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      resetProgressCache();
      lessons = course;
      aiToday = null;
    });

    testWidgets('다른 경로(수업으로 배우기)에서 끝낸 진도가 배우기 탭 저장에 덮어써지지 않음', (t) async {
      t.view.physicalSize = const Size(1080, 8000);
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: LearnPage()));
      await t.pumpAndSettle();
      // 용어 팝업 → 수업으로 배우기 경로와 같은 방식으로 진도 갱신
      final other = await loadProgress();
      finishLesson(other, courseLessons(course)[5], [], DateTime.now()); // s2l1
      await saveProgress(other);
      // 배우기 탭에서 수업 하나 끝내기
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
      final saved = Progress.fromJson((await SharedPreferences.getInstance()).getString('progress_v1'));
      expect(saved.done, containsAll(['s1l1', 's2l1']));
    });

    testWidgets('퀴즈 보기는 섞여 나오고, 정답은 위치가 아니라 내용으로 판정', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      addTearDown(t.view.reset);
      final l = courseLessons(course)[6]; // s2l2: 정답이 대부분 두 번째 보기
      await t.pumpWidget(MaterialApp(home: LessonPage(l, rnd: Random(3))));
      for (var i = 0; i < (l['cards'] as List).length; i++) {
        await t.tap(find.text('다음'));
        await t.pumpAndSettle();
      }
      var moved = false;
      for (var qi = 0; qi < 3; qi++) {
        final q = l['quiz'][qi];
        final correct = q['options'][q['answer']] as String;
        final shown = [for (var k = 0; k < 4; k++) (t.widget<Text>(find.descendant(of: find.byKey(ValueKey('option-$k')), matching: find.byType(Text))).data ?? '').replaceAll('⁠', '')];
        if (shown.indexOf(correct) != q['answer']) moved = true;
        await t.tap(find.byKey(ValueKey('option-${shown.indexOf(correct)}')));
        await t.pumpAndSettle();
        expect(find.textContaining(kt('맞았어요')), findsOneWidget);
        await t.tap(find.text(qi < 2 ? '다음 문제' : '결과 보기'));
        await t.pumpAndSettle();
      }
      expect(moved, isTrue);
      expect(find.textContaining(kt('3개 맞혔어요')), findsOneWidget);
    });

    testWidgets('복습 퀴즈 결과 화면엔 분야 바꾸기가 없음', (t) async {
      t.view.physicalSize = const Size(1080, 8000);
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: QuizPage(only: {'per', 'pbr', 'roe'})));
      for (var k = 0; k < 3; k++) {
        await t.tap(find.byType(InkWell).first);
        await t.pump();
        await t.tap(find.text(k < 2 ? '다음 문제' : '결과 보기'));
        await t.pump();
      }
      expect(find.textContaining('3문제 중'), findsOneWidget);
      expect(find.text('분야 바꾸기'), findsNothing);
    });
  });
}
