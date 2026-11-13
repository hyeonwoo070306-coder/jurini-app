import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'learn.dart';

typedef J = Map<String, dynamic>;

late J data, sp500, news, kr, usMore, surprise, links, calendar, lessons;
Set<String> ndx = {}; // 나스닥 100 티커
late List<dynamic> companies, terms;
late Map<String, dynamic> G;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Pretendard'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  data = jsonDecode(await rootBundle.loadString('assets/companies.json'));
  sp500 = jsonDecode(await rootBundle.loadString('assets/sp500.json'));
  news = jsonDecode(await rootBundle.loadString('assets/news.json'));
  kr = jsonDecode(await rootBundle.loadString('assets/kr.json'));
  usMore = jsonDecode(await rootBundle.loadString('assets/us_more.json'));
  surprise = jsonDecode(await rootBundle.loadString('assets/surprise.json'));
  links = jsonDecode(await rootBundle.loadString('assets/links.json'));
  calendar = jsonDecode(await rootBundle.loadString('assets/calendar.json'));
  lessons = jsonDecode(await rootBundle.loadString('assets/lessons.json'));
  ndx = {...usMore['meta']['nasdaq100']};
  terms = jsonDecode(await rootBundle.loadString('assets/glossary.json'))['terms'];
  G = {for (final t in terms) t['id'] as String: t};
  companies = mergeCompanies(data['companies'], [...sp500['companies'], ...usMore['companies']]);
  runApp(const App());
  loadLive();
}

// ---------- 매일 종가 기준 지표 (GitHub Actions가 매일 만드는 docs/valuation.json) ----------
// 깃허브 저장소를 만든 뒤 주소를 넣는다. 비어 있으면 앱에 든 숫자만 쓴다.
const liveBase = 'https://raw.githubusercontent.com/hyeonwoo070306-coder/jurini-app/main/docs/';
final live = ValueNotifier<String?>(null); // 받아온 종가 기준일
final redraw = ValueNotifier(0);

Future<J?> getJson(String file) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(liveBase + file)).timeout(const Duration(seconds: 8));
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join());
    return j is J ? j : null;
  } catch (_) {
    return null; // 인터넷이 없거나 파일이 이상하면 앱에 들어 있는 것을 그대로 쓴다.
  } finally {
    client.close();
  }
}

// 인터넷에서 받은 뉴스 파일: 형식이 맞는 뉴스만 남긴다. 하나라도 이상하면 그 뉴스만 버린다.
J? validNews(J n) {
  final cs = n['companies'];
  if (n['asof'] is! String || cs is! Map) return null;
  bool ok(dynamic x) =>
      x is Map && x['title'] is String && x['impact'] is String && x['source'] is String && newsKinds.containsKey(x['type']);
  return {
    ...n,
    if (n['market'] is List) 'market': [for (final x in n['market'] as List) if (ok(x)) x],
    'companies': <String, dynamic>{
      for (final e in cs.entries)
        if (e.value is List) e.key as String: [for (final x in e.value as List) if (ok(x)) x]
    },
  };
}

// 인터넷에서 받은 지표 파일: 숫자 칸이 숫자(또는 비어 있음)인지 확인
bool validValuation(J j) {
  final cs = j['companies'];
  if (j['asof'] is! String || cs is! Map) return false;
  for (final v in cs.values) {
    if (v is! Map || v['market_cap_usd_b'] is! num || v['rank'] is! int) return false;
    for (final k in ['per', 'forward_per', 'pbr', 'dividend_yield']) {
      if (v[k] != null && v[k] is! num) return false;
    }
  }
  return true;
}

bool validSurprise(J j) {
  final cs = j['companies'];
  if (j['asof'] is! String || cs is! Map) return false;
  for (final c in cs.values) {
    if (c is! Map || c['rows'] is! List) return false;
    for (final r in c['rows']) {
      if (r is! Map || r['q'] is! String || r['eps'] is! num || r['est'] is! num) return false;
    }
  }
  return true;
}

bool validCalendar(J j) =>
    j['asof'] is String &&
    j['events'] is List &&
    (j['events'] as List).every((e) => e is Map && e['date'] is String && e['title'] is String && e['type'] is String);

Future<void> loadLive() async {
  // 매일 AI 수업(사실 확인 통과분)과 AI가 추가한 용어. 없거나 형식이 틀리면 조용히 건너뜀
  getJson('glossary_ai.json').then((j) {
    if (j != null && j['terms'] is List) {
      mergeAiGlossary(j);
      redraw.value++;
    }
  });
  getJson('lesson_today.json').then((j) {
    if (j != null && validAiLesson(j)) {
      aiToday = j;
      redraw.value++;
    }
  });
  getJson('lessons_ai.json').then((j) {
    if (j != null && j['lessons'] is List) {
      aiArchive = [for (final l in j['lessons'] as List) if (l is Map && validAiLesson(l.cast<String, dynamic>())) l.cast<String, dynamic>()];
      redraw.value++;
    }
  });
  getJson('calendar.json').then((j) {
    if (j != null && validCalendar(j)) {
      calendar = j;
      redraw.value++;
    }
  });
  getJson('surprise.json').then((j) {
    if (j != null && validSurprise(j)) {
      surprise = j;
      redraw.value++;
    }
  });
  final raw = await getJson('news.json');
  final n = raw == null ? null : validNews(raw);
  if (n != null) news = n;
  final v = await getJson('valuation.json');
  if (v != null && validValuation(v)) {
    applyLive(v);
  } else if (n != null) {
    redraw.value++; // 뉴스만 바뀌어도 화면을 다시 그린다
  }
}

// shortcut: 받아온 숫자를 기기에 저장하지 않아 앱을 켤 때마다 새로 받음(약 10KB). 오프라인 사용이 많으면 저장 기능을 붙인다.
void applyLive(J j) {
  final String asof = j['asof'];
  final J byTk = j['companies'];
  for (final J c in companies) {
    final J? v = byTk[c['ticker']];
    if (v == null || !isFull(c)) continue;
    c['market_cap_usd_b'] = v['market_cap_usd_b'];
    final String day = v['asof'] is String ? v['asof'] : asof;
    c['market_cap_asof'] = day;
    c['rank'] = v['rank'];
    c['valuation'] = <String, dynamic>{...c['valuation'], 'per': v['per'], 'forward_per': v['forward_per'], 'pbr': v['pbr'], 'asof': day};
    c['shareholder_return'] = <String, dynamic>{...c['shareholder_return'], 'dividend_yield': v['dividend_yield']};
  }
  final full = companies.where((c) => isFull(c)).toList()..sort((a, b) => (a['rank'] as int).compareTo(b['rank']));
  companies = [...full, ...companies.where((c) => !isFull(c))];
  live.value = asof;
}

// 자세한 설명이 있는 회사(companies.json)를 먼저, 나머지 S&P 500은 기본 카드로 가나다순.
List<dynamic> mergeCompanies(List detailed, List basic) {
  final byTicker = {for (final b in basic) b['ticker']: b};
  final full = [for (final J d in detailed) {...d, 'group': byTicker[d['ticker']]?['sector']}];
  final rest = [for (final J b in basic) if (!full.any((d) => d['ticker'] == b['ticker'])) {...b, 'group': b['sector']}]
    ..sort((a, b) => (a['name_ko'] as String).compareTo(b['name_ko']));
  return [...full, ...rest];
}

bool isFull(J c) => c['business'] != null;
bool isKr(J c) => c['market'] != null; // 한국 회사(코스피·코스닥)

// ---------- 숫자·글자 포맷 ----------
const disclaimer = '투자 공부용 정보이며 매수·매도 추천이 아닙니다.';

String comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
// 시가총액: 십억 달러 단위
String krw(num b) => b >= 1000 ? '${(b / 1000).toStringAsFixed(2)}조 달러' : '${comma((b * 10).round())}억 달러';
// 재무: 백만 달러 단위
String eok(num? m) => m == null ? '-' : '${comma((m / 100).round())}억 달러';
// 한국 회사: 억 원 단위 숫자 → "33.4조 원" / "1,234억 원"
String wonEok(num? m) => m == null
    ? '-'
    : m.abs() >= 10000
        ? '${(m / 10000).toStringAsFixed(1)}조 원'
        : '${comma(m.round())}억 원';
String won(num m) {
  final jo = m * 1e6 * 1400 / 1e12;
  return jo >= 1 ? '약 ${jo.toStringAsFixed(jo >= 100 ? 0 : 1)}조 원' : '약 ${comma((jo * 10000).round())}억 원';
}
String nf(num x) => x == x.roundToDouble() ? x.round().toString() : x.toString();
String opt(num? x, String unit) => x == null ? '-' : '${nf(x)}$unit';
String period(String label) => label.replaceAll('최근 12개월(TTM)', '최근 12개월');
// Flutter엔 word-break:keep-all이 없어서 한글 글자 사이에 줄바꿈 금지 문자(U+2060)를 넣는다.
String kt(String s) => s.replaceAll(RegExp(r'(?<=[가-힣])(?=[가-힣])'), '⁠');

// ---------- 디자인 토큰 ----------
class P {
  final Color bg, surface, sunken, fg, muted, line, accent, accentSoft, mark, good, warn, goodSoft, warnSoft;
  final List<Color> seg;
  const P(this.bg, this.surface, this.sunken, this.fg, this.muted, this.line, this.accent, this.accentSoft, this.mark,
      this.good, this.warn, this.goodSoft, this.warnSoft, this.seg);

