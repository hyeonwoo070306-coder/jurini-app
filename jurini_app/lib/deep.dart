part of 'main.dart';

// ---------- 기업 깊이 노트 (assets/deep.json, 형식은 deep_research/SCHEMA.md) ----------
J deep = {'companies': {}};

// 형식이 이상한 노트는 없는 셈 친다 (앱이 죽지 않게)
J? deepOf(J c) {
  final all = deep['companies'];
  final n = all is Map ? all[c['ticker']] : null;
  return n is J && n['summary'] is String && n['tech'] is List ? n : null;
}

// 기업 목록에서 이름 옆에 붙는 작은 표시
InlineSpan deepBadge(P p) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(6)),
        child: Text('깊이 노트', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.accent))));

List<J> _maps(Object? xs) => [for (final x in xs is List ? xs : const []) if (x is J) x];
String _s(Object? x) => x is String ? x : '';

// 읽기용 글자: 본문은 크고 줄 간격 넉넉하게, 작은 이름표는 굵고 흐리게
const _prose = TextStyle(fontSize: 15.5, height: 1.65);
TextStyle _label(P p) => TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.muted, height: 1.4);

// 큰 제목: 위는 넓게(앞 칸과 떨어지게), 아래는 좁게
Widget deepHeading(P p, String title, [String? lead]) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: col(6, [txt(title, h(20)), if (lead != null) txt(lead, sub(p, 13.5).copyWith(height: 1.5))]));

Widget _rows(P p, List<Widget> xs) => box(
    p,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < xs.length; i++) ...[
        if (i > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: p.line)),
        xs[i],
      ]
    ]));

Widget _claims(P p, IconData icon, String title, Color color, Color soft, List<J> xs) => box(
    p,
    col(16, [
      Row(children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 10),
        Text(title, style: h(17)),
      ]),
      for (final x in xs)
        col(4, [
          txt(_s(x['point']), const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.5)),
          txt(_s(x['evidence']), sub(p, 14).copyWith(height: 1.6)),
        ]),
    ]));

// 회사 소개 바로 아래에 들어가는 깊이 노트 본문
List<Widget> deepNote(BuildContext ctx, P p, J n) {
  final tech = _maps(n['tech']), rivals = _maps(n['rivals']), bull = _maps(n['bull']), bear = _maps(n['bear']);
  final J v = n['vision'] is J ? n['vision'] : {};
  final ms = _maps(v['milestones']);
  final watch = [for (final x in n['watch'] is List ? n['watch'] : const []) if (x is String) x];
  return [
    box(p, col(10, [Text('한눈에 보기', style: _label(p)), txt(n['summary'], _prose)])),
    if (tech.isNotEmpty) ...[
      deepHeading(p, '핵심 기술', '이 회사를 이 회사로 만드는 기술이에요. 눌러서 자세히 읽어 보세요.'),
      col(8, [for (var i = 0; i < tech.length; i++) _TechCard(tech[i], i == 0)]),
    ],
    if (_s(v['goal']) != '' || ms.isNotEmpty) ...[
      deepHeading(p, '어디로 가려고 할까요?'),
      box(
          p,
          col(14, [
            if (_s(v['goal']) != '') col(6, [Text('회사가 밝힌 목표', style: _label(p)), txt(v['goal'], _prose)]),
            if (ms.isNotEmpty && _s(v['goal']) != '') Divider(height: 1, color: p.line),
            for (final m in ms) _milestone(p, m),
          ])),
    ],
    if (rivals.isNotEmpty) ...[
      deepHeading(p, '경쟁사와 비교하면'),
      _rows(p, [
        for (final r in rivals) col(4, [txt(_s(r['name']), h(16)), txt(_s(r['diff']), sub(p, 14.5).copyWith(color: p.fg, height: 1.6))])
      ]),
    ],
    if (bull.isNotEmpty || bear.isNotEmpty) deepHeading(p, '좋은 점과 걱정되는 점', '숫자와 사실로 된 근거를 같이 보세요.'),
    if (bull.isNotEmpty) _claims(p, Icons.trending_up_rounded, '투자 포인트', p.good, p.goodSoft, bull),
    if (bear.isNotEmpty) _claims(p, Icons.error_outline_rounded, '걱정거리', p.warn, p.warnSoft, bear),
    if (watch.isNotEmpty) ...[
      deepHeading(p, '앞으로 확인할 것'),
      box(p, timeline(p, watch)),
    ],
  ];
}

Widget _milestone(P p, J m) {
  final done = m['status'] == 'done';
  return MergeSemantics(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
        padding: const EdgeInsets.only(top: 2, right: 10),
        child: Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 18, color: done ? p.good : p.muted)),
    SizedBox(
        width: 92,
        child: Text(_s(m['when']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.5, fontFeatures: tabular))),
    Expanded(
        child: col(2, [
      txt(_s(m['what']), const TextStyle(fontSize: 14.5, height: 1.5)),
      Text(done ? '이뤘어요' : '계획이에요', style: sub(p, 12).copyWith(color: done ? p.good : p.muted)),
    ])),
  ]));
}

// 출처와 'AI가 정리' 안내 (상세 화면 아래쪽)
Widget deepSources(BuildContext ctx, P p, J n) {
  final src = [for (final x in _maps(n['sources'])) if (_s(x['url']).startsWith('http')) x];
  return col(12, [
    deepHeading(p, '깊이 노트 출처'),
    if (src.isNotEmpty)
      Column(children: [
        for (var i = 0; i < src.length; i++)
          groupRow(
              p,
              i == 0,
              i == src.length - 1,
              () => launchUrl(Uri.parse(src[i]['url']), mode: LaunchMode.externalApplication),
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: txt(_s(src[i]['title']), const TextStyle(fontSize: 14, height: 1.4))),
                  const SizedBox(width: 10),
                  Icon(Icons.open_in_new_rounded, size: 18, color: p.muted, semanticLabel: '출처 열기'),
                ]),
              )),
      ]),
    txt('AI가 공시를 바탕으로 정리했어요. 틀릴 수 있어요.${_s(n['asof']) == '' ? '' : ' (${n['asof']} 기준)'} $disclaimer',
        sub(p, 12).copyWith(height: 1.5)),
  ]);
}

// 핵심 기술 카드: 접으면 이름 + 두 줄 맛보기, 펼치면 무엇/왜/경쟁사와 다른 점
class _TechCard extends StatefulWidget {
  final J t;
  final bool open;
  const _TechCard(this.t, this.open);
  @override
  State<_TechCard> createState() => _TechCardState();
}

class _TechCardState extends State<_TechCard> {
  late bool open = widget.open;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context), t = widget.t;
    Widget part(String label, Object? body) => col(4, [Text(label, style: _label(p)), txt(_s(body), _prose)]);
    return Semantics(
      button: true,
      expanded: open,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
            child: col(10, [
              Row(children: [
                Expanded(child: txt(_s(t['name']), h(17))),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: p.muted),
              ]),
              AnimatedSize(
                duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: open
                    ? col(16, [part('무엇인가요', t['what']), part('왜 중요한가요', t['why']), part('경쟁사와 다른 점', t['edge'])])
                    : Text(kt(_s(t['what'])), maxLines: 2, overflow: TextOverflow.ellipsis, style: sub(p, 14).copyWith(height: 1.55)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
