import 'package:flutter_test/flutter_test.dart';
import 'package:jurini/main.dart';

void main() {
  final tl = [
    {'id': 'per', 'term': 'PER(주가수익비율)'},
    {'id': 'semi', 'term': '반도체'},
    {'id': 'memsemi', 'term': '메모리 반도체'},
    {'id': 'roe', 'term': 'ROE'},
    {'id': 'ev', 'term': 'EV'},
    {'id': 'stock', 'term': '주식'},
    {'id': 'equity', 'term': '자본'},
  ];
  String cut(String t) => [for (final m in findTermMatches(t, tl)) '${m.$3}:${t.substring(m.$1, m.$2)}'].join('|');

  test('긴 용어 먼저, 겹치지 않게, 같은 용어는 한 번만 칠해요', () {
    expect(cut('메모리 반도체 수요가 늘었고 반도체 장비도 팔려요'), 'memsemi:메모리 반도체|semi:반도체');
  });
  test('영문은 단어 경계만, 2글자 이하와 흔한 단어는 건너뜀', () {
    expect(cut('STEPS를 지나 PER이 낮아요. ROE는 높고 EV는 몰라요'), 'per:PER|roe:ROE');
    expect(cut('주식과 자본'), '');
    expect(cut('PERFECT 폭풍'), '');
  });
  test('최대 4개', () {
    final many = [for (var i = 0; i < 6; i++) {'id': 'k$i', 'term': '용어${String.fromCharCode(0xAC00 + i)}'}];
    expect(findTermMatches(many.map((m) => m['term']).join(' '), many).length, 4);
  });
}
