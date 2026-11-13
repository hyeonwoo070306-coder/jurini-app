"""주린이 기업 노트 로고 키트 원본 만들기 (시안 C '새싹 노트')

심볼(노트 여백선이 새싹으로 자람) + 글자(Pretendard ExtraBold를 윤곽선으로 바꿈) → brand/ 아래 SVG.
변형(흑백·앱 아이콘·PNG)은 로고 디자인 스킬의 export_variants.py로 만든다 (README 참고).
실행: python brand/make_brand.py   (fonttools 필요)
"""
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "jurini_app", "assets", "fonts", "Pretendard-ExtraBold.otf")
NAME = "주린이 기업 노트"

# 색: 어두운 바탕용 / 밝은 바탕용
INK_DARK, LEAF_DARK = "#F2F4F6", "#7C9CFF"
INK_LIGHT, LEAF_LIGHT = "#121831", "#4F6BFF"
TILE = "#121831"

# 심볼 도형 (256×256, 시안 C 최종). 잎만 따로 칠한다.
LINES = ('<rect x="66" y="99" width="20" height="132" rx="10"/><rect x="110" y="131" width="96" height="20" rx="10"/>'
         '<rect x="110" y="171" width="96" height="20" rx="10"/><rect x="110" y="211" width="60" height="20" rx="10"/>')
LEAF = '<path d="M76 109C76 65 104 39 154 37C154 85 124 111 76 109Z"/>'


def symbol(ink, leaf, extra=""):
    return f'<g fill="{ink}">{LINES}</g><g fill="{leaf}">{LEAF}</g>{extra}'


def svg(w, h, body, title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}"><title>{title}</title>{body}</svg>\n'


def wordmark(height):
    """글자를 윤곽선 path로. (path d, 너비) 반환. 높이 = 대문자 높이 기준 em 비율로 맞춤."""
    f = TTFont(FONT)
    gs, cmap, upm = f.getGlyphSet(), f.getBestCmap(), f["head"].unitsPerEm
    s = height / upm
    x, parts = 0.0, []
    for ch in NAME:
        g = cmap[ord(ch)]
        if ch != " ":
            pen = SVGPathPen(gs)
            # 글꼴 좌표는 y가 위로 증가 → 뒤집고, 기준선을 height*0.88에 둔다
            gs[g].draw(TransformPen(pen, (s, 0, 0, -s, x, height * 0.88)))
            parts.append(pen.getCommands())
        x += gs[g].width * s - height * 0.02  # 한글은 살짝 좁혀야 단어로 보임
    return " ".join(parts), x


def selfcheck():
    d, w = wordmark(100)
    assert d.startswith("M") and 400 < w < 900, w


def main():
    selfcheck()
    out = lambda n, s: open(os.path.join(HERE, n), "w", encoding="utf-8").write(s)
    out("jurini-symbol.svg", svg(256, 256, symbol(INK_LIGHT, LEAF_LIGHT), "주린이 기업 노트 심볼"))
    out("jurini-symbol-dark.svg", svg(256, 256, symbol(INK_DARK, LEAF_DARK), "주린이 기업 노트 심볼 (어두운 바탕)"))
    out("jurini-app-icon.svg", svg(256, 256, f'<rect width="256" height="256" rx="58" fill="{TILE}"/>'
        f'<g transform="translate(43.5 43.5) scale(.66)">{symbol(INK_DARK, LEAF_DARK)}</g>', "주린이 기업 노트 앱 아이콘"))
    # 안드로이드 적응형 아이콘 전경 (108dp 캔버스의 가운데 66dp 안전 영역 = 61%)
    out("jurini-adaptive-foreground.svg", svg(256, 256, f'<g transform="translate(50 50) scale(.61)">{symbol(INK_DARK, LEAF_DARK)}</g>',
        "앱 아이콘 전경"))

    # 가로형: 심볼 높이 256, 글자 높이 = 심볼의 40%, 간격 = 줄 하나 굵기의 3배
    d, w = wordmark(100)
    for name, ink, leaf in (("jurini-horizontal.svg", INK_LIGHT, LEAF_LIGHT), ("jurini-horizontal-dark.svg", INK_DARK, LEAF_DARK)):
        body = symbol(ink, leaf) + f'<path fill="{ink}" transform="translate(236 86)" d="{d}"/>'
        out(name, svg(round(236 + w + 24), 256, body, "주린이 기업 노트 가로 로고"))
    # 세로형: 심볼 위, 글자 아래 가운데
    W = max(256, round(w) + 40)
    for name, ink, leaf in (("jurini-stacked.svg", INK_LIGHT, LEAF_LIGHT), ("jurini-stacked-dark.svg", INK_DARK, LEAF_DARK)):
        body = f'<g transform="translate({(W - 256) / 2} 0)">{symbol(ink, leaf)}</g>' \
               f'<path fill="{ink}" transform="translate({(W - w) / 2} 270)" d="{d}"/>'
        out(name, svg(W, 380, body, "주린이 기업 노트 세로 로고"))
    print("ok", os.listdir(HERE))


if __name__ == "__main__":
    main()
