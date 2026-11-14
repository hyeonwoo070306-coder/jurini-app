part of 'main.dart';

// 뉴스 글에서 용어사전 용어를 찾는다: (시작, 끝, id). 글자 수 3 미만·흔한 단어는 건너뛴다.
const _commonWords = {'주식'};
List<(int, int, String)> findTermMatches(String text, Iterable terms, {int max = 4}) {
  final cands = <(String, String)>[
    for (final t in terms)
      if (termName(t).length >= 3 && !_commonWords.contains(termName(t))) (termName(t), t['id'] as String),
  ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  final found = <(int, int, String)>[];
  bool latin(String c) => RegExp(r'[A-Za-z0-9]').hasMatch(c);
  for (final (name, id) in cands) {
    var from = 0;
    while (true) {
      final i = text.indexOf(name, from);
      if (i < 0) break;
      from = i + 1;
      final end = i + name.length;
      // 영문 용어는 앞뒤가 영문·숫자가 아닐 때만 (STEPS 안의 EPS 방지)
      if (latin(name[0]) && i > 0 && latin(text[i - 1])) continue;
      if (latin(name[name.length - 1]) && end < text.length && latin(text[end])) continue;
      if (found.any((f) => i < f.$2 && end > f.$1)) continue;
      found.add((i, end, id));
      break;
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  // 앞에 나온 것부터 max개 (긴 용어가 먼저 뽑혔으니 그중 앞쪽만 남긴다)
  return found.take(max).toList();
}

// 본문을 형광펜 용어가 섞인 글 조각으로 바꾼다.
List<InlineSpan> termSpans(BuildContext ctx, String text) {
  final out = <InlineSpan>[];
  var at = 0;
  for (final (a, b, id) in findTermMatches(text, terms)) {
    if (a > at) out.add(s(text.substring(at, a)));
    out.add(term(ctx, id, text.substring(a, b)));
    at = b;
  }
  if (at < text.length) out.add(s(text.substring(at)));
  return out;
}
