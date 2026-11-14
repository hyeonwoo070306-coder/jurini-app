import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 내일을 추리해 보기 (경제 일정 추리 퀴즈)
void main() {
  J read(String f) => jsonDecode(File('assets/$f').readAsStringSync());
  setUpAll(() {
    terms = read('glossary.json')['terms'];
    G = {for (final t in terms) t['id'] as String: t};
    predictData = read('predict.json');
    lessons = read('lessons.json');
    news = {'companies': {}};
    data = read('companies.json');
    companies = data['companies'];
    kr = {'companies': []};
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetGuessCache();
  });

  test('predict.json: 모든 경제 일정 종류가 형식에 맞다', () {
    expect(validPredict(predictData), isTrue);
    expect((predictData['kinds'] as Map).keys, containsAll(['us_cpi', 'us_pce', 'us_jobs', 'fomc', 'us_gdp', 'bok_rate', 'kr_cpi']));
    final broken = jsonDecode(jsonEncode(predictData));
    broken['kinds']['us_cpi']['quiz']['answer'] = 1; // 정답이 사슬의 빈칸과 다름
    expect(validPredict(broken), isFalse);
    final long = jsonDecode(jsonEncode(predictData));
    long['kinds']['fomc']['chains']['cut'][0]['t'] = '가' * 41;
    expect(validPredict(long), isFalse);
    final badTerm = jsonDecode(jsonEncode(predictData));
    badTerm['kinds']['fomc']['chains']['cut'][0]['term'] = 'no_such_term';
    expect(validPredict(badTerm), isFalse);
    expect(validPredict({}), isFalse);
  });

  test('upcomingPredict: 앞으로 며칠 안의 경제 일정만, 이미 지난 시각은 뺀다', () {
    final now = DateTime.utc(2026, 11, 14, 10, 0); // 한국 시간 11월 14일 10:00
    final events = [
      {'date': '2026-11-14', 'kst': '2026-11-14 08:00', 'type': 'macro', 'kind': 'us_cpi', 'title': '이미 발표됨'},
      {'date': '2026-11-14', 'kst': '2026-11-14 22:30', 'type': 'macro', 'kind': 'us_cpi', 'title': '오늘 밤'},
      {'date': '2026-11-15', 'kst': null, 'type': 'macro', 'kind': 'bok_rate', 'title': '내일'},
      {'date': '2026-11-16', 'kst': null, 'type': 'earnings', 'kind': 'earnings', 'title': '실적'},
      {'date': '2026-11-21', 'kst': null, 'type': 'macro', 'kind': 'fomc', 'title': '7일 뒤'},
      {'date': '2026-11-22', 'kst': null, 'type': 'macro', 'kind': 'fomc', 'title': '8일 뒤'},
      {'date': '2026-11-16', 'kst': null, 'type': 'macro', 'kind': 'other', 'title': '추리 자료 없음'},
    ];
    expect([for (final e in upcomingPredict(events, now)) e['title']], ['오늘 밤', '내일', '7일 뒤']);
    expect([for (final e in upcomingPredict(events, now, days: 1)) e['title']], ['오늘 밤', '내일']);
  });

  test('predictVerdict: 둘 다 있을 때만 맞음/틀림', () {
    expect(predictVerdict('above', 'above'), isTrue);
    expect(predictVerdict('above', 'below'), isFalse);
    expect(predictVerdict(null, 'below'), isNull);
    expect(predictVerdict('cut', null), isNull);
  });

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 9000);
    addTearDown(t.view.reset);
  }

  testWidgets('추리 화면: 흐름 → 빈칸 퀴즈 → 내 추리 저장', (t) async {
    tall(t);
    final e = {'date': '2026-11-20', 'kst': '2026-11-20 22:30', 'type': 'macro', 'kind': 'us_cpi', 'title': '미국 소비자물가지수(CPI)', 'id': '2026-11-20:us_cpi'};
    await t.pumpWidget(MaterialApp(home: PredictPage(e)));
    await t.pumpAndSettle();
    expect(find.textContaining(kt('연준이 금리를 늦게 내릴까 걱정해요')), findsOneWidget);
    await t.tap(find.textContaining(kt('금리를 더 올려야 한다고 볼 수 있어요'))); // 오답
    await t.pumpAndSettle();
    expect(find.textContaining(kt('물가가 덜 오르면')), findsOneWidget);
    await t.tap(find.textContaining(kt('예상보다 높게')).last);
    await t.pumpAndSettle();
    expect((await loadGuesses())['2026-11-20:us_cpi'], 'above');
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('predict_v1')!), {'2026-11-20:us_cpi': 'above'});
    expect(t.takeException(), isNull);
  });

  testWidgets('결과가 나오면: 틀린 추리엔 실제 결과의 흐름을 보여준다', (t) async {
    tall(t);
    SharedPreferences.setMockInitialValues({'predict_v1': jsonEncode({'2026-11-10:fomc': 'hike'})});
    final e = {
      'date': '2026-11-10', 'kst': '2026-11-10 04:00', 'type': 'macro', 'kind': 'fomc', 'title': '미국 금리 결정(FOMC)', 'id': '2026-11-10:fomc',
      'result': {'summary': '기준금리를 0.25%p 내렸어요', 'impact': '대출 이자가 줄 수 있어요.', 'source': '연준', 'url': 'https://x.gov', 'vs': 'cut'},
    };
    await t.pumpWidget(MaterialApp(home: PredictPage(e)));
    await t.pumpAndSettle();
    expect(find.text('내 추리 vs 실제'), findsOneWidget);
    expect(find.textContaining(kt('결과가 이렇게 나왔으니')), findsOneWidget);
    expect(find.textContaining(kt('회사들이 돈을 빌리기 쉬워질 수 있어요')), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('배우기 탭: 오늘·내일 경제 일정이 있으면 추리 카드가 보인다', (t) async {
    tall(t);
    final k = DateTime.now().toUtc().add(const Duration(hours: 9));
    final tomorrow = dayKey(k.add(const Duration(days: 1)));
    calendar = {'asof': 'x', 'note': 'n', 'events': [{'date': tomorrow, 'kst': null, 'type': 'macro', 'kind': 'fomc', 'title': '미국 금리 결정(FOMC)'}]};
    resetProgressCache();
    await t.pumpWidget(const MaterialApp(home: LearnPage()));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('predict-card')), findsOneWidget);
    calendar = {'asof': 'x', 'note': 'n', 'events': []};
    await t.pumpWidget(const MaterialApp(home: LearnPage(key: ValueKey(2))));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('predict-card')), findsNothing);
  });

  testWidgets('일정 화면: 7일 안 경제 일정엔 추리해 보기, 결과 나온 내 추리엔 내 추리 확인', (t) async {
    tall(t);
    final k = DateTime.now().toUtc().add(const Duration(hours: 9));
    String day(int n) => dayKey(k.add(Duration(days: n)));
    SharedPreferences.setMockInitialValues({'predict_v1': jsonEncode({'${day(-2)}:us_cpi': 'above'})});
    calendar = {'asof': day(0), 'note': 'n', 'events': [
      {'date': day(2), 'kst': null, 'type': 'macro', 'kind': 'fomc', 'title': '미국 금리 결정(FOMC)', 'id': '${day(2)}:fomc'},
      {'date': day(20), 'kst': null, 'type': 'macro', 'kind': 'us_gdp', 'title': '먼 일정', 'id': '${day(20)}:us_gdp'},
      {'date': day(-2), 'kst': null, 'type': 'macro', 'kind': 'us_cpi', 'title': '지난 물가', 'id': '${day(-2)}:us_cpi',
       'result': {'summary': '예상보다 낮았어요', 'impact': '금리 인하 기대가 커질 수 있어요.', 'source': 'BLS', 'url': 'https://x.gov', 'vs': 'below'}},
    ]};
    await t.pumpWidget(const MaterialApp(home: NewsPage()));
    await t.tap(find.text('일정'));
    await t.pumpAndSettle();
    expect(find.text('추리해 보기'), findsOneWidget);
    expect(find.text('내 추리 확인'), findsOneWidget);
    await t.tap(find.text('내 추리 확인'));
    await t.pumpAndSettle();
    expect(find.textContaining(kt('결과가 이렇게 나왔으니')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