  static const light = P(Color(0xFFF2F4F6), Color(0xFFFFFFFF), Color(0xFFF2F4F6), Color(0xFF191F28), Color(0xFF6B7684),
      Color(0xFFEAEDF0), Color(0xFF0B7A62), Color(0xFFE6F2EE), Color(0xFFFFEBA0), Color(0xFF1F8A4C), Color(0xFFC2410C),
      Color(0xFFEFF7F1), Color(0xFFFDF1EA), [
        Color(0xFF0C6B5F), Color(0xFF3FA796), Color(0xFF8CCFC1), Color(0xFFE8B04B),
        Color(0xFFB9C4C1), Color(0xFF6E8A85), Color(0xFFD7DEDC), Color(0xFFA3B5B1)
      ]);
  static const dark = P(Color(0xFF0B0D10), Color(0xFF15181D), Color(0xFF1E2228), Color(0xFFF2F4F6), Color(0xFF8B95A1),
      Color(0xFF23272E), Color(0xFF7C9CFF), Color(0xFF1A2240), Color(0xFF8A6A00), Color(0xFF4ADE80), Color(0xFFFF8A5B),
      Color(0xFF13261B), Color(0xFF2E1C14), [
        Color(0xFF7C9CFF), Color(0xFF4C6FFF), Color(0xFFB4C3FF), Color(0xFFF2B84B),
        Color(0xFF5E6673), Color(0xFF9AA6B8), Color(0xFF39404A), Color(0xFF6F7A8A)
      ]);
  static P of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const brand = {
  'aapl': Color(0xFF3D4A48), 'nvda': Color(0xFF4F8A1F), 'msft': Color(0xFF2F6DB5), 'googl': Color(0xFFC2463A),
  'amzn': Color(0xFFD98A14), 'spcx': Color(0xFF1E2A3A), 'meta': Color(0xFF2D5FD3), 'avgo': Color(0xFFB5312A),
  'tsla': Color(0xFF9E2A2A), 'lly': Color(0xFFC21E3A),
};

ThemeData theme(P p, Brightness b) => ThemeData(
      brightness: b,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b, primary: p.accent, surface: p.surface, onSurface: p.fg),
      appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.fg, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: p.surface,
          indicatorColor: Colors.transparent,
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith(
              (st) => IconThemeData(color: st.contains(WidgetState.selected) ? p.fg : p.muted)),
          labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
              fontSize: 12,
              fontWeight: st.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: st.contains(WidgetState.selected) ? p.fg : p.muted))),
      chipTheme: ChipThemeData(
          backgroundColor: p.surface,
          selectedColor: p.fg,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          // 직접 준 글자 모양은 테마 글꼴을 물려받지 않아서 글꼴을 꼭 적는다
          labelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, fontWeight: FontWeight.w600, color: p.muted),
          secondaryLabelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, fontWeight: FontWeight.w600, color: p.surface),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: p.surface,
          hintStyle: TextStyle(color: p.muted, fontSize: 14.5),
          prefixIconColor: p.muted,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      textTheme: ThemeData(brightness: b, fontFamily: 'Pretendard').textTheme.apply(bodyColor: p.fg, displayColor: p.fg),
    );

// ---------- 작은 위젯 도우미 ----------
const pad = EdgeInsets.fromLTRB(16, 16, 16, 32);
const bold = TextStyle(fontWeight: FontWeight.w700);
TextStyle h(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.3);
TextStyle sub(P p, [double size = 12.5]) => TextStyle(fontSize: size, color: p.muted);

List<Widget> spaced(double g, List<Widget> ws) => [
      for (var i = 0; i < ws.length; i++) ...[if (i > 0) SizedBox(height: g), ws[i]]
    ];
Widget col(double g, List<Widget> ws) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(g, ws));

Widget txt(String t, [TextStyle? st]) => Text(kt(t), style: st);
Widget h3(String t) => txt(t, h(17));
TextSpan s(String t, [TextStyle? st]) => TextSpan(text: kt(t), style: st);
Widget rich(List<InlineSpan> spans, [TextStyle? st]) => Text.rich(TextSpan(children: spans), style: st);

// 형광펜 용어: 누르면 용어 바텀시트
TextSpan term(BuildContext ctx, String id, [String? label]) => TextSpan(
      text: kt(label ?? (G[id]['term'] as String).replaceAll(RegExp(r'\(.*\)'), '')),
      style: TextStyle(backgroundColor: P.of(ctx).mark, color: P.of(ctx).fg, fontWeight: FontWeight.w600),
      recognizer: TapGestureRecognizer()..onTap = () => openTerm(ctx, id),
    );

Widget box(P p, Widget child,
        {Color? color, double r = 18, EdgeInsets pad = const EdgeInsets.all(18), bool border = false}) =>
    Container(
      padding: pad,
      decoration: BoxDecoration(
          color: color ?? p.surface, borderRadius: BorderRadius.circular(r), border: border ? Border.all(color: p.line) : null),
      child: child,
    );

// 묶음 목록의 한 줄: 맨 위·맨 아래만 둥글게, 사이엔 얇은 선
Widget groupRow(P p, bool first, bool last, VoidCallback onTap, Widget child) => Material(
      color: p.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(first ? 18 : 0), bottom: Radius.circular(last ? 18 : 0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Container(
              decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.line))), child: child)),
    );

const newsKinds = {'good': ('호재', '좋은 소식'), 'bad': ('악재', '걱정되는 소식'), 'watch': ('지켜볼 일', '앞으로 있을 일')};

Widget newsCard(P p, List items) {
  Color colorOf(String t) => t == 'good' ? p.good : t == 'bad' ? p.warn : p.accent;
  // 상세 화면에서 가장 먼저 눈에 띄어야 하는 칸: 장식 대신 파란 바탕 한 겹으로 구분
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(16)),
    child: col(14, [
      Row(children: [
        Icon(Icons.newspaper_rounded, size: 20, color: p.accent),
        const SizedBox(width: 8),
        Expanded(child: Text('최근 뉴스', style: h(19))),
        Text('${news['asof']} 정리', style: sub(p, 11.5)),
      ]),
      for (final (i, n) in items.indexed) ...[
        if (i > 0) Container(height: 1, color: p.accent.withValues(alpha: .18)),
        col(6, [
          Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: colorOf(n['type']).withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                child: Text(newsKinds[n['type']]?.$1 ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorOf(n['type'])))),
            const SizedBox(width: 8),
            Text(n['date'] ?? '', style: sub(p, 12)),
          ]),
          txt(n['title'], const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.45)),
          rich([
            TextSpan(text: '회사에 주는 영향  ', style: TextStyle(fontWeight: FontWeight.w700, color: colorOf(n['type']))),
            s(n['impact']),
          ], const TextStyle(fontSize: 14, height: 1.5)),
          Text('출처: ${n['source']}', style: sub(p, 11.5)),
        ]),
      ],
      txt('AI(Claude)가 하루 두 번 뉴스를 모아 자동으로 정리해요. 틀릴 수 있으니 중요한 내용은 원문으로 확인하세요. 호재·악재는 뉴스 내용을 쉽게 나눈 것일 뿐, 주가가 어떻게 움직일지는 아무도 몰라요.',
          sub(p, 11.5)),
    ]),
  );
}

// "2026-09" → "2026년 9월 분기"
String qLabel(String q) => '${q.substring(0, 4)}년 ${int.parse(q.substring(5))}월 분기';
String usd(num x) => '${x < 0 ? '−' : ''}\$${x.abs().toStringAsFixed(2)}';

// 증권사 예측 평균(컨센서스) EPS vs 실제 EPS. 차이 2% 미만은 '예상 수준'
Widget surpriseCard(BuildContext ctx, P p, J data) {
  final List rows = data['rows'];
  final J? next = data['next'];
  (String, Color) tag(num? pct) => pct == null
      ? ('비교 불가', p.muted)
      : pct >= 2
          ? ('예상보다 좋음 +${nf(pct)}%', p.good)
          : pct <= -2
              ? ('예상보다 나쁨 ${nf(pct)}%', p.warn)
              : ('예상 수준 ${pct >= 0 ? '+' : ''}${nf(pct)}%', p.muted);
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(14)),
    child: col(10, [
      rich([s('증권사 예측과 비교 ('), term(ctx, 'eps', 'EPS'), s(')')], h(15)),
      rich([term(ctx, 'consensus', '증권사 예측 평균'), s('과 실제 실적을 비교해요. 차이가 크면 '), term(ctx, 'earnings_surprise', '어닝 서프라이즈·쇼크'), s('라고 해요.')],
          sub(p, 12.5)),
      for (final r in rows)
        Row(children: [
          Expanded(
              child: col(2, [
            Text(qLabel(r['q']), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text('예측 ${usd(r['est'])} → 실제 ${usd(r['eps'])}', style: sub(p, 12.5).copyWith(fontFeatures: tabular)),
          ])),
          () {
            final (label, color) = tag(r['pct']);
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)));
          }(),
        ]),
      if (next != null)
        txt('다음 ${qLabel(next['q'])} 예측 EPS: ${usd(next['est'])}${next['n'] == null ? '' : ' (분석가 ${next['n']}명 평균)'}', sub(p, 12.5)),
      txt('출처: 나스닥 (${surprise['asof']} 기준). 매출·영업이익 예측은 유료 데이터라 아직 보여드리지 못해요.', sub(p, 11.5)),
    ]),
  );
}

Widget pointCard(P p, IconData icon, String title, Color color, Color soft, List items) => box(
    p,
    col(12, [
      Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 10),
        Text(title, style: h(16)),
      ]),
      col(10, [
        for (final x in items)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                margin: const EdgeInsets.only(top: 8, right: 10, left: 4),
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            Expanded(child: txt(x, const TextStyle(fontSize: 14.5, height: 1.5))),
          ])
      ]),
    ]));

Widget explain(P p, Widget child) =>
    box(p, child, color: p.sunken, border: false, r: 12, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

Widget fact(P p, Widget label, String value, [double size = 17]) => box(
    p, col(2, [label, Text(value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700))]),
    color: p.sunken, border: false, r: 12, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));

Widget grid(List<Widget> xs) => col(8, [
      for (var i = 0; i < xs.length; i += 2)
        IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: xs[i]),
          const SizedBox(width: 8),
          Expanded(child: i + 1 < xs.length ? xs[i + 1] : const SizedBox()),
        ]))
    ]);

