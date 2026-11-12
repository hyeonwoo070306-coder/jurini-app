import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef J = Map<String, dynamic>;

late J data, sp500, news, kr;
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
  terms = jsonDecode(await rootBundle.loadString('assets/glossary.json'))['terms'];
  G = {for (final t in terms) t['id'] as String: t};
  companies = mergeCompanies(data['companies'], sp500['companies']);
  runApp(const App());
  loadLive();
}

// ---------- 매일 종가 기준 지표 (GitHub Actions가 매일 만드는 docs/valuation.json) ----------
// 깃허브 저장소를 만든 뒤 주소를 넣는다. 비어 있으면 앱에 든 숫자만 쓴다.
const liveBase = 'https://raw.githubusercontent.com/hyeonwoo070306-coder/jurini-app/main/docs/';
final live = ValueNotifier<String?>(null); // 받아온 종가 기준일
final redraw = ValueNotifier(0);

Future<J?> getJson(String file) async {
  try {
    final req = await HttpClient().getUrl(Uri.parse(liveBase + file)).timeout(const Duration(seconds: 8));
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    return jsonDecode(await res.transform(utf8.decoder).join());
  } catch (_) {
    return null; // 인터넷이 없거나 파일이 이상하면 앱에 들어 있는 것을 그대로 쓴다.
  }
}

Future<void> loadLive() async {
  final n = await getJson('news.json');
  if (n != null && n['companies'] is Map) news = n;
  final v = await getJson('valuation.json');
  if (v != null) {
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
    c['market_cap_asof'] = asof;
    c['rank'] = v['rank'];
    c['valuation'] = <String, dynamic>{...c['valuation'], 'per': v['per'], 'forward_per': v['forward_per'], 'pbr': v['pbr'], 'asof': asof};
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
          labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.muted),
          secondaryLabelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.surface),
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
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: p.accent.withValues(alpha: .7), width: 1.5),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accentSoft, p.surface]),
      boxShadow: [BoxShadow(color: p.accent.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: col(14, [
      Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
            child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5))),
        const SizedBox(width: 8),
        Expanded(child: Text('최근 뉴스', style: h(19))),
        Text('${news['asof']} 정리', style: sub(p, 11.5)),
      ]),
      for (final (i, n) in items.indexed) ...[
        if (i > 0) Container(height: 1, color: p.line),
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
      txt('호재·악재는 뉴스 내용을 쉽게 나눈 것이에요. 주가가 어떻게 움직일지는 아무도 몰라요.', sub(p, 11.5)),
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

Widget chip(P p, String label, [VoidCallback? onTap]) => Material(
      color: p.sunken,
      shape: const StadiumBorder(),
      child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(label, style: const TextStyle(fontSize: 13)))),
    );

Color brandColor(J c) {
  final String tk = c['ticker'];
  return brand[c['id']] ?? HSLColor.fromAHSL(1, (tk.codeUnits.fold(0, (a, b) => a * 31 + b) % 360).toDouble(), .35, .4).toColor();
}

const tabular = [FontFeature.tabularFigures()];
const ink = Color(0xFF191F28);

