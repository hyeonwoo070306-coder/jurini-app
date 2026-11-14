part of 'main.dart';

// ---------- 내일을 추리해 보기: 큰 경제 발표 전 "이렇게 나오면 → 시장은 무엇을 걱정할까?" (assets/predict.json)
// 주가·종목·방향이 아니라 원인→결과 흐름만 다룬다. 결과 비교는 calendar_results.json의 vs (above/inline/below, hike/hold/cut).
J predictData = {}; // 비어 있으면 추리 입구가 안 보인다 (main()에서 채움)

// 한국 시간 '지금' (폰 시간대와 상관없이). 날짜·시각 글자만 쓴다.
DateTime kstNow() => DateTime.now().toUtc().add(const Duration(hours: 9));

J? predictKind(J e) => e['type'] == 'macro' && predictData['kinds']?[e['kind']] is Map
    ? (predictData['kinds'][e['kind']] as Map).cast<String, dynamic>()
    : null;

String predictId(J e) => e['id'] ?? '${e['date']}:${e['kind']}';

// 오늘부터 days일 뒤까지(한국 시간)의 추리할 수 있는 경제 일정, 가까운 것부터. 오늘 이미 지난 시각은 뺀다.
List<J> upcomingPredict(List events, DateTime nowKst, {int days = 7}) {
  final today = dayKey(nowKst), last = dayKey(nowKst.add(Duration(days: days)));
  final hm = '$today ${nowKst.hour.toString().padLeft(2, '0')}:${nowKst.minute.toString().padLeft(2, '0')}';
  return [
    for (final e in events)
      if (e is Map &&
          predictKind(e.cast<String, dynamic>()) != null &&
          '${e['date']}'.compareTo(today) >= 0 &&
          '${e['date']}'.compareTo(last) <= 0 &&
          (e['kst'] == null || '${e['kst']}'.compareTo(hm) > 0))
        e.cast<String, dynamic>()
  ]..sort((a, b) => '${a['date']} ${a['kst'] ?? '99'}'.compareTo('${b['date']} ${b['kst'] ?? '99'}'));
}

// 내 추리가 실제와 같은지. 어느 한쪽이 없으면 null (비교하지 않음)
bool? predictVerdict(String? guess, String? vs) => guess == null || vs == null ? null : guess == vs;

bool validPredict(J j) {
  final kinds = j['kinds'];
  if (kinds is! Map || kinds.isEmpty) return false;
  for (final k in kinds.values) {
    if (k is! Map || k['guess'] is! List || (k['guess'] as List).length != 3 || k['chains'] is! Map || k['quiz'] is! Map) return false;
    final Map chains = k['chains'];
    for (final g in k['guess']) {
      if (g is! Map || g['label'] is! String || chains[g['v']] is! List) return false;
      final List steps = chains[g['v']];
      if (steps.length < 2 || steps.length > 4) return false;
      for (final s in steps) {
        if (s is! Map || s['t'] is! String || (s['t'] as String).isEmpty || (s['t'] as String).length > 40) return false;
        if (s['term'] != null && G[s['term']] == null) return false;
      }
    }
    final Map q = k['quiz'];
    final List? qc = chains[q['case']];
    if (qc == null || chains[k['show']] == null || k['show'] == q['case'] || q['why'] is! String) return false;
    if (q['blank'] is! int || q['blank'] < 1 || q['blank'] >= qc.length) return false; // 첫 칸(발표 결과)은 빈칸이 아님
    final opts = q['options'];
    if (opts is! List || opts.length != 3 || !opts.every((o) => o is String)) return false;
    if (q['answer'] is! int || q['answer'] < 0 || q['answer'] > 2 || opts[q['answer']] != qc[q['blank']]['t']) return false;
  }
  return true;
}

// ---------- 내 추리 저장 (폰 안, 이벤트 id → 고른 값)
const _predictKey = 'predict_v1';
Map<String, String>? _guessCache;

@visibleForTesting
void resetGuessCache() => _guessCache = null;

Future<Map<String, String>> loadGuesses() async {
  if (_guessCache != null) return _guessCache!;
  try {
    _guessCache = (jsonDecode((await SharedPreferences.getInstance()).getString(_predictKey) ?? '{}') as Map).cast<String, String>();
  } catch (_) {
    _guessCache = {}; // 깨진 저장값이면 처음부터
  }
  return _guessCache!;
}

Future<void> saveGuess(String id, String v) async {
  final g = await loadGuesses();
  g[id] = v;
  await (await SharedPreferences.getInstance()).setString(_predictKey, jsonEncode(g));
  redraw.value++;
}

void openPredict(BuildContext ctx, J e) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => PredictPage(e)));