// 누를 수 있으면 Material ActionChip(누르는 칸 48dp), 아니면 그냥 라벨
Widget chip(P p, String label, [VoidCallback? onTap]) => onTap == null
    ? Chip(label: Text(label), backgroundColor: p.sunken, labelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 13, color: p.fg))
    : ActionChip(
        label: Text(label), onPressed: onTap, backgroundColor: p.sunken, labelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 13, color: p.fg));

Color brandColor(J c) {
  final String tk = c['ticker'];
  return brand[c['id']] ?? HSLColor.fromAHSL(1, (tk.codeUnits.fold(0, (a, b) => a * 31 + b) % 360).toDouble(), .35, .4).toColor();
}

const tabular = [FontFeature.tabularFigures()];
const ink = Color(0xFF191F28);

// shortcut: 로고 이미지는 FMP(financialmodelingprep.com)의 공개 로고 주소를 쓴다. 로고는 각 회사의 상표라
//           광고를 붙여 출시하기 전에 이용 조건을 확인하고, 필요하면 로고 사용 허락을 받은 서비스로 바꾼다.
String logoUrl(J c) {
  final String tk = c['ticker'];
  final code = isKr(c) ? '$tk.${c['market'] == '코스닥' ? 'KQ' : 'KS'}' : tk.replaceAll('.', '-');
  return 'https://financialmodelingprep.com/image-stock/$code.png';
}

Widget logo(J c, [double size = 44, Color? bg]) {
  final badge = logoBadge(c, size, bg);
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * .3),
    child: Image.network(
      logoUrl(c),
      width: size,
      height: size,
      cacheWidth: (size * 3).round(), // 원본 대신 화면 크기에 맞게 풀어서 메모리 절약
      fit: BoxFit.contain,
      // 투명 배경 로고가 어두운 화면에서도 보이게 흰 바탕 위에 그린다
      frameBuilder: (_, child, frame, __) => frame == null
          ? badge
          : Container(width: size, height: size, color: Colors.white, padding: EdgeInsets.all(size * .12), child: child),
      errorBuilder: (_, __, ___) => badge,
    ),
  );
}

Widget logoBadge(J c, double size, Color? bg) {
  final String tk = c['ticker'];
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg ?? brandColor(c), borderRadius: BorderRadius.circular(size * .3)),
    child: Text(isKr(c) ? (c['name_ko'] as String).characters.take(2).toString() : tk.substring(0, min(4, tk.length)),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .29)),
  );
}

PreferredSizeWidget topBar(BuildContext ctx, String title, String trailing) => AppBar(
      title: Text(title, style: h(20)),
      centerTitle: false,
      actions: [
        Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(trailing, style: sub(P.of(ctx), 12))))
      ],
    );

Widget timeline(P p, List xs) => col(8, [
      for (final x in xs)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              margin: const EdgeInsets.only(top: 8, right: 10),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
          Expanded(child: txt(x, const TextStyle(fontSize: 14))),
        ])
    ]);

Widget bullets(List xs) => col(4, [
      for (final x in xs)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(child: txt(x, const TextStyle(fontSize: 14))),
        ])
    ]);

// 사업별·지역별 비중 막대 + 범례
Widget mix(P p, List rows) => col(10, [
      ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
              height: 18,
              child: Row(children: [
                for (var i = 0; i < rows.length; i++)
                  Expanded(
                      flex: max(1, ((rows[i][1] as num) * 10).round()),
                      child: Container(margin: EdgeInsets.only(left: i > 0 ? 2 : 0), color: p.seg[i % 8])),
              ]))),
      col(6, [
        for (var i = 0; i < rows.length; i++)
          Row(children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: p.seg[i % 8], borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: txt(rows[i][0], const TextStyle(fontSize: 13.5))),
            Text('${nf(rows[i][1])}%', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ])
      ]),
    ]);

Widget barRow(P p, String label, num? x, num mx, bool latest, [String Function(num?) fmt = eok]) => Row(children: [
      SizedBox(width: 76, child: txt(label, sub(p).copyWith(height: 1.25))),
      const SizedBox(width: 10),
      Expanded(
          child: SizedBox(
              height: 26,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Positioned.fill(
                    child: Container(
                        decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(8)))),
                if (x != null)
                Positioned.fill(
                    child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max(.02, x.abs() / mx).toDouble(),
                        child: Container(
                            decoration: BoxDecoration(
                                color: x < 0 ? p.warn : (latest ? p.accent : p.seg[1]),
                                borderRadius: BorderRadius.circular(8))))),
                Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(6)),
                        child: Text(x == null ? '공시 없음' : '${x < 0 ? '−' : ''}${fmt(x.abs())}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)))),
              ]))),
    ]);

// PER 위치 게이지 (0~60배, 평균선 21배)
Widget gauge(P p, double pos) => col(6, [
      SizedBox(
          height: 20,
          child: LayoutBuilder(
              builder: (_, k) => Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                    Container(
                        height: 12,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(colors: [p.goodSoft, p.sunken, p.warnSoft], stops: const [0, .45, 1]))),
                    Positioned(left: k.maxWidth * 21 / 60 - 1, top: 0, bottom: 0, child: Container(width: 2, color: p.muted)),
                    Positioned(
                        left: k.maxWidth * pos - 10,
                        child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: p.accent, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 3)))),
                  ]))),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final t in ['0배', '평균 약 20배', '60배+']) Text(t, style: sub(p, 11.5))
      ]),
    ]);

Widget riskItem(P p, String r) {
  final i = r.indexOf(':');
  final head = i < 0 ? r : r.substring(0, i), rest = i < 0 ? '' : r.substring(i + 1).trim();
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(top: 1, right: 10), child: Icon(Icons.error_outline_rounded, size: 18, color: p.warn)),
    Expanded(
        child: col(2, [
      txt(head, const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      if (rest.isNotEmpty) txt(rest, const TextStyle(fontSize: 14, height: 1.5)),
    ])),
  ]);
}

// ---------- 용어 바텀시트 ----------
void openTerm(BuildContext ctx, String id) {
  final J? t = G[id];
  if (t == null) return;
  final p = P.of(ctx);
  final names = [
    for (final tk in (t['used_by'] as List?) ?? []) // AI가 추가한 용어엔 없음
      for (final c in companies)
        if (c['ticker'] == tk) c['name_ko']
  ];
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: p.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: col(12, [
          Wrap(spacing: 6, children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(t['category'] ?? '경제용어', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.accent))),
            if (t['ai'] == true)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(999)),
                  child: Text('AI가 추가한 용어', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.muted))),
          ]),
          txt(t['term'], h(20)),
          txt(t['definition'], const TextStyle(fontSize: 15)),
          explain(p, col(2, [Text('예시', style: sub(p, 12)), txt(t['example'], const TextStyle(fontSize: 14))])),
          if (t['why'] != null)
            explain(p, col(2, [
              Text('주가에 왜 중요할까?', style: sub(p, 12).copyWith(fontWeight: FontWeight.w700, color: p.accent)),
              txt(t['why'], const TextStyle(fontSize: 14, height: 1.5)),
            ])),
          if (t['market_effect'] != null) ...[
            explain(p, col(2, [Text('시장에 주는 영향', style: sub(p, 12)), txt(t['market_effect'], const TextStyle(fontSize: 14))])),
            txt('일반적인 경향이며, 항상 이렇게 움직이지는 않아요.', sub(p)),
          ],
          if (names.isNotEmpty) txt('이 용어가 나오는 회사: ${names.join(', ')}', sub(p)),
          Text(disclaimer, style: sub(p, 11.5)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.fg,
                foregroundColor: p.surface,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(sheet),
            child: const Text('알겠어요', style: bold),
          ),
        ]),
      ),
    ),
  );
}

// ---------- 앱 ----------
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([live, redraw]),
      builder: (_, __) => MaterialApp(
            title: '주린이 기업 노트',
            debugShowCheckedModeBanner: false,
            theme: theme(P.light, Brightness.light),
            darkTheme: theme(P.dark, Brightness.dark),
            themeMode: ThemeMode.dark,
            home: const Shell(),
          ));
}

