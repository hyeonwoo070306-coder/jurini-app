"""기업 깊이 노트 검사기 + 합치기.

원본: deep_research/deep_*.json  ({"companies": {티커: 노트}})
결과: jurini_app/assets/deep.json ({"asof", "companies": {티커: 노트}})
형식은 deep_research/SCHEMA.md. 통과해야 합친다.

python check_deep.py            # 전부 검사 + 합치기
python check_deep.py deep_research/deep_1.json   # 한 파일만 검사(합치지 않음)
"""
import glob
import json
import re
import sys

OUT = "jurini_app/assets/deep.json"
BANNED = re.compile(r"매수|매도|추천|목표가|사세요|파세요|오를 것|내릴 것|오를 거|떨어질 거|급등|폭등|대박")
PRICE = re.compile(r"(?<![수])주가[^.]{0,12}\d|\d+(\.\d+)?\s*달러(에|로)\s*(거래|마감)|PER\s*(은|는|이|가)?\s*약?\s*\d")
URL = re.compile(r"^https://\S+$")


def text_problems(where, s, lo, hi):
    out = []
    if not isinstance(s, str) or not (lo <= len(s) <= hi):
        out.append(f"{where}: 글자 수 {lo}~{hi} (지금 {len(s) if isinstance(s, str) else '없음'})")
        return out
    if BANNED.search(s):
        out.append(f"{where}: 투자 권유·주가 예측 표현 '{BANNED.search(s)[0]}'")
    if PRICE.search(s):
        out.append(f"{where}: 주가·그날 PER 숫자 '{PRICE.search(s)[0]}'")
    if not re.search(r"(요|다|음|임)[.!?)]?$|[가-힣a-zA-Z0-9%)]$", s.strip()):
        out.append(f"{where}: 문장 끝 이상")
    return out


def items(where, xs, lo, hi, fields):
    out = []
    if not isinstance(xs, list) or not (lo <= len(xs) <= hi):
        return [f"{where}: {lo}~{hi}개"]
    for i, x in enumerate(xs):
        if not isinstance(x, dict):
            out.append(f"{where}[{i}]: 객체여야 함")
            continue
        for k, (a, b) in fields.items():
            out += text_problems(f"{where}[{i}].{k}", x.get(k), a, b)
    return out


def note_problems(tk, n, tickers, term_ids):
    w = tk
    out = []
    if tk not in tickers:
        out.append(f"{w}: 앱의 미국 50개·한국 상장 회사 티커가 아님")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(n.get("asof", ""))):
        out.append(f"{w}.asof: YYYY-MM-DD")
    out += text_problems(f"{w}.summary", n.get("summary"), 80, 260)
    out += items(f"{w}.tech", n.get("tech"), 3, 5, {"name": (2, 30), "what": (40, 220), "why": (40, 220), "edge": (40, 220)})
    v = n.get("vision") or {}
    out += text_problems(f"{w}.vision.goal", v.get("goal"), 40, 240)
    ms = v.get("milestones")
    if not isinstance(ms, list) or not (2 <= len(ms) <= 6):
        out.append(f"{w}.vision.milestones: 2~6개")
    else:
        for i, m in enumerate(ms):
            out += text_problems(f"{w}.vision.milestones[{i}].what", m.get("what"), 5, 120)
            if not re.fullmatch(r"\d{4}(-\d{2})?|\d{4}년( [1-4]분기| 상반기| 하반기)?", str(m.get("when", ""))):
                out.append(f"{w}.vision.milestones[{i}].when: '2026', '2026-11', '2027년 하반기' 형식")
            if m.get("status") not in ("done", "planned"):
                out.append(f"{w}.vision.milestones[{i}].status: done|planned")
    out += items(f"{w}.rivals", n.get("rivals"), 3, 5, {"name": (2, 30), "diff": (40, 200)})
    out += items(f"{w}.bull", n.get("bull"), 3, 4, {"point": (10, 80), "evidence": (40, 220)})
    out += items(f"{w}.bear", n.get("bear"), 3, 4, {"point": (10, 80), "evidence": (40, 220)})
    ws = n.get("watch")
    if not isinstance(ws, list) or not (2 <= len(ws) <= 4):
        out.append(f"{w}.watch: 2~4개")
    else:
        for i, s in enumerate(ws):
            out += text_problems(f"{w}.watch[{i}]", s, 10, 120)
    for t in n.get("terms", []):
        if t not in term_ids:
            out.append(f"{w}.terms: 용어사전에 없는 id '{t}'")
    src = n.get("sources")
    if not isinstance(src, list) or len(src) < 4:
        out.append(f"{w}.sources: 4개 이상")
    else:
        for i, s in enumerate(src):
            if not URL.match(str(s.get("url", ""))) or not s.get("title"):
                out.append(f"{w}.sources[{i}]: title과 https url 필수")
        urls = [s.get("url", "") for s in src]
        if any(re.search(r"browse-edgar|/search|[?&](q|query|company)=", u, re.I) for u in urls):
            out.append(f"{w}.sources: 검색 결과 주소 말고 실제 문서 주소를 쓴다")
        filing = sum(bool(re.search(r"sec\.gov/Archives/edgar/data/\d+/|dart\.fss\.or\.kr/dsaf001/main\.do\?rcpNo=\d+", u)) for u in urls)
        if filing < 1:
            out.append(f"{w}.sources: 실제 공시 원문 1개 이상 필요(sec.gov/Archives/edgar/data/... 또는 dart.fss.or.kr/dsaf001/main.do?rcpNo=...)")
        official = sum(bool(re.search(r"sec\.gov/Archives|dart\.fss\.or\.kr/dsaf001|investor|ir\.|/ir/|/investors?/|annualreport|shareholder", u, re.I)) for u in urls)
        if official < 2:
            out.append(f"{w}.sources: 공시·IR 출처가 2개 이상 필요")
    return out


def selfcheck():
    assert text_problems("x", "엔비디아 주가는 180달러에 거래돼요.", 5, 100)
    assert text_problems("x", "지금 사세요.", 3, 100)
    assert text_problems("x", "데이터센터 매출이 2025 회계연도에 크게 늘었어요.", 5, 100) == []
    assert items("x", [], 3, 5, {}) == ["x: 3~5개"]


def main():
    selfcheck()
    tickers = {c["ticker"] for c in json.load(open("jurini_app/assets/companies.json", encoding="utf-8"))["companies"]}
    tickers |= {c["ticker"] for c in json.load(open("jurini_app/assets/kr.json", encoding="utf-8"))["companies"]}
    term_ids = {t["id"] for t in json.load(open("jurini_app/assets/glossary.json", encoding="utf-8"))["terms"]}
    files = sys.argv[1:] or sorted(glob.glob("deep_research/deep_*.json"))
    merged, errs = {}, []
    for f in files:
        for tk, n in json.load(open(f, encoding="utf-8"))["companies"].items():
            if tk in merged:
                errs.append(f"{f}: {tk} 중복")
            errs += note_problems(tk, n, tickers, term_ids)
            merged[tk] = n
    if errs:
        print("\n".join(errs[:80]))
        sys.exit(f"검사 실패 {len(errs)}건")
    print(f"통과: {len(merged)}개 회사")
    if sys.argv[1:]:
        return
    asof = max((n["asof"] for n in merged.values()), default="")
    with open(OUT, "w", encoding="utf-8") as fp:
        json.dump({"asof": asof, "companies": merged}, fp, ensure_ascii=False, indent=1)
    print("저장:", OUT)


if __name__ == "__main__":
    main()