// 일정 화면의 입구: 7일 안의 경제 일정 → '추리해 보기', 결과가 나온 지난 일정에 내 추리가 있으면 → '내 추리 확인'
Widget predictEntry(BuildContext ctx, P p, J e) {
  if (predictKind(e) == null) return const SizedBox.shrink();
  final upcoming = upcomingPredict([e], kstNow()).isNotEmpty;
  if (!upcoming && e['result'] is! Map) return const SizedBox.shrink();
  return FutureBuilder(
    future: loadGuesses(),
    initialData: _guessCache,
    builder: (_, snap) {
      final mine = snap.data?[predictId(e)];
      if (!upcoming && mine == null) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openPredict(ctx, e),
          style: TextButton.styleFrom(
              minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 4), foregroundColor: p.accent),
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: Text(upcoming ? (mine == null ? '추리해 보기' : '내 추리 다시 보기') : '내 추리 확인',
              style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );
    },
  );
}

// ---------- 원인→결과 사슬: 카드 + 화살표. 위에서부터 한 칸씩 나타난다 (애니메이션 줄이기면 바로 표시)
class ChainFlow extends StatefulWidget {
  final List steps;
  final int? blank; // 빈칸으로 둘 칸 (퀴즈)
  final bool filled; // 빈칸을 맞힌 뒤 채워 보여줌
  final bool animate;
  const ChainFlow(this.steps, {super.key, this.blank, this.filled = false, this.animate = true});
  @override
  State<ChainFlow> createState() => _ChainFlowState();
}

class _ChainFlowState extends State<ChainFlow> with SingleTickerProviderStateMixin {
  late final AnimationController ctl =
      AnimationController(vsync: this, duration: Duration(milliseconds: 380 * widget.steps.length + 120));

  void play() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      ctl.value = 1;
    } else {
      ctl.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ctl.value == 0 && !ctl.isAnimating) play();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  // i번째 칸이 나타나는 구간 (앞 칸이 자리 잡은 뒤 다음 칸)
  Animation<double> part(int i) {
    final n = widget.steps.length;
    return CurvedAnimation(parent: ctl, curve: Interval(i / (n + .3), (i + 1.3) / (n + .3), curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final n = widget.steps.length;
    Widget appear(int i, Widget child) {
      final a = part(i);
      return FadeTransition(
          opacity: a,
          child: SlideTransition(position: a.drive(Tween(begin: const Offset(0, .18), end: Offset.zero)), child: child));
    }

    Widget step(int i) {
      final J s = (widget.steps[i] as Map).cast<String, dynamic>();
      final isBlank = widget.blank == i && !widget.filled;
      final justFilled = widget.blank == i && widget.filled;
      final String? termId = G[s['term']] != null ? s['term'] : null;
      final Color bg = i == 0 ? p.accentSoft : isBlank ? p.sunken : justFilled ? p.goodSoft : p.surface;
      final content = Row(children: [
        Expanded(
          child: isBlank
              ? Text('?  빈칸에 들어갈 말은?', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.muted))
              : txt(s['t'], TextStyle(fontSize: i == 0 ? 16.5 : 15.5, fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600, height: 1.45)),
        ),
        if (termId != null && !isBlank) ...[
          const SizedBox(width: 8),
          Text(termName(G[termId]), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == 0 ? p.accent : p.muted)),
          Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
        ],
      ]);
      return Semantics(
        label: isBlank ? '빈칸' : null,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: termId == null || isBlank ? null : () => openTerm(context, termId),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: content),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < n; i++) ...[
        if (i > 0)
          appear(
              i,
              SizedBox(
                  height: 30,
                  child: Center(child: Icon(Icons.arrow_downward_rounded, size: 20, color: p.accent, semanticLabel: '그러면')))),
        appear(i, step(i)),
      ],
    ]);
  }
}

// ---------- 추리 화면
class PredictPage extends StatefulWidget {
  final J event;
  const PredictPage(this.event, {super.key});
  @override
  State<PredictPage> createState() => _PredictState();
}

class _PredictState extends State<PredictPage> {
  int? picked; // 빈칸 퀴즈에서 고른 보기
  String? guess;
  int replay = 0;