final homeKey = GlobalKey();

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        // live/redraw가 바뀌면 화면을 새로 만들어 받은 숫자가 바로 보이게 한다
        body: ListenableBuilder(
            listenable: Listenable.merge([live, redraw]),
            builder: (_, __) =>
                IndexedStack(
                index: i, children: [const LearnPage(), HomePage(key: homeKey), const LinksPage(), const TermsPage(), const NewsPage()])),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.school_outlined), label: '배우기'),
            NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '기업'),
            NavigationDestination(icon: Icon(Icons.hub_outlined), label: '연결'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '용어사전'),
            NavigationDestination(icon: Icon(Icons.newspaper_rounded), label: '뉴스'),
          ],
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  String q = '';
  String? sector;
  bool korea = false;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final query = q.trim().toLowerCase();
    final List src = korea ? kr['companies'] : companies;
    final sectors = {for (final c in src) c['group']}.whereType<String>().toList()..sort();
    final list = src.where((c) {
      if (sector != null && c['group'] != sector) return false;
      return query.isEmpty || '${c['name_ko']} ${c['name_en']} ${c['ticker']}'.toLowerCase().contains(query);
    }).toList();
    final header = spaced(12, [
          // 장식 없는 제목 영역: 질문 한 줄, 설명 한 줄, 범위·기준일 한 줄
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: col(8, [
              txt(korea ? '한국 상장 기업, 무슨 일을 할까요?' : '미국 대표 기업, 무슨 일을 할까요?',
                  h(24).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              txt(korea ? '회사를 누르면 업종·주요 제품과 금융감독원 공시 재무 숫자를 볼 수 있어요. 매출이 큰 회사부터 보여드려요.' : '회사를 누르면 중학생도 읽을 수 있게 풀어 쓴 기업 노트가 열려요.',
                  sub(p, 14).copyWith(height: 1.5)),
              Text(
                  korea
                      ? '${src.length}개 회사 (코스피 ${src.where((c) => c['market'] == '코스피').length} · 코스닥 ${src.where((c) => c['market'] == '코스닥').length}) · ${kr['meta']['asof']} 상장 목록 기준'
                      : '${src.length}개 회사 · 자세한 노트 ${companies.where((c) => isFull(c)).length}곳 · 시가총액 ${live.value ?? data['meta']['market_cap_asof']}${live.value == null ? '' : ' 종가'} 기준',
                  style: sub(p, 12).copyWith(fontFeatures: tabular)),
              Text(disclaimer, style: sub(p, 11.5)),
            ]),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('미국')),
              ButtonSegment(value: true, label: Text('한국')),
            ],
            selected: {korea},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              korea = v.first;
              sector = null;
            }),
          ),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
                hintText: korea ? '회사 이름이나 종목코드 검색 (예: 삼성, 005930)' : '회사 이름이나 티커 검색 (예: 애플, KO)',
                prefixIcon: const Icon(Icons.search)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in [null, ...sectors])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s ?? '전체'),
                    selected: sector == s,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => sector = s),
                  ),
                ),
            ]),
          ),
          rich([
            term(context, 'market_cap', '시가총액'),
            s('처럼 형광펜 칠한 단어를 누르면 뜻을 바로 알려드려요.'),
          ], sub(p, 13)),
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${list.length}개 회사', style: sub(p, 13).copyWith(fontWeight: FontWeight.w600))),
          if (list.isEmpty) Text('찾는 회사가 없어요.', style: sub(p)),
        ]);
    // 500개를 한 번에 그리지 않도록 화면에 보이는 줄만 만든다.
    return Scaffold(
      body: ListView.builder(
        padding: pad.copyWith(top: MediaQuery.of(context).padding.top + 12),
        itemCount: header.length + list.length + 1,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          if (i == header.length + list.length) {
            return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(disclaimer, textAlign: TextAlign.center, style: sub(p, 11.5)));
          }
          final k = i - header.length;
          return Padding(
              padding: EdgeInsets.only(top: k == 0 ? 10 : 0),
              child: companyRow(context, p, list[k], k == 0, k == list.length - 1));
        },
      ),
    );
  }
}

Widget companyRow(BuildContext context, P p, J c, [bool first = true, bool last = true]) => groupRow(
      p,
      first,
      last,
      () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(c))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          if (c['rank'] != null)
            SizedBox(
                width: 26,
                child: Text('${c['rank']}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.muted, fontFeatures: tabular))),
          logo(c, 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: c['name_ko'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              TextSpan(text: '  ${c['ticker']}', style: sub(p, 12)),
              if (ndx.contains(c['ticker'])) TextSpan(text: '  나스닥100', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.accent)),
            ])),
            if ((c['one_liner'] ?? '') != '')
              Text(kt(c['one_liner']), maxLines: 2, overflow: TextOverflow.ellipsis, style: sub(p, 13)),
          ])),
          if (isKr(c) && (c['financials'] as List?)?.isNotEmpty == true && c['financials'].last['revenue'] != null) ...[
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(wonEok(c['financials'].last['revenue']).replaceAll(' 원', ''),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: tabular)),
              Text('원 매출', style: sub(p, 11)),
            ]),
          ],
          if (c['market_cap_usd_b'] != null) ...[
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(c['market_cap_usd_b'] / 1000).toStringAsFixed(2)}조',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: tabular)),
              Text('달러', style: sub(p, 11)),
            ]),
          ],
        ]),
      ),
    );

const tabs = {'biz': '사업', 'money': '돈 버는 법', 'perf': '실적', 'value': '주가 수준', 'div': '배당', 'risk': '리스크'};
const metrics = {
  'revenue': ('매출', 'revenue', '회사가 1년 동안 판 금액 전체예요.'),
  'operating_income': ('영업이익', 'operating_income', '본업으로 남긴 이익이에요. 회사의 실력을 볼 때 가장 먼저 봐요.'),
  'free_cash_flow': ('잉여현금', 'fcf', '투자까지 하고 실제로 남은 현금이에요. 배당과 자사주 매입은 여기서 나와요.'),
};

class DetailPage extends StatefulWidget {
  final J c;
  const DetailPage(this.c, {super.key});
  @override
  State<DetailPage> createState() => _DetailState();
}

class _DetailState extends State<DetailPage> {
  late String tab = isFull(widget.c) ? 'biz' : 'perf';
  String metric = 'revenue';