Widget logo(J c, [double size = 44, Color? bg]) {
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

Widget barRow(P p, String label, num? x, num mx, bool latest) => Row(children: [
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
                        child: Text(x == null ? '공시 없음' : '${x < 0 ? '−' : ''}${eok(x.abs())}',
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
  return Container(
    padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
    decoration: BoxDecoration(border: Border(left: BorderSide(color: p.warn, width: 3))),
    child: col(0, [
      txt(head, const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      if (rest.isNotEmpty) txt(rest, const TextStyle(fontSize: 14)),
    ]),
  );
}

// ---------- 용어 바텀시트 ----------
void openTerm(BuildContext ctx, String id) {
  final J? t = G[id];
  if (t == null) return;
  final p = P.of(ctx);
  final names = [
    for (final tk in t['used_by'])
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
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text(t['category'] ?? '경제용어', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.accent)))),
          txt(t['term'], h(20)),
          txt(t['definition'], const TextStyle(fontSize: 15)),
          explain(p, col(2, [Text('예시', style: sub(p, 12)), txt(t['example'], const TextStyle(fontSize: 14))])),
          if (t['market_effect'] != null) ...[
            explain(p, col(2, [Text('시장에 주는 영향', style: sub(p, 12)), txt(t['market_effect'], const TextStyle(fontSize: 14))])),
            txt('일반적인 경향이며, 항상 이렇게 움직이지는 않아요.', sub(p)),
          ],
          if (names.isNotEmpty) txt('이 용어가 나오는 회사: ${names.join(', ')}', sub(p)),
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

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [HomePage(), TermsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '기업'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '용어사전'),
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
    final sectors = {for (final c in companies) c['group']}.whereType<String>().toList()..sort();
    final List src = korea ? kr['companies'] : companies;
    final list = src.where((c) {
      if (sector != null && c['group'] != sector) return false;
      return query.isEmpty || '${c['name_ko']} ${c['name_en']} ${c['ticker']}'.toLowerCase().contains(query);
    }).toList();
    Widget stat(String n, String label) => Expanded(
        child: col(2, [
          Text(n, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: tabular)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]));
    final header = spaced(12, [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B3A7A), Color(0xFF131A33)])),
            child: col(14, [
              Text(
                  korea
                      ? '코스피·코스닥 · ${kr['meta']['asof']} 상장 목록 기준'
                      : 'S&P 500 · 시가총액 ${live.value ?? data['meta']['market_cap_asof']}${live.value == null ? '' : ' 종가'} 기준',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .3)),
              txt(korea ? '한국 상장 기업,\n무슨 일을 할까요?' : '미국 대표 기업,\n무슨 일을 할까요?',
                  const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.6)),
              txt(korea ? '회사를 누르면 업종과 주요 제품을 볼 수 있어요. 자세한 노트와 재무 숫자는 준비 중이에요.' : '회사를 누르면 중학생도 읽을 수 있게 풀어 쓴 기업 노트가 열려요.',
                  const TextStyle(color: Colors.white70, fontSize: 14)),
              Container(height: 1, color: Colors.white12),
              Row(children: [
                stat('${src.length}', '회사'),
                if (korea) ...[
                  stat('${src.where((c) => c['market'] == '코스피').length}', '코스피'),
                  stat('${src.where((c) => c['market'] == '코스닥').length}', '코스닥'),
                ] else ...[
                  stat('${companies.where((c) => isFull(c)).length}', '자세한 노트'),
                  stat('${terms.length}', '경제용어'),
                ],
              ]),
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
          // shortcut: 한국은 업종이 150가지가 넘어 칩으로 못 보여줌. 큰 분류로 묶는 표가 생기면 칩을 붙인다.
          if (!korea)
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
            ])),
            if ((c['one_liner'] ?? '') != '')
              Text(kt(c['one_liner']), maxLines: 2, overflow: TextOverflow.ellipsis, style: sub(p, 13)),
          ])),
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
                      eok(latest['revenue'])),
              ]),
            ]),
          ),
          Padding(
            padding: pad,
            child: col(14, [
          if (!full)
            explain(p, txt(isKr(c)
                ? '이 회사의 자세한 설명과 재무 숫자는 준비 중이에요. 지금은 한국거래소에 등록된 업종·주요제품만 보여드려요. (${c['market']}, ${c['listed']} 상장)'
                : '이 회사의 자세한 설명(투자 포인트, 사업, 리스크)은 준비 중이에요. 지금은 미국 SEC 공시에서 가져온 숫자만 보여드려요.',
                const TextStyle(fontSize: 13.5))),
          if (full) ...[
          if ((news['companies'][c['ticker']] as List?)?.isNotEmpty ?? false) newsCard(p, news['companies'][c['ticker']]),
          pointCard(p, Icons.trending_up_rounded, '투자 포인트', p.good, p.goodSoft, c['invest_points']),
          pointCard(p, Icons.error_outline_rounded, '주의할 점', p.warn, p.warnSoft, c['cautions']),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in tabs.entries)
                InkWell(
                  onTap: () => setState(() => tab = e.key),
                  child: Container(
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
                ),
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
        return [
          h3('실적은 늘고 있나요?'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              for (final e in metrics.entries)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => metric = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: metric == e.key ? p.surface : null, borderRadius: BorderRadius.circular(9)),
                      child: Text(e.value.$1,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: metric == e.key ? p.fg : p.muted)),
                    ),
                  ),
                ),
            ]),
          ),
          rich([term(ctx, tid, label), s(': $help')], sub(p)),
          col(10, [
            for (var i = 0; i < fin.length; i++) barRow(p, period(fin[i]['label']), fin[i][metric], mx, i == fin.length - 1)
          ]),
          grid([
            fact(p, rich([term(ctx, 'operating_margin', '영업이익률')], sub(p, 12)), opt(last['operating_margin_pct'], '%')),
            fact(p, rich([term(ctx, 'capex', '설비투자')], sub(p, 12)), eok(last['capex'])),
            if (b.containsKey('cash')) ...[
              // SEC 기본 카드: 유가증권이 빠진 현금, 장기부채만 있다
              fact(p, Text('현금성 자산', style: sub(p, 12)), eok(b['cash'])),
              fact(p, Text('장기부채', style: sub(p, 12)), eok(b['long_term_debt'])),
            ] else ...[
              fact(p, Text('현금·투자자산', style: sub(p, 12)), eok(b['cash_and_investments'])),
              fact(p, Text('총부채', style: sub(p, 12)), eok(b['total_debt'])),
            ],
          ]),
          if (b['asof'] != null) txt('현금·부채는 ${b['asof']} 기준이에요.', sub(p)),
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
          if (last['revenue'] != null)
            txt('1억 달러는 환율 1,400원 기준 약 1,400억 원이에요. 최근 매출 ${eok(last['revenue'])} ≈ ${won(last['revenue'])}.', sub(p)),
        ];
      case 'value':
        final num? per = v['per'];
        final verdict = per == null
            ? '적자라 PER을 계산할 수 없어요'
            : per < 15
                ? '이익에 비해 싼 편'
                : per <= 28
                    ? '시장 평균 근처'
                    : per <= 45
                        ? '비싼 편'
                        : '아주 비싼 편';
        return [
          h3('지금 주가, 비싼 편일까요?'),
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
