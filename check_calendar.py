"""calendar_macro.json(경제 지표 일정) · calendar_results.json(지난 일정 결과 요약) 검사기

Claude 예약 작업(매일)이 새 일정·결과를 넣은 뒤 커밋 전에 반드시 실행한다. 실패하면 커밋하지 않는다.
실행: python check_calendar.py   (종료 코드 0 = 통과)
"""
import json
import re
import sys

from check_news import BANNED, PRICE

KINDS = {"fomc", "us_cpi", "us_jobs", "us_pce", "us_gdp", "bok_rate", "kr_cpi", "other"}
DAY = re.compile(r"^\d{4}-\d{2}-\d{2}$")
RATE_KINDS = {"fomc", "bok_rate"}  # 금리 결정: 결과 비교(vs)는 올림/그대로/내림
ID = re.compile(r"^\d{4}-\d{2}-\d{2}:[A-Za-z0-9._]+$")


def macro_problems(m):
    out, seen = [], set()
    for e in m.get("events", []):
        w = f"{e.get('date')} {e.get('title')}"
        if not DAY.match(str(e.get("date", ""))):
            out.append(f"{w}: date는 YYYY-MM-DD")
        if e.get("kind") not in KINDS:
            out.append(f"{w}: kind는 {sorted(KINDS)} 중 하나")
        if e.get("kind") == "other" and not (isinstance(e.get("why"), str) and 0 < len(e["why"]) <= 80):
            out.append(f"{w}: kind가 other면 why(왜 중요한지, 80자 이내) 필수")
        if e.get("time") is not None and not re.match(r"^\d{2}:\d{2} (ET|KST)$", str(e["time"])):
            out.append(f"{w}: time은 'HH:MM ET' / 'HH:MM KST' / null")
        if not (isinstance(e.get("title"), str) and 0 < len(e["title"]) <= 30):
            out.append(f"{w}: title은 1~30자")
        if not str(e.get("url", "")).startswith("https://") or not e.get("source"):
            out.append(f"{w}: 공식 출처(source)와 https url 필수")
        key = (e.get("date"), e.get("kind"), e.get("title"))
        if key in seen:
            out.append(f"{w}: 같은 일정이 두 번")
        seen.add(key)
    return out


def result_problems(r):
    out = []
    for k, v in r.items():
        if not ID.match(k):
            out.append(f"{k}: 키는 'YYYY-MM-DD:kind' 또는 'YYYY-MM-DD:티커'")
            continue
        for f, mx in (("summary", 120), ("impact", 160), ("source", 40)):
            if not (isinstance(v.get(f), str) and 0 < len(v[f]) <= mx):
                out.append(f"{k}: {f}는 1~{mx}자")
        if not str(v.get("url", "")).startswith("https://"):
            out.append(f"{k}: url은 https://")
        if "vs" in v:  # 선택: 앱 '내 추리 vs 실제' 비교용
            ok = {"hike", "hold", "cut"} if k.split(":")[1] in RATE_KINDS else {"above", "inline", "below"}
            if v["vs"] not in ok:
                out.append(f"{k}: vs는 {sorted(ok)} 중 하나")
        text = f"{v.get('summary', '')} {v.get('impact', '')}"
        if BANNED.search(text) or PRICE.search(text):
            out.append(f"{k}: 투자 권유·주가 숫자 표현 금지")
    return out


def earn_problems(m):
    """calendar_earnings.json: 회사 IR 공식 발표로 확인한 실적 발표일만. 나스닥·뉴스 기사 금지."""
    out, seen = [], set()
    tickers = {c["ticker"] for c in json.load(open("jurini_app/assets/companies.json", encoding="utf-8"))["companies"]}
    for i, e in enumerate(m.get("events", [])):
        w = f"earnings[{i}]"
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(e.get("date", ""))):
            out.append(f"{w}: date는 YYYY-MM-DD")
        if e.get("ticker") not in tickers:
            out.append(f"{w}: ticker는 앱의 미국 50개 회사 중 하나")
        if e.get("when") not in ("before", "after", None):
            out.append(f"{w}: when은 before/after/null")
        if not str(e.get("url", "")).startswith("https://") or not e.get("source"):
            out.append(f"{w}: 회사 IR 출처(source)와 https url 필수")
        if "nasdaq" in str(e.get("url", "")).lower() or "나스닥" in str(e.get("source", "")):
            out.append(f"{w}: 나스닥은 출처로 쓸 수 없음(회사 IR만)")
        if (e.get("date"), e.get("ticker")) in seen:
            out.append(f"{w}: 중복")
        seen.add((e.get("date"), e.get("ticker")))
    return out


def selfcheck():
    ir = {"date": "2026-11-20", "ticker": "NVDA", "when": "after", "source": "NVIDIA IR", "url": "https://investor.nvidia.com/x"}
    assert earn_problems({"events": [ir]}) == []
    assert earn_problems({"events": [{**ir, "url": "https://www.nasdaq.com/x"}]}), "나스닥 출처를 못 잡음"
    assert earn_problems({"events": [{**ir, "ticker": "ZZZZ"}]}), "없는 티커를 못 잡음"
    ok = {"date": "2026-12-10", "kind": "kr_cpi", "title": "한국 소비자물가", "time": "08:00 KST", "source": "국가데이터처", "url": "https://x.kr"}
    assert macro_problems({"events": [ok]}) == []
    assert macro_problems({"events": [ok, ok]}), "중복을 못 잡음"
    assert macro_problems({"events": [{**ok, "kind": "other"}]}), "other인데 why 없음을 못 잡음"
    res = {"summary": "물가 3.0% 상승", "impact": "금리 인하 기대가 커질 수 있어요.", "source": "BLS", "url": "https://bls.gov"}
    assert result_problems({"2026-12-10:us_cpi": res}) == []
    assert result_problems({"2026-12-10:us_cpi": {**res, "impact": "주가가 오를 것"}}), "주가 예측을 못 잡음"
    assert result_problems({"2026-12-10:us_cpi": {**res, "vs": "above"}}) == []
    assert result_problems({"2026-12-10:fomc": {**res, "vs": "cut"}}) == []
    assert result_problems({"2026-12-10:fomc": {**res, "vs": "above"}}), "금리 결정에 above를 못 잡음"
    assert result_problems({"2026-12-10:us_cpi": {**res, "vs": "cut"}}), "물가에 cut을 못 잡음"


def main():
    selfcheck()
    errs = macro_problems(json.load(open("calendar_macro.json", encoding="utf-8"))) + \
        result_problems(json.load(open("calendar_results.json", encoding="utf-8"))) +         earn_problems(json.load(open("calendar_earnings.json", encoding="utf-8")))
    if errs:
        print("\n".join(errs[:50]))
        sys.exit(f"검사 실패 {len(errs)}건 — 커밋하지 말 것")
    print("통과")


if __name__ == "__main__":
    main()
