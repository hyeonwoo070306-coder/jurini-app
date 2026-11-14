part of 'main.dart';

// ---------- 배우기: 진도 (폰 안에만 저장, 로그인 없음)
class Progress {
  final Set<String> done; // 끝낸 수업 id
  final Set<String> learned; // 배운 용어 id
  final Map<String, int> wrong; // 틀린 용어 id → 틀린 횟수 (맞히면 지움)
  final Set<String> days; // 공부한 날짜 'YYYY-MM-DD'
  Progress(this.done, this.learned, this.wrong, this.days);

  String toJson() => jsonEncode({'done': [...done], 'learned': [...learned], 'wrong': wrong, 'days': [...days]});

  // 비었거나 깨진 저장값이면 처음부터
  static Progress fromJson(String? s) {
    try {
      final j = jsonDecode(s ?? '');
      return Progress({...(j['done'] as List).cast<String>()}, {...(j['learned'] as List).cast<String>()},
          (j['wrong'] as Map).cast<String, int>(), {...(j['days'] as List).cast<String>()});
    } catch (_) {
      return Progress({}, {}, {}, {});
    }
  }
}

const _progressKey = 'progress_v1';

// 진도는 앱 전체에서 한 개만 쓴다. 배우기 탭과 '수업으로 배우기'가 서로 덮어쓰지 않게.
Progress? _progressCache;

@visibleForTesting
void resetProgressCache() => _progressCache = null;

Future<Progress> loadProgress() async =>
    _progressCache ??= Progress.fromJson((await SharedPreferences.getInstance()).getString(_progressKey));

Future<void> saveProgress(Progress p) async {
  _progressCache = p;
  await (await SharedPreferences.getInstance()).setString(_progressKey, p.toJson());
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<J> courseLessons(J course) => [
      for (final st in course['stages'])
        for (final l in st['lessons']) {...(l as Map).cast<String, dynamic>(), 'stage': st['id']}
    ];

// 아직 안 끝낸 첫 수업, 다 끝냈으면 null
J? nextLesson(J course, Progress p) {
  for (final l in courseLessons(course)) {
    if (!p.done.contains(l['id'])) return l;
  }
  return null;
}

// 이번 주(월요일 시작)에 공부한 날 수
int weekDays(Progress p, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return {for (var i = 0; i < 7; i++) dayKey(monday.add(Duration(days: i)))}.intersection(p.days).length;
}

// 복습할 용어 최대 3개: 틀린 용어 먼저, 그다음 배운 용어에서 무작위
List<J> reviewTerms(Progress p, Map<String, dynamic> glossary, Random rnd) {
  final wrong = [for (final id in p.wrong.keys) if (glossary[id] != null) id]..shuffle(rnd);
  final rest = [for (final id in p.learned) if (glossary[id] != null && !p.wrong.containsKey(id)) id]..shuffle(rnd);
  return [for (final id in [...wrong, ...rest].take(3)) (glossary[id] as Map).cast<String, dynamic>()];
}

// 수업을 끝냈을 때: 진도·배운 용어·공부한 날 갱신. 퀴즈에서 틀린 용어는 다음 복습에 다시 나온다.
void finishLesson(Progress p, J lesson, List<String> wrongTermIds, DateTime now) {
  p.done.add(lesson['id']);
  for (final String t in lesson['terms']) {
    p.learned.add(t);
    if (!wrongTermIds.contains(t)) p.wrong.remove(t);
  }
  for (final t in wrongTermIds) {
    p.wrong[t] = (p.wrong[t] ?? 0) + 1;
  }
  p.days.add(dayKey(now));
}

// ---------- 매일 AI 수업 (docs/lesson_today.json, 보관함 docs/lessons_ai.json) — 사실 확인 통과분만
J? aiToday;
List<J> aiArchive = [];

bool validAiLesson(J j) {
  bool strs(dynamic x, int lo, int hi) => x is List && x.length >= lo && x.length <= hi && x.every((e) => e is String);
  final quiz = j['quiz'];
  return j['id'] is String &&
      j['title'] is String &&
      strs(j['terms'], 1, 6) &&
      strs(j['cards'], 4, 5) &&
      quiz is List &&
      quiz.length == 3 &&
      quiz.every((q) => q is Map && q['q'] is String && strs(q['options'], 4, 4) && q['answer'] is int && q['answer'] >= 0 && q['answer'] < 4) &&
      j['stage'] is int &&
      j['stage'] >= 1 &&
      j['stage'] <= 5 &&
      j['verified'] == true &&
      j['sources'] is List &&
      (j['sources'] as List).isNotEmpty;
}

// AI가 추가한 용어를 사전에 합친다. 이미 있는 id는 건드리지 않는다.
void mergeAiGlossary(J g) {
  for (final t in g['terms'] as List) {
    if (t is! Map || G[t['id']] != null) continue;
    if (![t['id'], t['term'], t['definition'], t['example'], t['category']].every((x) => x is String)) continue;
    final J term = {...t.cast<String, dynamic>(), 'ai': true};
    terms.add(term);
    G[term['id']] = term;
  }
}

// 이 용어를 다루는 첫 코스 수업 (없으면 null)
J? lessonForTerm(String termId) {
  for (final l in courseLessons(lessons)) {
    if ((l['terms'] as List).contains(termId)) return l;
  }
  return null;
}

// 뉴스 카드 아래 '이 뉴스 이해하기: [용어]' 칩. 관련 용어가 없는 (예전) 뉴스면 아무것도 안 그림
Widget termChips(BuildContext ctx, P p, Map item) {
  final ts = [for (final t in (item['terms'] as List?) ?? []) if (G[t] != null) t as String];
  if (ts.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
    Text('이 뉴스 이해하기', style: sub(p, 12)),
    for (final t in ts) chip(p, termName(G[t]), () => openTerm(ctx, t)),
  ]);
}