  @override
  Widget build(BuildContext context) {
    final c = widget.c, p = P.of(context), full = isFull(c);
    final List fin = c['financials'] ?? [];
    final J? latest = fin.isEmpty ? null : fin.last;
    final bc = brandColor(c);
    const w70 = TextStyle(color: Colors.white70, fontSize: 12);
    // 형광펜 용어는 노란 바탕이라 글자만 어둡게
    final onMark = TextStyle(color: p.fg, fontSize: 12);
    Widget heroFact(Widget label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
        child: col(4, [
          label,
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ]));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bc,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: Text(full ? '시가총액 ${c['rank']}위' : c['sector'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)))),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bc, Color.lerp(bc, Colors.black, .3)!]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
            child: col(16, [
              Row(children: [
                logo(c, 56, Colors.white.withValues(alpha: .16)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name_ko'], style: h(26).copyWith(color: Colors.white)),
                  Text([c['ticker'], c['exchange'] ?? c['market'], c['sector']].whereType<String>().join(' · '), style: w70),
                ])),
              ]),
              if ((c['one_liner'] ?? '') != '')
                txt(c['one_liner'], const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.5)),
              grid([
                if (c['market_cap_usd_b'] != null)
                  heroFact(rich([term(context, 'market_cap', '시가총액')], onMark), krw(c['market_cap_usd_b'])),
                if (latest?['revenue'] != null)
                  heroFact(rich([s('1년 ', w70), term(context, 'revenue', '매출'), s(' (${period(latest!['label'])})', w70)], onMark),
                      (isKr(c) ? wonEok : eok)(latest['revenue'])),
              ]),
            ]),
          ),
          Padding(
            padding: pad,
            child: col(14, [
          if (!full)
            explain(p, txt(isKr(c)
                ? '이 회사의 자세한 설명은 준비 중이에요. 지금은 한국거래소에 등록된 업종·주요제품과 금융감독원 DART 사업보고서 숫자만 보여드려요. (${c['market']}, ${c['listed']} 상장)'
                : '이 회사의 자세한 설명(투자 포인트, 사업, 리스크)은 준비 중이에요. 지금은 미국 SEC 공시에서 가져온 숫자만 보여드려요.',
                const TextStyle(fontSize: 13.5))),
          if ((news['companies'][c['ticker']] as List?)?.isNotEmpty ?? false) newsCard(p, news['companies'][c['ticker']]),
          if (full) ...[
          pointCard(p, Icons.trending_up_rounded, '투자 포인트', p.good, p.goodSoft, c['invest_points']),
          pointCard(p, Icons.error_outline_rounded, '주의할 점', p.warn, p.warnSoft, c['cautions']),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in tabs.entries)
                Semantics(
                  button: true,
                  selected: tab == e.key,
                  child: InkWell(
                  onTap: () => setState(() => tab = e.key),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                    margin: const EdgeInsets.only(right: 18),
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: tab == e.key ? p.fg : Colors.transparent, width: 2))),
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: tab == e.key ? FontWeight.w700 : FontWeight.w500,
                            color: tab == e.key ? p.fg : p.muted)),
                  ),
                )),
            ]),
          ),
          ],
          box(p, r: 20, col(14, fin.isEmpty ? [h3('실적'), txt('공시에서 찾은 재무 숫자가 없어요.', sub(p))] : panel(context, p, c))),
          if (full)
          box(p, r: 20, col(14, [
            h3('이 회사에 나온 용어'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final String t in c['terms']) chip(p, G[t]['term'], () => openTerm(context, t)),
            ]),
          ])),
          txt(
              full
                  ? '출처: ${(c['sources'] as List).join(' · ')}\n시가총액 ${c['market_cap_asof']}, 주가 지표 ${c['valuation']['asof']} 기준. $disclaimer'
                  : isKr(c)
                      ? '출처: ${kr['meta']['source']} (${kr['meta']['asof']} 수집). $disclaimer'
                      : '출처: ${sp500['meta']['source']} (${sp500['meta']['asof']} 수집). 자동으로 뽑은 숫자라 회사 공시와 다를 수 있어요. $disclaimer',
              sub(p, 11.5)),
            ]),
          ),
        ],
      ),
    );
  }

  List<Widget> panel(BuildContext ctx, P p, J c) {
    final J v = c['valuation'] ?? {}, sr = c['shareholder_return'] ?? {}, b = c['balance'] ?? {};
    final List fin = c['financials'];
    const body = TextStyle(fontSize: 14.5);
    switch (tab) {
      case 'biz':
        return [
          h3('무슨 일을 하나요?'),
          txt(c['business'], body),
          rich([s('왜 강한가요?  '), TextSpan(children: [term(ctx, 'moat', '해자')], style: sub(p))], h(17)),
          txt(c['moat'], body),
          col(6, [Text('경쟁사', style: sub(p)), Wrap(spacing: 6, runSpacing: 6, children: [for (final x in c['competitors']) chip(p, x)])]),
        ];
      case 'money':
        final J rm = c['revenue_mix'];
        final List region = rm['by_region'] ?? [];
        return [
          h3('돈은 어디서 버나요?'),
          rich([s('${rm['fiscal_year']} 기준 '), term(ctx, 'revenue', '매출'), s(' 비중')], sub(p)),
          mix(p, rm['by_segment']),
          if (region.isNotEmpty) ...[h3('어느 나라에서 팔까요?'), mix(p, region)],
          if ((rm['note'] ?? '') != '') txt('※ ${rm['note']}', sub(p)),
          h3('앞으로 성장할 곳'),
          timeline(p, c['growth_drivers']),
        ];
      case 'perf':
        final (label, tid, help) = metrics[metric]!;
        final mx = fin.map((f) => (f[metric] as num? ?? 0).abs()).fold<num>(1, max);
        final J last = fin.last;
        final num? nc = b['net_cash'];
        final money = isKr(c) ? wonEok : eok;
        return [
          h3('실적은 늘고 있나요?'),
          // 홈의 미국/한국 전환과 같은 Material SegmentedButton
          SegmentedButton<String>(
            segments: [
              for (final e in metrics.entries)
                if (!(isKr(c) && e.key == 'free_cash_flow')) // 한국 DART 요약엔 현금흐름이 없다
                  ButtonSegment(value: e.key, label: Text(e.value.$1)),
            ],
            selected: {metric},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => metric = v.first),
          ),
          rich([term(ctx, tid, label), s(': $help')], sub(p)),
          col(10, [
            for (var i = 0; i < fin.length; i++) barRow(p, period(fin[i]['label']), fin[i][metric], mx, i == fin.length - 1, money)
          ]),
          grid([
            fact(p, rich([term(ctx, 'operating_margin', '영업이익률')], sub(p, 12)), opt(last['operating_margin_pct'], '%')),
            if (!isKr(c)) fact(p, rich([term(ctx, 'capex', '설비투자')], sub(p, 12)), eok(last['capex'])),
            if (b.containsKey('equity')) ...[
              // 한국 DART 카드: 자산·부채·자본 총계
              fact(p, Text('자산총계', style: sub(p, 12)), money(b['total_assets'])),
              fact(p, Text('부채총계', style: sub(p, 12)), money(b['total_debt'])),
              fact(p, Text('자본총계', style: sub(p, 12)), money(b['equity'])),
            ] else if (b.containsKey('cash')) ...[
              // SEC 기본 카드: 유가증권이 빠진 현금, 장기부채만 있다
              fact(p, Text('현금성 자산', style: sub(p, 12)), eok(b['cash'])),
              fact(p, Text('장기부채', style: sub(p, 12)), eok(b['long_term_debt'])),
            ] else ...[
              fact(p, Text('현금·투자자산', style: sub(p, 12)), eok(b['cash_and_investments'])),
              fact(p, Text('총부채', style: sub(p, 12)), eok(b['total_debt'])),
            ],
          ]),
          if (b['asof'] != null) txt('${isKr(c) ? '자산·부채' : '현금·부채'}는 ${b['asof']} 기준이에요.', sub(p)),
          if (nc != null)
          explain(
              p,
              rich([
                ...nc >= 0
                    ? [s('빚보다 현금이 '), TextSpan(text: eok(nc), style: bold), s(' 더 많아요 ('), term(ctx, 'net_cash', '순현금'), s('). ')]
                    : [s('현금보다 빚이 '), TextSpan(text: eok(-nc), style: bold), s(' 더 많아요 ('), term(ctx, 'net_debt', '순부채'), s('). ')],
                TextSpan(text: '${b['asof']} 기준', style: sub(p)),
              ], const TextStyle(fontSize: 13.5))),
          if ((c['financial_note'] ?? '') != '') txt('※ ${c['financial_note']}', sub(p)),
          if ((surprise['companies'][c['ticker']]?['rows'] as List?)?.isNotEmpty ?? false)
            surpriseCard(ctx, p, surprise['companies'][c['ticker']]),
          if (isKr(c) && c['fs'] != null) txt('${c['fs']} 재무제표 기준이에요. 연결은 자회사까지 합친 숫자예요.', sub(p)),
          if (last['revenue'] != null && !isKr(c))
            txt('1억 달러는 환율 1,400원 기준 약 1,400억 원이에요. 최근 매출 ${eok(last['revenue'])} ≈ ${won(last['revenue'])}.', sub(p)),
        ];
      case 'value':
        final num? per = v['per'];
        final verdict = per == null
            ? '적자라 PER을 계산할 수 없어요'
            : per < 15
                ? '시장 평균보다 낮은 편'
                : per <= 28
                    ? '시장 평균 근처'
                    : per <= 45
                        ? '시장 평균보다 높은 편'
                        : '시장 평균보다 훨씬 높은 편';
        return [
          h3('지금 주가 수준은 어느 정도일까요?'),
          if (per != null && per > 100) txt('이익이 아주 작으면 PER이 지나치게 커져서 숫자의 의미가 줄어요.', sub(p)),
          rich([
            term(ctx, 'per', 'PER'),
            s(' ${per == null ? '-' : '${per.toStringAsFixed(1)}배'} · '),
            TextSpan(text: kt(verdict), style: bold),
          ], sub(p)),
          if (per != null) gauge(p, min(per, 60) / 60),
          grid([
            fact(p, rich([term(ctx, 'forward_per', '선행 PER')], sub(p, 12)), opt(v['forward_per'], '배')),
            fact(p, rich([term(ctx, 'pbr', 'PBR')], sub(p, 12)), opt(v['pbr'], '배')),
            fact(p, rich([term(ctx, 'roe', 'ROE')], sub(p, 12)), opt(v['roe'], '%')),
            fact(p, Text('기준일', style: sub(p, 12)), v['asof'], 14),
          ]),
          explain(p, txt(v['comment'], const TextStyle(fontSize: 13.5))),
          txt('평균선은 대략적인 참고값이에요. PER은 주가가 바뀌면 매일 달라져요.', sub(p)),
        ];
      case 'div':
        final num? dps = sr['dividend_per_share'];
        return [
          h3('주주에게 얼마나 돌려주나요?'),
          if (dps == null)
            explain(p, rich([const TextSpan(text: '배당을 주지 않는 회사예요. ', style: bold), s('번 돈을 성장에 다시 투자하고 있어요.')], const TextStyle(fontSize: 13.5)))
          else ...[
            grid([
              fact(p, Text('1년 배당금 (1주)', style: sub(p, 12)), '\$${dps.toStringAsFixed(2)}'),
              fact(p, rich([term(ctx, 'dividend_yield', '배당수익률')], sub(p, 12)), opt(sr['dividend_yield'], '%')),
              fact(p, rich([term(ctx, 'payout_ratio', '배당성향')], sub(p, 12)), opt(sr['payout_ratio'], '%')),
              fact(p, Text('연속 배당 증가', style: sub(p, 12)), opt(sr['dividend_growth_years'], '년')),
            ]),
            txt('${sr['frequency']}마다 지급 · 100주를 갖고 있으면 1년에 약 \$${(dps * 100).toStringAsFixed(0)}를 받아요.', sub(p)),
          ],
          rich([term(ctx, 'buyback', '자사주 매입')], h(17)),
          txt(sr['buyback'], body),
        ];
      default:
        return [
          h3('어떤 위험이 있나요?'),
          col(8, [for (final String r in c['risks']) riskItem(p, r)]),
          h3('앞으로 볼 일정'),
          timeline(p, c['upcoming']),
        ];
    }
  }
}

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});
  @override
  State<TermsPage> createState() => _TermsState();
}

class _TermsState extends State<TermsPage> {
  String q = '';
  String? cat;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final query = q.trim().toLowerCase();
    final list = terms
        .where((t) => cat == null || t['category'] == cat)
        .where((t) => query.isEmpty || '${t['term']}${t['definition']}'.toLowerCase().contains(query))
        .toList();
    final cats = [for (final t in terms) t['category'] as String].toSet();
    return Scaffold(
      appBar: topBar(context, '용어사전', '${terms.length}개'),
      body: ListView(
        padding: pad,
        children: [
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(hintText: '용어 검색 (예: PER, 현금)', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in [null, ...cats])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s ?? '전체'),
                    selected: cat == s,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => cat = s),
                  ),
                ),
            ]),
          ),
          if (list.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text('찾는 용어가 없어요.', style: sub(p))),
          for (final (i, t) in list.indexed) ...[
            if (i == 0 || list[i - 1]['category'] != t['category'])
              Padding(
                  padding: const EdgeInsets.fromLTRB(4, 22, 0, 8),
                  child: Text(t['category'], style: sub(p, 13).copyWith(fontWeight: FontWeight.w700))),
            groupRow(
              p,
              i == 0 || list[i - 1]['category'] != t['category'],
              i == list.length - 1 || list[i + 1]['category'] != t['category'],
              () => openTerm(context, t['id']),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: col(2, [
                  Text(t['term'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(t['definition'], maxLines: 1, overflow: TextOverflow.ellipsis, style: sub(p, 13)),
                ]),
              ),
            ),
          ],
          Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(disclaimer, textAlign: TextAlign.center, style: sub(p, 11.5))),
        ],
      ),
    );
  }
}

// ---------- 뉴스 탭: AI가 정리한 회사 뉴스 요약 (news.json, 누르면 회사 노트)
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsState();
}

// 오늘의 시장: 금리·물가·환율 같은 시장 전체 흐름 뉴스 (예전 데이터엔 없음)
List<J> marketNews() => [for (final x in (news['market'] as List?) ?? []) (x as Map).cast<String, dynamic>()];

Future<void> reloadNews() async {
  final raw = await getJson('news.json');
  final n = raw == null ? null : validNews(raw);
  if (n != null) {
    news = n;
    redraw.value++;
  }
}