  @override
  void initState() {
    super.initState();
    loadGuesses().then((g) {
      if (mounted) setState(() => guess = g[predictId(widget.event)]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final e = widget.event;
    final k = predictKind(e)!;
    final Map chains = k['chains'];
    final List guesses = k['guess'];
    String labelOf(String? v) => [for (final g in guesses) if (g['v'] == v) g['label'] as String].firstOrNull ?? '';
    final J q = (k['quiz'] as Map).cast<String, dynamic>();
    final J? r = e['result'] is Map ? (e['result'] as Map).cast<String, dynamic>() : null;
    final String? vs = chains[r?['vs']] != null ? r!['vs'] : null;
    final verdict = predictVerdict(guess, vs);
    const strong = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.45);

    Widget option(String label, bool selected, Color? tint, VoidCallback? onTap, {Key? key}) => Material(
          key: key,
          color: selected ? p.fg : tint ?? p.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: double.infinity),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: txt(label, TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: selected ? p.surface : p.fg)),
              ),
            ),
          ),
        );

    final quizChain = [
      for (final (i, s) in (chains[q['case']] as List).indexed)
        i == q['blank'] && picked != null ? {...s, 't': q['options'][q['answer']]} : s
    ];

    return Scaffold(
      appBar: AppBar(title: Text('내일을 추리해 보기', style: h(18)), centerTitle: false),
      body: ListView(padding: pad, children: [
        // ① 일정
        txt(e['title'], h(22)),
        const SizedBox(height: 6),
        Text('${calDay(e['date'])} ${calTime(e)} · 한국 시간', style: sub(p, 13.5).copyWith(fontFeatures: tabular)),
        const SizedBox(height: 8),
        txt(calNote(e), sub(p, 14).copyWith(height: 1.5)),

        // ② 흐름
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: txt('만약 "${labelOf(k['show'])}" 나오면?', h(18))),
          IconButton(
            tooltip: '흐름 다시 보기',
            onPressed: () => setState(() => replay++),
            icon: Icon(Icons.replay_rounded, color: p.muted),
          ),
        ]),
        txt('발표 하나가 어떻게 이어지는지 차례로 따라가 봐요. 칸을 누르면 용어 뜻이 나와요.', sub(p, 13)),
        const SizedBox(height: 12),
        ChainFlow(chains[k['show']], key: ValueKey('show-$replay')),

        // ③ 빈칸 퀴즈: 반대로 나오면?
        const SizedBox(height: 32),
        txt('반대로 "${labelOf(q['case'])}" 나오면?', h(18)),
        txt('흐름의 빈칸에 들어갈 말을 골라 보세요.', sub(p, 13)),
        const SizedBox(height: 12),
        ChainFlow(quizChain, blank: q['blank'], filled: picked != null, animate: false),
        const SizedBox(height: 14),
        for (final (i, o) in (q['options'] as List).indexed) ...[
          option(
              o,
              false,
              picked == null ? null : i == q['answer'] ? p.goodSoft : i == picked ? p.warnSoft : null,
              picked != null ? null : () => setState(() => picked = i),
              key: ValueKey('quiz-$i')),
          const SizedBox(height: 8),
        ],
        if (picked != null)
          explain(p, txt('${picked == q['answer'] ? '맞았어요! ' : '아쉬워요. '}${q['why']}', const TextStyle(fontSize: 14, height: 1.5))),

        // ④ 내 추리 (결과가 나오기 전까지만 고를 수 있음)
        const SizedBox(height: 32),
        Text('내 추리', style: h(18)),
        if (r == null) ...[
          txt('발표가 어떻게 나올 것 같나요? 정답은 없어요. 골라 두면 발표 뒤에 결과와 비교해 드려요.', sub(p, 13)),
          const SizedBox(height: 12),
          for (final g in guesses) ...[
            option(g['label'], guess == g['v'], null, () {
              setState(() => guess = g['v']);
              saveGuess(predictId(e), g['v']);
            }),
            const SizedBox(height: 8),
          ],
          if (guess != null) txt('"${labelOf(guess)}"로 저장했어요. 발표 뒤에 다시 와 보세요.', sub(p, 13).copyWith(color: p.good)),
        ] else
          txt(guess == null ? '이번 발표는 추리하지 않았어요.' : '발표 전에 "${labelOf(guess)}"를 골랐어요.', sub(p, 14)),

        // ⑤ 결과 비교
        if (r != null) ...[
          const SizedBox(height: 32),
          Text('내 추리 vs 실제', style: h(18)),
          const SizedBox(height: 12),
          box(
              p,
              col(10, [
                if (vs != null)
                  Row(children: [
                    Expanded(child: col(2, [Text('내 추리', style: sub(p, 12)), txt(guess == null ? '-' : labelOf(guess), strong)])),
                    Expanded(child: col(2, [Text('실제', style: sub(p, 12)), txt(labelOf(vs), strong.copyWith(color: p.accent))])),
                  ]),
                if (verdict == true) txt('추리가 맞았어요! 흐름을 잘 읽었어요.', TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.good)),
                txt(r['summary'], const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.5)),
                rich([TextSpan(text: '의미  ', style: TextStyle(fontWeight: FontWeight.w700, color: p.accent)), s(r['impact'])],
                    sub(p, 13.5).copyWith(height: 1.5)),
                Text('출처: ${r['source']}', style: sub(p, 11.5)),
              ])),
          if (vs != null && verdict != true) ...[
            const SizedBox(height: 16),
            txt(verdict == false ? '결과가 이렇게 나왔으니 흐름은 이렇게 돼요.' : '결과가 이렇게 나왔으니 흐름은 이렇게 될 수 있어요.', strong),
            const SizedBox(height: 12),
            ChainFlow(chains[vs]),
          ],
        ],
        const SizedBox(height: 28),
        txt('${predictData['note'] ?? ''} 주가를 맞히는 게임이 아니라 흐름을 익히는 연습이에요. $disclaimer', sub(p, 11.5)),
      ]),
    );
  }
}