// 용어 팝업의 '수업으로 배우기': 수업을 끝내면 진도에 반영
Future<void> learnFromTerm(BuildContext ctx, J lesson) async {
  String? goal;
  for (final st in lessons['stages']) {
    if (st['id'] == lesson['stage']) goal = st['goal'];
  }
  final List<String>? wrong = await Navigator.push(ctx, MaterialPageRoute(builder: (_) => LessonPage(lesson, goal: goal)));
  if (wrong == null) return;
  final p = await loadProgress();
  finishLesson(p, lesson, wrong, DateTime.now());
  await saveProgress(p);
  redraw.value++;
}

// ---------- 배우기 탭 (앱 첫 화면)
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  @override
  State<LearnPage> createState() => _LearnState();
}

class _LearnState extends State<LearnPage> {
  Progress? prog;

  @override
  void initState() {
    super.initState();
    loadProgress().then((p) {
      if (mounted) setState(() => prog = p);
    });
  }

  Future<void> save() async {
    await saveProgress(prog!);
    if (mounted) setState(() {});
  }

  Future<void> openLesson(J lesson, {bool ai = false}) async {
    String? goal;
    if (!ai) {
      for (final st in lessons['stages']) {
        if (st['id'] == lesson['stage']) goal = st['goal'];
      }
    }
    final List<String>? wrongTerms =
        await Navigator.push(context, MaterialPageRoute(builder: (_) => LessonPage(lesson, ai: ai, goal: goal)));
    if (wrongTerms == null) return;
    finishLesson(prog!, lesson, wrongTerms, DateTime.now());
    await save();
  }

  // 오늘의 뉴스 읽기: 배운 용어와 겹치는 뉴스 → 오늘의 시장 첫 뉴스 → 읽는 법(learn)이 있는 아무 뉴스
  J? newsToRead(Progress p) {
    final all = [
      ...marketNews(),
      for (final l in (news['companies'] as Map).values)
        for (final x in l as List) (x as Map).cast<String, dynamic>()
    ].where((x) => x['learn'] is String).toList();
    if (all.isEmpty) return null;
    for (final x in all) {
      if ((x['terms'] as List? ?? []).any(p.learned.contains)) return x;
    }
    return all.first;
  }