class _NewsState extends State<NewsPage> {
  bool cal = false; // false = 뉴스, true = 일정
  String? calType; // null = 전체, macro, earnings
  String market = '전체';
  String? kind; // null = 전체, 아니면 good/bad/watch
  String q = '';

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    Color colorOf(String t) => t == 'good' ? p.good : t == 'bad' ? p.warn : p.accent;
    // 뉴스의 회사(티커) → 앱 안의 회사 데이터 (로고·상세 화면용)
    final byTk = <String, J>{for (final c in [...companies, ...kr['companies']]) c['ticker'] as String: c};
    final query = q.trim().toLowerCase();
    final rows = <(String, J?, J)>[]; // (티커, 회사, 뉴스 한 개)
    for (final e in (news['companies'] as Map).entries) {
      final String tk = e.key;
      final co = byTk[tk];
      final m = co != null && isKr(co) ? '한국' : '미국';
      if (market != '전체' && m != market) continue;
      if (query.isNotEmpty && !'${co?['name_ko'] ?? ''} ${co?['name_en'] ?? ''} $tk'.toLowerCase().contains(query)) continue;
      for (final x in e.value as List) {
        if (kind == null || x['type'] == kind) rows.add((tk, co, x as J));
      }
    }
    // 지난 뉴스는 최신순, 아직 오지 않은 일정(미래 날짜)은 그 뒤에 가까운 날부터
    final today = DateTime.now().toIso8601String().substring(0, 10);
    String d(r) => '${r.$3['date'] ?? ''}';
    rows.sort((a, b) {
      final fa = d(a).compareTo(today) > 0, fb = d(b).compareTo(today) > 0;
      if (fa != fb) return fa ? 1 : -1;
      return fa ? d(a).compareTo(d(b)) : d(b).compareTo(d(a));
    });
    final toggle = SegmentedButton<bool>(
      segments: const [ButtonSegment(value: false, label: Text('뉴스')), ButtonSegment(value: true, label: Text('일정'))],
      selected: {cal},
      showSelectedIcon: false,
      onSelectionChanged: (v) => setState(() => cal = v.first),
    );
    if (cal) {
      return Scaffold(
        appBar: topBar(context, '일정', '${calendar['asof']} 기준'),
        body: ListView(padding: pad, children: [
          toggle,
          const SizedBox(height: 16),
          ...calendarList(context, p, calType, (t) => setState(() => calType = t)),
        ]),
      );
    }
    return Scaffold(
      appBar: topBar(context, '뉴스', '${news['asof']} 정리'),
      body: RefreshIndicator(
        onRefresh: reloadNews,
        child: ListView(
          padding: pad,
          children: [
            toggle,
            const SizedBox(height: 16),
            txt("AI(Claude)가 하루 두 번 회사 뉴스를 쉽게 정리해요. 누르면 회사 노트로, '원문 보기'는 언론사 기사로 가요.", sub(p, 13)),
            if (marketNews().isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text('오늘의 시장', style: h(18))),
              for (final (i, x) in marketNews().indexed)
                groupRow(
                  p,
                  i == 0,
                  i == marketNews().length - 1,
                  () {
                    if (x['url'] is String && (x['url'] as String).startsWith('http')) {
                      launchUrl(Uri.parse(x['url']), mode: LaunchMode.externalApplication);
                    }
                  },
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: col(6, [
                      Row(children: [
                        Icon(Icons.public_rounded, size: 18, color: p.accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${x['date'] ?? ''} · ${x['source'] ?? ''}', style: sub(p, 12))),
                      ]),
                      txt(x['title'], const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.45)),
                      rich([
                        TextSpan(text: '왜 움직였나  ', style: TextStyle(fontWeight: FontWeight.w700, color: p.accent)),
                        s(x['impact']),
                      ], const TextStyle(fontSize: 14, height: 1.5)),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '전체', label: Text('전체')),
                ButtonSegment(value: '미국', label: Text('미국')),
                ButtonSegment(value: '한국', label: Text('한국')),
              ],
              selected: {market},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => market = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(hintText: '회사 이름으로 찾기 (예: 엔비디아, 삼성)', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final k in [null, ...newsKinds.keys])
                ChoiceChip(
                  label: Text(k == null ? '전체' : newsKinds[k]!.$1),
                  selected: kind == k,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => kind = k),
                ),
            ]),
            const SizedBox(height: 16),
            if (rows.isEmpty) Text('찾는 뉴스가 없어요.', style: sub(p)),
            for (final (i, (tk, co, x)) in rows.indexed)
              groupRow(
                p,
                i == 0,
                i == rows.length - 1,
                () {
                  if (co != null) Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(co)));
                },
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: col(6, [
                    Row(children: [
                      if (co != null) ...[logo(co, 28), const SizedBox(width: 10)],
                      Expanded(
                          child: Text('${co?['name_ko'] ?? tk} · ${x['date'] ?? ''}',
                              style: sub(p, 12).copyWith(fontWeight: FontWeight.w600))),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: colorOf(x['type']).withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                          child: Text(newsKinds[x['type']]?.$1 ?? '',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorOf(x['type'])))),
                    ]),
                    txt(x['title'], const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.45)),
                    rich([
                      TextSpan(text: '회사에 주는 영향  ', style: TextStyle(fontWeight: FontWeight.w700, color: colorOf(x['type']))),
                      s(x['impact']),
                    ], const TextStyle(fontSize: 14, height: 1.5)),
                    Row(children: [
                      Expanded(child: Text('출처: ${x['source']}', style: sub(p, 11.5))),
                      if (x['url'] is String && (x['url'] as String).startsWith('http'))
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(x['url']), mode: LaunchMode.externalApplication),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 12.5)),
                          child: const Text('원문 보기'),
                        ),
                    ]),
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            txt('AI 요약은 틀릴 수 있어요. 중요한 내용은 원문으로 확인하세요. $disclaimer', sub(p, 11.5)),
          ],
        ),
      ),
    );
  }
}

// ---------- 퀴즈: 뜻을 보고 맞는 용어 고르기
typedef Question = ({J answer, List<J> options, String prompt});

String termName(J t) => (t['term'] as String).replaceAll(RegExp(r'\(.*?\)'), '').trim();

// 뜻 안에 정답 이름이 그대로 들어 있으면 가린다 (예: "PER은 ..." → "○○은 ...")
String maskTerm(String text, J t) {
  var out = text;
  for (final name in {termName(t), t['term'] as String, ...RegExp(r'\((.*?)\)').allMatches(t['term']).map((m) => m[1]!)}) {
    if (name.length >= 2) out = out.replaceAll(name, '○○');
  }
  return out;
}

// n문제: 정답은 서로 다르게, 오답 3개는 같은 분야에서 먼저 고른다
// only: 정답 후보를 이 용어들로만 (복습 퀴즈). 오답 보기는 전체 용어에서.
List<Question> makeQuiz(List all, Random rnd, {String? cat, int n = 10, Set<String>? only}) {
  final pool = [for (final J t in all) if ((cat == null || t['category'] == cat) && (only == null || only.contains(t['id']))) t]..shuffle(rnd);
  return [
    for (final J a in pool.take(n))
      () {
        final same = [for (final J t in all) if (t['id'] != a['id'] && t['category'] == a['category']) t]..shuffle(rnd);
        final other = [for (final J t in all) if (t['id'] != a['id'] && t['category'] != a['category']) t]..shuffle(rnd);
        final opts = [a, ...[...same, ...other].take(3)]..shuffle(rnd);
        return (answer: a, options: opts, prompt: maskTerm(a['definition'], a));
      }()
  ];
}

class QuizPage extends StatefulWidget {
  // only가 있으면 그 용어들로 바로 복습 퀴즈, onAnswer로 맞힘/틀림을 알려준다
  final Set<String>? only;
  final void Function(String termId, bool correct)? onAnswer;
  const QuizPage({super.key, this.only, this.onAnswer});
  @override
  State<QuizPage> createState() => _QuizState();
}

class _QuizState extends State<QuizPage> {
  final rnd = Random();
  String? cat;
  List<Question> qs = [];
  int i = 0, score = 0;
  J? picked;
  final wrong = <J>[];

  @override
  void initState() {
    super.initState();
    if (widget.only != null) {
      qs = makeQuiz(terms, rnd, only: widget.only, n: widget.only!.length);
    }
  }

  void start() => setState(() {
        qs = makeQuiz(terms, rnd, cat: cat, only: widget.only, n: widget.only?.length ?? 10);
        i = score = 0;
        picked = null;
        wrong.clear();
      });

