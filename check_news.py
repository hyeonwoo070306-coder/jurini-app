"""docs/news.json 검사기 (+ 통과하면 앱 복사본 jurini_app/assets/news.json 갱신)

Claude 예약 작업(하루 2번)이 뉴스를 정리한 뒤 커밋 전에 반드시 실행한다. 실패하면 커밋하지 않는다.
실행: python check_news.py   (종료 코드 0 = 통과)
"""
import json
import os
import re
import shutil
import sys

OUT, COPY = "docs/news.json", "jurini_app/assets/news.json"
BANNED = re.compile(r"목표가|목표 주가|매수|매도|추천|사세요|파세요|사야|팔아야|급등할|폭락할|오를 것|내릴 것|오를 거|내릴 거")
PRICE = re.compile(r"주가[^.]{0,12}\d[\d,.]*\s*(원|달러|만\s*원)|\d[\d,.]*\s*(달러|원)\s*(로|까지|선)\s*(올|내|떨|상승|하락)")
DATE = re.compile(r"^\d{4}(-\d{2}){0,2}$")  # 연도만, 연-월, 연-월-일


def item_problems(x, where, term_ids):
    out = []
    if x.get("type") not in ("good", "bad", "watch"):
        out.append(f"{where}: type은 good/bad/watch")
    for k, mx in (("title", 80), ("impact", 160), ("source", 40)):
        if not isinstance(x.get(k), str) or not 0 < len(x[k]) <= mx:
            out.append(f"{where}: {k}는 1~{mx}자")
    if not DATE.match(str(x.get("date", ""))):
        out.append(f"{where}: date는 YYYY, YYYY-MM, YYYY-MM-DD")
    if not str(x.get("url", "")).startswith("https://"):
        out.append(f"{where}: url은 https://")
    # 배우기 연결용(선택): 관련 용어 id 1~3개, 그 용어로 읽는 법 120자 이내
    if "terms" in x:
        ts = x["terms"]
        if not isinstance(ts, list) or not 1 <= len(ts) <= 3 or (term_ids is not None and not set(ts) <= term_ids):
            out.append(f"{where}: terms는 용어사전에 있는 id 1~3개")
    if "learn" in x and not (isinstance(x["learn"], str) and 0 < len(x["learn"]) <= 120):
        out.append(f"{where}: learn은 1~120자")
    text = f"{x.get('title', '')} {x.get('impact', '')} {x.get('learn', '')}"
    if BANNED.search(text) or PRICE.search(text):
        out.append(f"{where}: 투자 권유·주가 숫자 표현 금지")
    return out


def problems(n, known, term_ids=None):
    out = []
    if not isinstance(n.get("asof"), str) or not re.match(r"^\d{4}-\d{2}-\d{2}$", n["asof"]):
        out.append("asof는 YYYY-MM-DD")
    cs = n.get("companies")
    if not isinstance(cs, dict) or len(cs) < 40:
        return out + ["companies가 40개 회사보다 적음 (지운 것 아닌지 확인)"]
    for tk, items in cs.items():
        if tk not in known:
            out.append(f"{tk}: 앱에 없는 티커")
        if not isinstance(items, list) or not 1 <= len(items) <= 4:
            out.append(f"{tk}: 뉴스는 1~4개")
            continue
        for x in items:
            out += item_problems(x, f"{tk} '{str(x.get('title'))[:20]}'", term_ids)
    # 오늘의 시장(선택, 예전 데이터엔 없음): 시장 전체 흐름 뉴스 2~4개
    if "market" in n:
        m = n["market"]
        if not isinstance(m, list) or not 2 <= len(m) <= 4:
            out.append("market은 2~4개")
        else:
            for x in m:
                out += item_problems(x, f"시장 '{str(x.get('title'))[:20]}'", term_ids)
    return out


def term_ids():
    ids = {t["id"] for t in json.load(open("jurini_app/assets/glossary.json", encoding="utf-8"))["terms"]}
    if os.path.exists("docs/glossary_ai.json"):
        ids |= {t["id"] for t in json.load(open("docs/glossary_ai.json", encoding="utf-8"))["terms"]}
    return ids


def selfcheck():
    item = {"date": "2026-11-12", "type": "good", "title": "실적 발표", "impact": "돈을 잘 벌고 있어요.", "source": "회사 발표", "url": "https://a.com"}
    known = {f"T{i}" for i in range(40)}
    good = {"asof": "2026-11-13", "companies": {k: [item] for k in known}}
    assert problems(good, known) == []
    bad = {"asof": "2026-11-13", "companies": {**good["companies"], "T0": [{**item, "impact": "주가가 300달러까지 오를 것"}]}}
    assert problems(bad, known), "금지 표현을 못 잡음"
    assert problems({"asof": "2026-11-13", "companies": {"T0": [item]}}, known), "회사 수 급감을 못 잡음"
    terms = {"cpi", "per"}
    assert problems({**good, "market": [item, item]}, known, terms) == [], "market 정상인데 오류"
    assert problems({**good, "market": [item] * 5}, known, terms), "market 5개를 못 잡음"
    assert problems({**good, "companies": {**good["companies"], "T0": [{**item, "terms": ["없는용어"]}]}}, known, terms), "없는 용어를 못 잡음"
    assert problems({**good, "companies": {**good["companies"], "T0": [{**item, "terms": ["cpi"], "learn": "가" * 121}]}}, known, terms), "learn 121자를 못 잡음"
    assert problems({**good, "companies": {**good["companies"], "T0": [{**item, "terms": ["cpi"], "learn": "물가 뉴스예요."}]}}, known, terms) == []


def main():
    selfcheck()
    known = {c["ticker"] for f in ("companies.json", "kr.json") for c in json.load(open(f"jurini_app/assets/{f}", encoding="utf-8"))["companies"]}
    n = json.load(open(OUT, encoding="utf-8"))
    errs = problems(n, known, term_ids())
    if errs:
        print("\n".join(errs[:50]))
        sys.exit(f"검사 실패 {len(errs)}건 — 커밋하지 말 것")
    shutil.copy(OUT, COPY)
    print("통과:", len(n["companies"]), "개 회사, 앱 복사본 갱신")


if __name__ == "__main__":
    main()