  Widget row(P p, String step, String title, String? note, VoidCallback? onTap, {Key? key}) => InkWell(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: col(3, [
                Text(step, style: sub(p, 12).copyWith(fontWeight: FontWeight.w700, color: p.accent)),
                txt(title, const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.4)),
                if (note != null) txt(note, sub(p, 13).copyWith(height: 1.45)),
              ])),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.muted),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final pr = prog;
    if (pr == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final today = dayKey(DateTime.now());
    final events = [for (final e in calEvents()) if (e['date'] == today) e];
    final market = marketNews();
    final next = nextLesson(lessons, pr);
    final reading = newsToRead(pr);
    final review = reviewTerms(pr, G, Random(today.hashCode));
    final int stage = next?['stage'] ?? 5;
    final stageTitle = [for (final st in lessons['stages']) if (st['id'] == stage) st['title']].first;
    final divider = Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: p.line);

    return Scaffold(
      appBar: topBar(context, '배우기', '하루 10분'),
      body: ListView(padding: pad, children: [
        // 오늘의 시장 한눈에 (팝업 대신. 일정·시장 뉴스가 없으면 칸 자체를 숨김)
        if (events.isNotEmpty || market.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(16)), // 일정 화면의 파란 칸과 모양을 구분
            child: col(10, [
              Row(children: [
                Icon(Icons.wb_sunny_outlined, size: 20, color: p.accent),
                const SizedBox(width: 8),
                Text('오늘의 시장 한눈에', style: h(17)),
              ]),
              for (final e in events.take(2))
                InkWell(
                  onTap: () {
                    if (calKinds[e['kind']]?.$3 case final String term) openTerm(context, term);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Row(children: [
                      SizedBox(
                          width: 52,
                          child: Text(calTime(e), style: sub(p, 13).copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular))),
                      Expanded(child: txt(e['title'], const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              if (market.isNotEmpty) ...[
                txt(market.first['title'], const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.45)),
                if ((market.first['terms'] as List?)?.isNotEmpty ?? false)
                  Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('이 뉴스 이해하기', style: sub(p, 12)),
                    for (final t in market.first['terms'])
                      if (G[t] != null) chip(p, termName(G[t]), () => openTerm(context, t)),
                  ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),
        ],
        // 오늘의 10분
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: col(0, [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('오늘의 10분', style: h(18))),
            if (next != null)
              row(p, '① 오늘의 수업 · 5분', next['title'], '$stage단계 · $stageTitle', () => openLesson(next),
                  key: const ValueKey('today-lesson'))
            else if (aiToday != null)
              row(p, '① 오늘의 수업 · AI 수업', aiToday!['title'], '오늘 뉴스로 만든 수업이에요', () => openLesson(aiToday!, ai: true),
                  key: const ValueKey('today-lesson'))
            else
              row(p, '① 오늘의 수업', '오늘은 복습만 해요', '5단계 코스를 모두 끝냈어요. 새 수업은 매일 AI 수업으로 이어져요.', null,
                  key: const ValueKey('today-lesson')),
            divider,
            if (reading != null)
              row(p, '② 오늘의 뉴스 읽기 · 3분', reading['title'], reading['learn'],
                  (reading['terms'] as List?)?.isNotEmpty ?? false ? () => openTerm(context, reading['terms'][0]) : null)
            else
              row(p, '② 오늘의 뉴스 읽기', '오늘 읽을 뉴스를 준비 중이에요', '인터넷에 연결하면 새 뉴스를 받아요.', null),
            divider,
            if (review.isNotEmpty)
              row(p, '③ 복습 퀴즈 · 2분', '배운 용어 ${review.length}개 다시 풀기', null, () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => QuizPage(
                            only: {for (final t in review) t['id'] as String},
                            onAnswer: (id, ok) {
                              if (ok) {
                                prog!.wrong.remove(id);
                              } else {
                                prog!.wrong[id] = (prog!.wrong[id] ?? 0) + 1;
                              }
                              prog!.days.add(dayKey(DateTime.now()));
                            })));
                await save();
              })
            else
              row(p, '③ 복습 퀴즈', '수업을 하나 끝내면 복습 퀴즈가 생겨요', null, null),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('이번 주 ${weekDays(pr, DateTime.now())}일 공부 · 5단계 중 $stage단계', style: sub(p, 12.5)),
            ),
          ]),
        ),
        // 오늘·내일(한국 시간) 큰 경제 발표가 있으면 추리 퀴즈 한 장
        if (upcomingPredict(calendar['events'], kstNow(), days: 1).firstOrNull case final J e) ...[
          const SizedBox(height: 12),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: row(p, '추리 퀴즈 · 3분', '내일을 추리해 보기', '${calDay(e['date'])} ${calTime(e)} ${e['title']}. 이렇게 나오면 시장은 무엇을 걱정할까요?',
                () => openPredict(context, e),
                key: const ValueKey('predict-card')),
          ),
        ],
        if (aiToday != null && next != null) ...[
          const SizedBox(height: 12),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: row(
                p,
                '보너스 · 오늘의 AI 수업',
                aiToday!['title'],
                aiToday!['stage'] > stage ? '${aiToday!['stage']}단계 내용이에요. 어려우면 나중에 봐도 돼요.' : '오늘 뉴스로 만든 수업이에요.',
                () => openLesson(aiToday!, ai: true)),
          ),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(4, 28, 4, 8), child: Text('5단계 코스', style: h(18))),
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final st in lessons['stages'])
              ExpansionTile(
                shape: const Border(),
                title: Text('${st['id']}단계 · ${st['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${(st['lessons'] as List).where((l) => pr.done.contains(l['id'])).length} / ${(st['lessons'] as List).length} 끝냄',
                    style: sub(p, 12)),
                children: [
                  for (final l in st['lessons'])
                    ListTile(
                      leading: Icon(pr.done.contains(l['id']) ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: pr.done.contains(l['id']) ? p.good : p.muted, size: 20),
                      title: txt(l['title'], const TextStyle(fontSize: 14.5)),
                      onTap: () => openLesson({...(l as Map).cast<String, dynamic>(), 'stage': st['id']}),
                    ),
                ],
              ),
          ]),
        ),
        if (aiArchive.isNotEmpty) ...[
          const SizedBox(height: 12),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              title: const Text('AI 수업 보관함', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              subtitle: Text('최근 ${aiArchive.length}개 · 매일 뉴스로 만든 수업', style: sub(p, 12)),
              children: [
                for (final l in aiArchive.reversed)
                  ListTile(
                    leading: Icon(pr.done.contains(l['id']) ? Icons.check_circle_rounded : Icons.auto_awesome_outlined,
                        color: pr.done.contains(l['id']) ? p.good : p.muted, size: 20),
                    title: txt(l['title'], const TextStyle(fontSize: 14.5)),
                    subtitle: Text('${l['date']} · ${l['stage']}단계', style: sub(p, 12)),
                    onTap: () => openLesson(l, ai: true),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizPage())),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('자유 퀴즈', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),
        txt('진도는 이 폰에만 저장돼요. 앱을 지우면 사라져요. $disclaimer', sub(p, 11.5)),
      ]),
    );
  }
}