  void pick(J t) {
    if (picked != null) return;
    widget.onAnswer?.call(qs[i].answer['id'], t['id'] == qs[i].answer['id']);
    setState(() {
      picked = t;
      if (t['id'] == qs[i].answer['id']) {
        score++;
      } else {
        wrong.add(qs[i].answer);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final cats = [for (final t in terms) t['category'] as String].toSet();
    final List<Widget> body;
    if (qs.isEmpty) {
      // 시작 화면
      body = [
        txt('뜻을 읽고 맞는 경제용어를 골라 보세요. 한 번에 10문제예요.', sub(p, 14)),
        Text('어떤 분야를 풀까요?', style: h(16)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in [null, ...cats])
            ChoiceChip(label: Text(c ?? '전체'), selected: cat == c, showCheckmark: false, onSelected: (_) => setState(() => cat = c)),
        ]),
        FilledButton(onPressed: start, child: const Padding(padding: EdgeInsets.all(12), child: Text('시작하기', style: bold))),
      ];
    } else if (i >= qs.length) {
      // 결과 화면
      body = [
        box(p, col(8, [
          Text('${qs.length}문제 중 $score개 맞혔어요', style: h(22)),
          txt(score == qs.length ? '완벽해요! 다른 분야도 도전해 보세요.' : score >= qs.length * .7 ? '잘했어요! 틀린 용어만 한 번 더 볼까요?' : '괜찮아요. 틀린 용어를 눌러 다시 읽어 보세요.', sub(p, 14)),
        ])),
        if (wrong.isNotEmpty) ...[
          Text('다시 볼 용어', style: h(16)),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in wrong) chip(p, t['term'], () => openTerm(context, t['id']))]),
        ],
        FilledButton(onPressed: start, child: const Padding(padding: EdgeInsets.all(12), child: Text('다시 풀기', style: bold))),
        OutlinedButton(onPressed: () => setState(() => qs = []), child: const Padding(padding: EdgeInsets.all(12), child: Text('분야 바꾸기'))),
      ];
    } else {
      // 문제 화면
      final q = qs[i];
      final done = picked != null;
      Color? colorOf(J t) => !done ? null : t['id'] == q.answer['id'] ? p.good : t['id'] == picked!['id'] ? p.warn : null;
      body = [
        Row(children: [
          Text('${i + 1} / ${qs.length}', style: h(16)),
          const Spacer(),
          Text('맞힌 문제 $score', style: sub(p, 13)),
        ]),
        LinearProgressIndicator(value: (i + (done ? 1 : 0)) / qs.length, borderRadius: BorderRadius.circular(4)),
        box(p, col(8, [
          Text('다음 설명에 맞는 용어는?', style: sub(p, 13).copyWith(fontWeight: FontWeight.w700)),
          txt(q.prompt, const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.5)),
        ])),
        for (final o in q.options)
          Material(
            color: colorOf(o)?.withValues(alpha: .18) ?? p.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), side: BorderSide(color: colorOf(o) ?? Colors.transparent, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => pick(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(child: Text(o['term'], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
                  if (done && o['id'] == q.answer['id']) Icon(Icons.check_circle_rounded, color: p.good),
                  if (done && o['id'] == picked!['id'] && o['id'] != q.answer['id']) Icon(Icons.cancel_rounded, color: p.warn),
                ]),
              ),
            ),
          ),
        if (done) ...[
          explain(p, col(4, [
            Text(picked!['id'] == q.answer['id'] ? '정답이에요!' : '정답은 "${q.answer['term']}"이에요.',
                style: TextStyle(fontWeight: FontWeight.w800, color: picked!['id'] == q.answer['id'] ? p.good : p.warn)),
            txt('예시: ${q.answer['example']}', const TextStyle(fontSize: 14)),
          ])),
          FilledButton(
            onPressed: () => setState(() {
              i++;
              picked = null;
            }),
            child: Padding(padding: const EdgeInsets.all(12), child: Text(i + 1 < qs.length ? '다음 문제' : '결과 보기', style: bold)),
          ),
        ],
      ];
    }
    return Scaffold(
      appBar: topBar(context, widget.only != null ? '복습 퀴즈' : '용어 퀴즈', widget.only != null ? '' : cat ?? '전체'),
      body: ListView(padding: pad, children: spaced(12, [...body, Text(disclaimer, textAlign: TextAlign.center, style: sub(p, 11.5))])),
    );
  }
}

// ---------- 연결: 공급·협력·경쟁 관계 (assets/links.json, 회사 공시·공식 발표 기준)
const linkKinds = {'supply': '공급', 'partner': '협력', 'compete': '경쟁'};

Color linkColor(P p, String kind) => switch (kind) { 'supply' => p.accent, 'partner' => p.good, _ => p.warn };

// 앱 안 회사면 그 회사 데이터, 아니면 null (links.json의 nodes는 이름·설명만 있음)
J? appCompany(String id) {
  for (final c in [...companies, ...kr['companies']]) {
    if (c['ticker'] == id) return c;
  }
  return null;
}

String nodeName(String id) => appCompany(id)?['name_ko'] ?? links['nodes'][id]?['ko'] ?? id;

// 앱 안 회사 중 연결이 있는 회사, 연결 많은 순
List<String> linkedIds() {
  final n = <String, int>{};
  for (final l in links['links']) {
    for (final x in [l['from'], l['to']]) {
      if (appCompany(x) != null) n[x] = (n[x] ?? 0) + 1;
    }
  }
  return n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
}

// 업종 → 연결 있는 회사 티커 (연결 많은 순 유지)
Map<String, List<String>> linkedBySector() {
  final out = <String, List<String>>{};
  for (final id in linkedIds()) {
    final c = appCompany(id)!;
    (out[(c['group'] ?? c['sector'] ?? '기타') as String] ??= []).add(id);
  }
  return out;
}

List<J> linksOf(String id) => [for (final J l in links['links']) if (l['from'] == id || l['to'] == id) l];

class LinksPage extends StatefulWidget {
  const LinksPage({super.key});
  @override
  State<LinksPage> createState() => _LinksState();
}

class _LinksState extends State<LinksPage> {
  late final ids = linkedIds();
  late final sectors = linkedBySector();
  late String center = ids.first;
  J? picked;
  String q = '';

  void go(String id) => setState(() {
        center = id;
        picked = null;
      });

  Widget pick(String id) =>
      ChoiceChip(label: Text(nodeName(id)), selected: id == center, showCheckmark: false, onSelected: (_) => go(id));

  Widget node(P p, String id, double size, bool on) {
    final c = appCompany(id);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .3 + 3),
            border: Border.all(color: on ? Colors.white : Colors.transparent, width: 2)),
        padding: const EdgeInsets.all(1),
        child: c != null
            ? logo(c, size)
            : Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(size * .3)),
                child: Icon(id.startsWith('UNNAMED') ? Icons.help_outline : Icons.apartment_rounded,
                    color: p.muted, size: size * .5)),
      ),
      const SizedBox(height: 3),
      SizedBox(
          width: 76,
          child: Text(nodeName(id),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
    ]);
  }

  // 가운데 회사, 둘레에 이어진 회사. 선 색 = 연결 종류
  Widget graph(P p, List<J> ls) => LayoutBuilder(builder: (_, box) {
        final w = box.maxWidth, hgt = min(w, 340.0), cx = w / 2, cy = hgt / 2, r = min(cx, cy) - 44;
        Offset at(int k) =>
            Offset(cx + r * cos(-pi / 2 + 2 * pi * k / ls.length), cy + r * sin(-pi / 2 + 2 * pi * k / ls.length));
        return SizedBox(
          height: hgt,
          child: Stack(children: [
            CustomPaint(
                size: Size(w, hgt),
                painter: _Lines([for (final (k, l) in ls.indexed) (at(k), linkColor(p, l['kind']), identical(l, picked))],
                    Offset(cx, cy))),
            Positioned(left: cx - 38, top: cy - 34, child: node(p, center, 48, true)),
            for (final (k, l) in ls.indexed)
              Positioned(
                left: at(k).dx - 38,
                top: at(k).dy - 24,
                child: GestureDetector(
                  onTap: () => setState(() => picked = identical(picked, l) ? null : l),
                  child: node(p, l['from'] == center ? l['to'] : l['from'], 32, identical(l, picked)),
                ),
              ),
          ]),
        );
      });

  Widget card(P p, J l) {
    final String other = l['from'] == center ? l['to'] : l['from'];
    final String kind = l['kind'];
    final color = linkColor(p, kind);
    final String a = nodeName(l['from']), b = nodeName(l['to']);
    return box(
      p,
      col(8, [
        Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
              child: Text(linkKinds[kind]!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(width: 8),
          Expanded(
              child: txt(kind == 'supply' ? '$a → $b · ${l['what']}' : '$a · $b · ${l['what']}',
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        explain(
            p,
            col(6, [
              txt('$a 쪽이 흔들리면 → $b', sub(p, 12.5).copyWith(fontWeight: FontWeight.w700, color: p.accent)),
              txt(l['if_from'], const TextStyle(fontSize: 14, height: 1.5)),
              txt('$b 쪽이 흔들리면 → $a', sub(p, 12.5).copyWith(fontWeight: FontWeight.w700, color: p.accent)),
              txt(l['if_to'], const TextStyle(fontSize: 14, height: 1.5)),
            ])),
        if ((l['share'] ?? '') != '') txt('공시 내용: ${l['share']}', sub(p, 12.5)),
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: () => launchUrl(Uri.parse(l['url']), mode: LaunchMode.externalApplication),
                  child: Text('출처: ${l['source']} ↗', style: sub(p, 12).copyWith(decoration: TextDecoration.underline)))),
          if (appCompany(other) != null && linksOf(other).length > 1)
            TextButton(onPressed: () => go(other), child: Text('${nodeName(other)} 중심으로')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final ls = linksOf(center);
    final c = appCompany(center)!;
    return Scaffold(
      appBar: topBar(context, '기업 연결', '${links['asof']} 기준'),
      body: ListView(padding: pad, children: [
        txt('한 회사가 흔들리면 이어진 회사들도 같이 흔들릴 수 있어요. 회사를 고르고, 둘레의 회사를 눌러 보세요.', sub(p, 13)),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
          decoration: const InputDecoration(hintText: '회사 이름이나 티커로 찾기', prefixIcon: Icon(Icons.search)),
        ),
        const SizedBox(height: 8),
        if (q.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in ids)
              if ('${nodeName(id)} $id ${appCompany(id)?['name_en'] ?? ''}'.toLowerCase().contains(q)) pick(id),
          ])
        else
          // 업종별 묶음: 펼쳐서 회사 고르기
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final e in sectors.entries)
                ExpansionTile(
                  title: Text('${e.key} · ${e.value.length}곳', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  shape: const Border(),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [Wrap(spacing: 6, runSpacing: 6, children: [for (final id in e.value) pick(id)])],
                ),
            ]),
          ),
        const SizedBox(height: 8),
        graph(p, ls),
        Wrap(alignment: WrapAlignment.center, spacing: 14, children: [
          for (final e in linkKinds.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 14, height: 3, color: linkColor(p, e.key)),
              const SizedBox(width: 4),
              Text(e.key == 'supply' ? '공급(물건·서비스를 대 줌)' : e.value, style: sub(p, 12)),
            ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('${c['name_ko']}와 이어진 회사 ${ls.length}곳', style: h(17))),
          TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(c))),
              child: const Text('회사 노트 보기')),
        ]),
        const SizedBox(height: 8),
        ...spaced(10, [
          for (final l in picked == null ? ls : [picked!, ...ls.where((x) => !identical(x, picked))]) card(p, l)
        ]),
        const SizedBox(height: 16),
        txt('${links['note']}으로 정리했어요. 회사가 이름을 밝히지 않은 고객은 "이름 비공개 고객"으로 보여요. $disclaimer', sub(p, 11.5)),
      ]),
    );
  }
}

