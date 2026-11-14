part of 'main.dart';

// ---------- 도미노: 한 회사가 흔들리면 공시에 나온 관계를 따라 어디까지 번질 수 있는지 (예측 아님)

typedef Hit = ({String id, String via, J link, String effect});

// 시작 회사에서 단계별로 이어진 회사. 한 번 나온 회사는 다시 안 나오고, 영향 글은 흔들린 쪽(via)에 맞춘다.
List<List<Hit>> dominoWaves(String startId, List links, {int maxPerWave = 8, int depth = 2}) {
  final seen = {startId};
  final waves = <List<Hit>>[];
  var front = [startId];
  for (var d = 0; d < depth; d++) {
    final wave = <Hit>[];
    for (final v in front) {
      for (final J l in links) {
        if (wave.length >= maxPerWave) break;
        final String? o = l['from'] == v ? l['to'] : l['to'] == v ? l['from'] : null;
        if (o == null || !seen.add(o)) continue;
        wave.add((id: o, via: v, link: l, effect: l['from'] == v ? l['if_from'] : l['if_to']));
      }
    }
    if (wave.isEmpty) break;
    waves.add(wave);
    front = [for (final h in wave) h.id];
  }
  return waves;
}

// 받침 있으면 '이', 없으면 '가' (영문 이름은 '가')
String iGa(String w) {
  final c = w.codeUnitAt(w.length - 1);
  return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0 ? '이' : '가';
}

String shakeQ(String id) => '${nodeName(id)}${iGa(nodeName(id))} 흔들리면?';

void openDomino(BuildContext ctx, String id) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => DominoPage(id)));

Widget logoOrBadge(P p, String id, double size) {
  final c = appCompany(id);
  return c != null
      ? logo(c, size)
      : Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.sunken, borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(id.startsWith('UNNAMED') ? Icons.help_outline : Icons.apartment_rounded, color: p.muted, size: size * .5));
}

// 로고(없으면 회사 모양 배지) + 이름. 연결 탭과 도미노가 같이 쓴다.
Widget linkNode(P p, String id, double size, bool on, [double labelW = 76]) {
  return Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3 + 3),
          border: Border.all(color: on ? Colors.white : Colors.transparent, width: 2)),
      padding: const EdgeInsets.all(1),
      child: logoOrBadge(p, id, size),
    ),
    const SizedBox(height: 3),
    SizedBox(
        width: labelW,
        child: Text(nodeName(id),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: labelW < 60 ? 10.5 : 11.5, fontWeight: FontWeight.w600))),
  ]);
}

class DominoPage extends StatefulWidget {
  const DominoPage(this.startId, {super.key});
  final String startId;
  @override
  State<DominoPage> createState() => _DominoState();
}

class _DominoState extends State<DominoPage> with SingleTickerProviderStateMixin {
  late String start = widget.startId;
  late List<List<Hit>> waves = dominoWaves(start, links['links']);
  late final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final scroll = ScrollController();
  bool shaken = false;

  @override
  void dispose() {
    anim.dispose();
    scroll.dispose();
    super.dispose();
  }

  void shake() {
    HapticFeedback.lightImpact();
    setState(() => shaken = true);
    if (MediaQuery.of(context).disableAnimations) {
      anim.value = 1;
    } else {
      anim.forward(from: 0);
    }
  }

  void restart(String id) => setState(() {
        start = id;
        waves = dominoWaves(id, links['links']);
        shaken = false;
        anim.value = 0;
        scroll.jumpTo(0); // 새 회사의 그림과 버튼이 바로 보이게
      });

  // 시간표 (0~1): 흔들림 0~.12 → 1단계가 차례로 → 2단계가 차례로. 8개씩이어도 1 안에 끝난다.
  double lit(int d, int i) {
    if (!shaken) return 0;
    final n1 = waves[0].length;
    final s = d == 0 ? .12 + .035 * i : .12 + .035 * (n1 - 1) + .21 + .03 * i;
    return ((anim.value - s) / (d == 0 ? .18 : .16)).clamp(0.0, 1.0);
  }

