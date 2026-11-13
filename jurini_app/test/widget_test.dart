import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

void main() {
  test('숫자 포맷', () {
    expect(comma(1234567), '1,234,567');
    expect(eok(478834), '4,788억 달러'); // 백만 달러 → 억 달러
    expect(krw(5094), '5.09조 달러');
    expect(krw(850), '8,500억 달러'); // 십억 달러 → 억 달러
    expect(wonEok(3336059.4), '333.6조 원'); // 억 원 → 조 원
    expect(wonEok(1234.5), '1,235억 원');
    expect(wonEok(-500), '-500억 원');
    expect(won(478834), '약 670조 원');
    expect(won(50), '약 700억 원');
    expect(nf(21.0), '21');
    expect(opt(null, '배'), '-');
  });

  test('한글 단어 안에서는 줄바꿈 금지 문자가 들어간다', () {
    expect(kt('애플 AAPL'), '애⁠플 AAPL');
  });

  test('자세한 회사가 먼저, 겹치는 S&P 회사는 빼고 가나다순', () {
    final out = mergeCompanies([
      {'ticker': 'AAPL', 'name_ko': '애플', 'business': 'x'},
    ], [
      {'ticker': 'KO', 'name_ko': '코카콜라', 'sector': '필수소비재'},
      {'ticker': 'AAPL', 'name_ko': '애플', 'sector': '정보기술'},
      {'ticker': 'NVDA', 'name_ko': '엔비디아', 'sector': '정보기술'},
    ]);
    expect(out.map((c) => c['ticker']), ['AAPL', 'NVDA', 'KO']);
    expect(out.first['group'], '정보기술');
    expect(eok(null), '-');
  });

  test('applyLive: 종가 지표를 덮어쓰고 순위대로 다시 정렬', () {
    companies = [
      {'ticker': 'A', 'business': 'x', 'rank': 1, 'market_cap_usd_b': 100, 'valuation': {'per': 10.0, 'comment': 'c'}, 'shareholder_return': {'dividend_yield': 1.0}},
      {'ticker': 'B', 'business': 'x', 'rank': 2, 'market_cap_usd_b': 90, 'valuation': {'per': 20.0}, 'shareholder_return': {}},
      {'ticker': 'C', 'name_ko': '다'},
    ];
    applyLive({
      'asof': '2026-11-11',
      'companies': {
        'A': {'market_cap_usd_b': 80, 'per': 8.0, 'forward_per': null, 'pbr': 2.0, 'dividend_yield': 1.25, 'rank': 2},
        'B': {'market_cap_usd_b': 95, 'per': 21.1, 'forward_per': null, 'pbr': 3.0, 'dividend_yield': null, 'rank': 1},
      }
    });
    expect(companies.map((c) => c['ticker']), ['B', 'A', 'C']);
    final a = companies[1];
    expect(a['valuation']['per'], 8.0);
    expect(a['valuation'], isA<J>()); // 화면 코드가 J 타입으로 읽으므로 타입이 바뀌면 안 됨
    expect(a['shareholder_return'], isA<J>());
    expect(a['valuation']['comment'], 'c');
    expect(a['valuation']['asof'], '2026-11-11');
    expect(a['shareholder_return']['dividend_yield'], 1.25);
    expect(live.value, '2026-11-11');
  });

  test('인터넷에서 받은 파일이 이상하면 거른다', () {
    final n = validNews({
      'asof': '2026-11-12',
      'companies': {
        'A': [
          {'type': 'good', 'title': 't', 'impact': 'i', 'source': 's'},
          {'type': 'good', 'title': null, 'impact': 'i', 'source': 's'}, // 제목 없음 → 버림
          {'type': 'great', 'title': 't', 'impact': 'i', 'source': 's'}, // 모르는 종류 → 버림
        ],
        'B': 'oops',
      }
    })!;
    expect((n['companies']['A'] as List).length, 1);
    expect(n['companies'].containsKey('B'), false);
    expect(validNews({'companies': []}), isNull);
    expect(validValuation({'asof': 'x', 'companies': {'A': {'market_cap_usd_b': 1, 'rank': 1, 'per': 'NaN'}}}), false);
    expect(validValuation({'asof': 'x', 'companies': {'A': {'market_cap_usd_b': 1, 'rank': 1, 'per': null}}}), true);
  });

  test('퀴즈 문제 만들기: 보기 4개, 정답 포함, 겹치지 않음, 뜻에서 정답 가리기', () {
    final all = [
      for (var k = 0; k < 12; k++)
        {'id': 't$k', 'term': '용어$k(T$k)', 'definition': '용어$k은 뜻$k이에요. T$k라고도 해요.', 'category': k < 6 ? 'A' : 'B', 'example': 'e'}
    ];
    final qs = makeQuiz(all, Random(1), cat: 'A', n: 10);
    expect(qs.length, 6); // A 분야는 6개뿐
    expect(qs.map((q) => q.answer['id']).toSet().length, 6);
    for (final q in qs) {
      expect(q.options.length, 4);
      expect(q.options.map((o) => o['id']).toSet().length, 4);
      expect(q.options.any((o) => o['id'] == q.answer['id']), true);
      expect(q.prompt.contains(termName(q.answer)), false);
      expect(q.prompt.contains('○○'), true);
    }
  });

  test('증권사 예측 표시 도우미', () {
    expect(qLabel('2026-09'), '2026년 9월 분기');
    expect(usd(2.05), '\$2.05');
    expect(usd(-0.5), '−\$0.50');
    expect(validSurprise({'asof': 'x', 'companies': {'A': {'rows': [{'q': '2026-09', 'eps': 1, 'est': 1.1}]}}}), true);
    expect(validSurprise({'asof': 'x', 'companies': {'A': {'rows': [{'q': '2026-09', 'eps': '1', 'est': 1.1}]}}}), false);
  });
}