class _Lines extends CustomPainter {
  _Lines(this.ends, this.center);
  final List<(Offset, Color, bool)> ends;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (e, color, on) in ends) {
      canvas.drawLine(
          center,
          e,
          Paint()
            ..color = color.withValues(alpha: on ? 1 : .55)
            ..strokeWidth = on ? 3.5 : 2);
    }
  }

  @override
  bool shouldRepaint(_Lines old) => true;
}

// ---------- 일정: 경제 지표 발표·실적 발표 (assets/calendar.json, 매일 build_calendar.py가 갱신)
// kind → (짧은 이름, 왜 중요한지 한 줄, 누르면 여는 용어). 'other'는 일정마다 why를 따로 가진다.
const calKinds = <String, (String, String, String?)>{
  'fomc': ('미국 금리', '미국 기준금리를 정하는 날이에요. 금리가 바뀌면 전 세계 주식시장이 크게 움직여요.', 'fed_fomc'),
  'us_cpi': ('미국 물가', '물가가 예상보다 높으면 금리 인하가 늦어질까 봐 시장이 걱정해요.', 'cpi'),
  'us_jobs': ('미국 고용', '일자리가 얼마나 늘었는지 보여줘요. 경기가 튼튼한지 보는 성적표예요.', 'jobs_report'),
  'us_pce': ('미국 물가', '미국 중앙은행(연준)이 금리를 정할 때 가장 중요하게 보는 물가 숫자예요.', 'pce'),
  'us_gdp': ('미국 성장', '미국 경제가 지난 분기에 얼마나 컸는지 보여줘요.', 'gdp'),
  'bok_rate': ('한국 금리', '한국 기준금리를 정하는 날이에요. 대출 이자와 한국 주식에 영향을 줘요.', 'interest_rate'),
  'kr_cpi': ('한국 물가', '한국 물가가 오르면 한국은행이 금리를 내리기 어려워져요.', 'cpi'),
  'other': ('경제 지표', '', null),
  'earnings': ('실적', '회사가 지난 분기 성적표를 내요. 예상과 차이가 크면 주가가 크게 움직여요.', 'earnings_surprise'),
};

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

// '2026-11-17' → '오늘' / '내일' / '어제' / '11월 17일 (화)'
String calDay(String iso, [DateTime? now]) {
  final d = DateTime.parse(iso), n = now ?? DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '내일';
  if (diff == -1) return '어제';
  return '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
}

// 한국 시간으로 언제 보면 되는지
String calTime(J e) {
  final String? kst = e['kst'];
  if (kst != null) return kst.substring(11);
  return switch (e['when']) { 'after' => '아침', 'before' => '밤', _ => '미정' };
}

String calNote(J e) => e['type'] == 'earnings'
    ? switch (e['when']) { 'after' => '미국 장 마감 뒤 발표', 'before' => '미국 장 시작 전 발표', _ => '발표 시각 미정' }
    : (e['why'] as String?) ?? calKinds[e['kind']]?.$2 ?? '';

// 일정 한 줄. 결과가 있으면 결과 요약을 함께 보여준다.
Widget calRow(BuildContext ctx, P p, J e, Map byTk, {bool first = true, bool last = true, Color? bg}) {
  final co = byTk[e['ticker']] as J?;
  final J? r = e['result'] is Map ? (e['result'] as Map).cast<String, dynamic>() : null;
  final row = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 52,
          child: Text(calTime(e), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.muted, fontFeatures: tabular))),
      Expanded(
          child: col(4, [
        Row(children: [
          if (co != null) ...[logo(co, 22), const SizedBox(width: 8)],
          Expanded(child: txt(e['title'], const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35))),
        ]),
        if (r == null)
          txt(calNote(e), sub(p, 13).copyWith(height: 1.45))
        else ...[
          txt(r['summary'], TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.fg, height: 1.45)),
          rich([TextSpan(text: '의미  ', style: TextStyle(fontWeight: FontWeight.w700, color: p.accent)), s(r['impact'])],
              sub(p, 13).copyWith(height: 1.45)),
          Text('출처: ${r['source']}', style: sub(p, 11.5)),
        ],
      ])),
      const SizedBox(width: 8),
      Text(calKinds[e['kind']]?.$1 ?? '',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e['type'] == 'macro' ? p.accent : p.good)),
    ]),
  );
  void open() {
    if (e['type'] == 'earnings' && co != null) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => DetailPage(co)));
    } else if (calKinds[e['kind']]?.$3 case final String term) {
      openTerm(ctx, term);
    }
  }

  if (bg == null) return groupRow(p, first, last, open, row);
  return Material(color: bg, child: InkWell(onTap: open, child: row));
}

List<Widget> calendarList(BuildContext ctx, P p, String? type, void Function(String?) setType) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  // 하루 안에서는 이른 시각부터 (아침 ≈ 06시, 밤 ≈ 22시, 미정은 맨 뒤)
  String order(J e) => e['kst']?.substring(11) ?? switch (e['when']) { 'after' => '06:00', 'before' => '22:00', _ => '99' };
  int byTime(J a, J b) => order(a).compareTo(order(b));
  final all = [for (final J e in calendar['events']) e];
  final todays = all.where((e) => e['date'] == today).toList()..sort(byTime);
  final shown = all.where((e) => type == null || e['type'] == type);
  final days = <String, List<J>>{};
  for (final e in shown.where((e) => e['date'].compareTo(today) > 0)) {
    (days[e['date']] ??= []).add(e);
  }
  for (final l in days.values) {
    l.sort(byTime);
  }
  // 지난 일정 중 결과 요약이 있는 것, 최근 것부터
  final past = (all.where((e) => e['date'].compareTo(today) < 0 && e['result'] is Map).toList()
        ..sort((a, b) => b['date'].compareTo(a['date'])))
      .take(6)
      .toList();
  final next = all.where((e) => e['date'].compareTo(today) > 0).toList()
    ..sort((a, b) => a['date'] == b['date'] ? byTime(a, b) : a['date'].compareTo(b['date']));
  final byTk = {for (final c in companies) c['ticker']: c};

  return [
    // 오늘의 주요 일정: 화면에서 가장 먼저, 파란 바탕 한 겹으로 구분 (필터와 상관없이 오늘 것은 다 보임)
    Container(
      decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: col(0, [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(children: [
            Icon(Icons.today_rounded, size: 20, color: p.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('오늘의 주요 일정', style: h(18))),
            Text(
                '${DateTime.now().month}월 ${DateTime.now().day}일 (${_weekdays[DateTime.now().weekday - 1]})',
                style: sub(p, 12).copyWith(fontFeatures: tabular)),
          ]),
        ),
        if (todays.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: col(4, [
              txt('오늘은 시장을 움직일 큰 발표가 없어요.', const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (next.isNotEmpty) txt('다음 일정: ${calDay(next.first['date'])} ${calTime(next.first)} · ${next.first['title']}', sub(p, 13)),
            ]),
          )
        else
          for (final (i, e) in todays.indexed) ...[
            if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: p.accent.withValues(alpha: .18)),
            calRow(ctx, p, e, byTk, bg: Colors.transparent),
          ],
      ]),
    ),
    Padding(padding: const EdgeInsets.fromLTRB(4, 24, 4, 4), child: Text('지난 일정 결과', style: h(18))),
    txt('발표가 끝난 일정은 AI가 결과와 그 의미를 쉽게 정리해요.', sub(p, 13)),
    const SizedBox(height: 8),
    if (past.isEmpty) txt('아직 정리된 결과가 없어요. 발표가 끝나면 다음 날 아침에 정리해서 보여드려요.', sub(p, 14)),
    for (final (i, e) in past.indexed) ...[
      if (i == 0 || past[i - 1]['date'] != e['date'])
        Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text(calDay(e['date']), style: sub(p, 13).copyWith(fontWeight: FontWeight.w700))),
      calRow(ctx, p, e, byTk,
          first: i == 0 || past[i - 1]['date'] != e['date'], last: i == past.length - 1 || past[i + 1]['date'] != e['date']),
    ],
    Padding(padding: const EdgeInsets.fromLTRB(4, 24, 4, 4), child: Text('앞으로의 일정', style: h(18))),
    txt('시장을 움직이는 경제 지표 발표와 회사 실적 발표예요. 실적 발표 날은 회사가 지난 분기 성적표를 내는 날이라, 예상과 차이가 크면 주가가 크게 움직여요. 시각은 모두 한국 시간이고, 누르면 뜻이나 회사 노트가 열려요.',
        sub(p, 13)),
    const SizedBox(height: 12),
    Wrap(spacing: 6, children: [
      for (final (t, label) in [(null, '전체'), ('macro', '경제 지표'), ('earnings', '실적 발표')])
        ChoiceChip(label: Text(label), selected: type == t, showCheckmark: false, onSelected: (_) => setType(t)),
    ]),
    if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: txt('앞으로 정해진 일정이 아직 없어요. 매일 새로 받아와요.', sub(p, 14))),
    for (final MapEntry(key: day, value: list) in days.entries) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(calDay(day), style: h(16))),
      for (final (i, e) in list.indexed) calRow(ctx, p, e, byTk, first: i == 0, last: i == list.length - 1),
    ],
    const SizedBox(height: 20),
    txt('${calendar['note']} 실적 발표 \'아침\'은 미국 장 마감 뒤, \'밤\'은 미국 장 시작 전이에요. 결과 요약은 AI가 정리해서 틀릴 수 있어요. $disclaimer',
        sub(p, 11.5)),
  ];
}
