import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

void main() {
  test('숫자 포맷', () {
    expect(comma(1234567), '1,234,567');
    expect(eok(478834), '4,788억 달러'); // 백만 달러 → 억 달러
    expect(krw(5094), '5.09조 달러');
    expect(krw(850), '8,500억 달러'); // 십억 달러 → 억 달러
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
    expect(a['valuation']['comment'], 'c');
    expect(a['valuation']['asof'], '2026-11-11');
    expect(a['shareholder_return']['dividend_yield'], 1.25);
    expect(live.value, '2026-11-11');
  });
}