  Widget graph(P p) => LayoutBuilder(builder: (_, bx) {
        // 폭은 좁고 세로는 넉넉하니 세로로 긴 타원 두 겹: 360dp 폰에서도 이름이 안 겹치게
        final w = bx.maxWidth, rx = min(w / 2 - 38, 170.0), ry = rx * 1.3, hgt = 2 * ry + 64, cx = w / 2, cy = hgt / 2;
        final rs = waves.length > 1 ? [.58, 1.0] : [.8];
        final sizes = [32.0, 26.0];
        final pos = <String, Offset>{start: Offset(cx, cy)};
        for (final (d, wave) in waves.indexed) {
          for (final (i, x) in wave.indexed) {
            final a = -pi / 2 + 2 * pi * (i + d * .5) / wave.length; // 2단계는 반 칸 돌려 1단계와 엇갈리게
            pos[x.id] = Offset(cx + rs[d] * rx * cos(a), cy + rs[d] * ry * sin(a));
          }
        }
        // 이름 칸 폭: 같은 원 위 이웃과 겹치지 않게
        double labelW(int d) => (2 * pi * rs[d] * rx / waves[d].length - 6).clamp(44.0, 76.0);
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) {
            final t = shaken ? anim.value : 0.0;
            final shakeX = t < .12 ? sin(t / .12 * 6 * pi) * 5 * (1 - t / .12) : 0.0;
            return SizedBox(
              height: hgt,
              child: Stack(children: [
                CustomPaint(size: Size(w, hgt), painter: _DominoLines([
                  for (final (d, wave) in waves.indexed)
                    for (final (i, x) in wave.indexed)
                      (pos[x.via]!, pos[x.id]!, linkColor(p, x.link['kind']), d == 0 ? 1.0 : .55, lit(d, i),
                          x.link['kind'] == 'compete'),
                ])),
                Positioned(
                    left: cx - 30 + shakeX,
                    top: cy - 30,
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(21), border: Border.all(color: Colors.white, width: 2)),
                        padding: const EdgeInsets.all(1),
                        child: logoOrBadge(p, start, 54))),
                for (final (d, wave) in waves.indexed)
                  for (final (i, x) in wave.indexed)
                    Positioned(
                      left: pos[x.id]!.dx - labelW(d) / 2,
                      top: pos[x.id]!.dy - sizes[d] / 2 - 3,
                      child: Opacity(
                        opacity: .25 + ((lit(d, i) - .5) / .5).clamp(0.0, 1.0) * (d == 0 ? .75 : .45),
                        child: linkNode(p, x.id, sizes[d], false, labelW(d)),
                      ),
                    ),
              ]),
            );
          },
        );
      });

  Widget row(P p, Hit x, int d, bool first, bool last) {
    final String kind = x.link['kind'];
    final color = linkColor(p, kind);
    return groupRow(
      p,
      first,
      last,
      () => restart(x.id),
      Padding(
        key: ValueKey('row-${x.id}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(children: [
          Expanded(
            child: col(5, [
              Row(children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)),
                    child: Text(kind == 'compete' ? '경쟁 관계' : linkKinds[kind]!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
                const SizedBox(width: 8),
                Expanded(
                    child: txt('${nodeName(x.via)}${iGa(nodeName(x.via))} 흔들리면 → ${nodeName(x.id)}',
                        const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              ]),
              txt(x.effect, TextStyle(fontSize: 14, height: 1.5, color: d == 0 ? null : p.fg.withValues(alpha: .85))),
              txt('${x.link['what']} · 출처: ${x.link['source']}', sub(p, 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.muted, semanticLabel: '${nodeName(x.id)}에서 다시 시작'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return Scaffold(
      appBar: topBar(context, '도미노', '${links['asof']} 기준'),
      body: ListView(controller: scroll, padding: pad, children: [
        Text(kt(shakeQ(start)), style: h(22)),
        const SizedBox(height: 6),
        txt('공시에 나온 관계를 따라 영향이 번질 수 있는 길을 보여 줘요. 앞으로 일어날 일을 맞히는 예측이 아니에요.', sub(p, 13)),
        const SizedBox(height: 8),
        // 그림과 같은 내용이 아래 목록에 글로 있다
        ExcludeSemantics(child: graph(p)),
        Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 4, children: [
          for (final e in linkKinds.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(
                  size: const Size(18, 3),
                  painter: _DominoLines([(const Offset(0, 1.5), const Offset(18, 1.5), linkColor(p, e.key), 1, 1, e.key == 'compete')])),
              const SizedBox(width: 4),
              Text(e.key == 'compete' ? '경쟁(점선, 서로 다투는 사이)' : e.value, style: sub(p, 12)),
            ]),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: p.accent, foregroundColor: ink),
          onPressed: waves.isEmpty ? null : shake,
          icon: const Icon(Icons.vibration_rounded),
          label: Text(shaken ? '다시 흔들기' : '흔들어 보기', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 24),
        if (waves.isEmpty) txt('공시에 나온 연결이 아직 없어요.', sub(p, 13)),
        for (final (d, wave) in waves.indexed) ...[
          txt('${d + 1}단계 · ${d == 0 ? '바로 이어진 회사' : '한 다리 건너 이어진 회사 (영향이 더 약할 수 있어요)'}', h(16)),
          const SizedBox(height: 8),
          for (final (i, x) in wave.indexed) row(p, x, d, i == 0, i == wave.length - 1),
          const SizedBox(height: 20),
        ],
        txt('줄을 누르면 그 회사에서 다시 시작해요.', sub(p, 12)),
        const SizedBox(height: 8),
        txt('회사 공시·공식 발표 기준이에요. 실제로 꼭 이렇게 된다는 뜻은 아니에요. $disclaimer', sub(p, 11.5)),
      ]),
    );
  }
}

// (시작점, 끝점, 색, 진하기, 그린 정도 0~1, 점선?) — 옅은 바탕선 위에 불 켜진 만큼 진하게, 도착하면 퍼지는 고리
class _DominoLines extends CustomPainter {
  _DominoLines(this.segs);
  final List<(Offset, Offset, Color, double, double, bool)> segs;

  void line(Canvas c, Offset a, Offset b, Paint pt, bool dashed) {
    if (!dashed) return c.drawLine(a, b, pt);
    final len = (b - a).distance, dir = (b - a) / max(len, 1);
    for (var s = 0.0; s < len; s += 9) {
      c.drawLine(a + dir * s, a + dir * min(s + 5, len), pt);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, b, color, alpha, k, dashed) in segs) {
      line(canvas, a, b, Paint()..color = color.withValues(alpha: .14)..strokeWidth = 2, dashed);
      if (k <= 0) continue;
      // 앞 60%는 선이 뻗고, 나머지 40%는 도착한 회사에서 고리가 퍼진다
      line(canvas, a, Offset.lerp(a, b, min(k / .6, 1))!, Paint()..color = color.withValues(alpha: alpha)..strokeWidth = 2.5, dashed);
      if (k > .6 && k < 1) {
        final q = (k - .6) / .4;
        canvas.drawCircle(
            b,
            14 + 18 * q,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: alpha * .6 * (1 - q)));
      }
    }
  }

  @override
  bool shouldRepaint(_DominoLines old) => true;
}