// ---------- 수업 화면: 카드 → 퀴즈 3문제 → 결과. 끝내면 틀린 용어 목록을 돌려준다.
class LessonPage extends StatefulWidget {
  final J lesson;
  final bool ai;
  final String? goal;
  final Random? rnd;
  const LessonPage(this.lesson, {super.key, this.ai = false, this.goal, this.rnd});
  @override
  State<LessonPage> createState() => _LessonState();
}

class _LessonState extends State<LessonPage> {
  int step = 0, score = 0;
  int? picked; // 고른 보기의 원래 번호
  // 문제마다 보기 순서를 한 번 섞는다 (정답이 늘 같은 자리에 있지 않게)
  late final List<List<int>> orders = [
    for (final _ in widget.lesson['quiz'] as List) [0, 1, 2, 3]..shuffle(widget.rnd ?? Random())
  ];

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final J l = widget.lesson;
    final List cards = l['cards'], quiz = l['quiz'];
    final total = cards.length + quiz.length;
    Widget button(String label, VoidCallback onTap) => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(label, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16, fontWeight: FontWeight.w700)),
        );
    final List<Widget> body;
    if (step < cards.length) {
      body = [
        box(p, txt(cards[step], const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.6)), pad: const EdgeInsets.all(24)),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('이 수업의 용어', style: sub(p, 12)),
          for (final t in l['terms'])
            if (G[t] != null) chip(p, termName(G[t]), () => openTerm(context, t)),
        ]),
        button('다음', () => setState(() => step++)),
      ];
    } else if (step < total) {
      final J q = (quiz[step - cards.length] as Map).cast<String, dynamic>();
      final last = step == total - 1;
      body = [
        Text('퀴즈 ${step - cards.length + 1} / ${quiz.length}', style: sub(p, 13).copyWith(fontWeight: FontWeight.w700)),
        txt(q['q'], const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.5)),
        for (final (pos, k) in orders[step - cards.length].indexed)
          Material(
            key: ValueKey('option-$pos'),
            color: picked == null
                ? p.surface
                : k == q['answer']
                    ? p.good.withValues(alpha: .18)
                    : k == picked
                        ? p.warn.withValues(alpha: .18)
                        : p.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: picked != null
                  ? null
                  : () => setState(() {
                        picked = k;
                        if (k == q['answer']) score++;
                      }),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52, minWidth: double.infinity),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: txt(q['options'][k], const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        if (picked != null) ...[
          explain(
              p,
              txt('${picked == q['answer'] ? '맞았어요! ' : '정답은 "${q['options'][q['answer']]}"예요. '}${q['explain']}',
                  const TextStyle(fontSize: 14, height: 1.5))),
          button(
              last ? '결과 보기' : '다음 문제',
              () => setState(() {
                    step++;
                    picked = null;
                  })),
        ],
      ];
    } else {
      body = [
        box(
            p,
            col(8, [
              Text('수업 끝!', style: h(24)),
              txt('퀴즈 ${quiz.length}문제 중 $score개 맞혔어요.${score < quiz.length ? ' 틀린 용어는 복습 퀴즈에 다시 나와요.' : ''}', sub(p, 14)),
            ])),
        if (widget.goal != null) explain(p, txt('이 단계를 마치면: ${widget.goal}', const TextStyle(fontSize: 14, height: 1.5))),
        // 퀴즈 하나라도 틀리면 이 수업 용어를 복습 대상으로 (문제마다 용어 표시가 없어서)
        button('수업 끝내기',
            () => Navigator.pop(context, score < quiz.length ? [...(l['terms'] as List).cast<String>()] : <String>[])),
      ];
    }
    return Scaffold(
      appBar: AppBar(title: txt(l['title'], h(18)), centerTitle: false),
      body: ListView(padding: pad, children: [
        LinearProgressIndicator(semanticsLabel: "수업 진행", value: min(step, total) / total, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 16),
        if (widget.ai) ...[
          explain(p, txt('AI가 오늘 뉴스로 만든 수업이에요. 사실 확인을 거쳤지만 틀릴 수 있어요.', sub(p, 12.5))),
          const SizedBox(height: 12),
        ],
        ...spaced(14, body),
        const SizedBox(height: 20),
        Text(disclaimer, textAlign: TextAlign.center, style: sub(p, 11.5)),
      ]),
    );
  }
}
