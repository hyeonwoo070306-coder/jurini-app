"""경제 일정 캘린더 → docs/calendar.json (+ 앱 복사본 jurini_app/assets/calendar.json)

- 경제 지표: calendar_macro.json (FOMC·BLS·BEA·한국은행·통계청 공식 일정표에서 손으로 옮긴 것). 기관이 새해 일정을 내면 거기에 추가.
- 실적 발표: 앱의 미국 50개 회사, 나스닥 earnings-date (예상일*, 회사 확정 전엔 바뀔 수 있음).
  shortcut: 나스닥 데이터는 상업 사용 조건 확인 필요(CLAUDE.md 데이터 조사 참고). 출시 전 허가된 데이터로 바꾼다.
매일 .github/workflows/daily.yml에서 실행. 실행: python build_calendar.py (약 1분)
"""
import json
import os
import re
import shutil
import sys
import time
from datetime import date, datetime, timedelta, timezone

from build_sp500 import fetch

OUT, COPY = "docs/calendar.json", "jurini_app/assets/calendar.json"
MACRO = "calendar_macro.json"
DAYS_AHEAD = 120
MONTHS = {m: i for i, m in enumerate(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}


def us_dst(d):
    """미국 서머타임: 3월 둘째 일요일 ~ 11월 첫째 일요일"""
    def nth_sunday(y, m, n):
        first = date(y, m, 1)
        return first + timedelta(days=(6 - first.weekday()) % 7 + 7 * (n - 1))
    return nth_sunday(d.year, 3, 2) <= d < nth_sunday(d.year, 11, 1)


def to_kst(day, hhmm, zone):
    """'2026-12-09', '14:00', 'ET'|'KST' → 한국 시간 'YYYY-MM-DD HH:MM'"""
    d = date.fromisoformat(day)
    h, m = map(int, hhmm.split(":"))
    off = 9 if zone == "KST" else (-4 if us_dst(d) else -5)
    t = datetime(d.year, d.month, d.day, h, m, tzinfo=timezone(timedelta(hours=off)))
    return t.astimezone(timezone(timedelta(hours=9))).strftime("%Y-%m-%d %H:%M")


def macro_events(today, until):
    out = []
    for e in json.load(open(MACRO, encoding="utf-8"))["events"]:
        if not today <= e["date"] <= until:
            continue
        kst = None
        if e.get("time"):
            hhmm, zone = e["time"].split()
            kst = to_kst(e["date"], hhmm, zone)
        out.append({"date": (kst or e["date"])[:10], "kst": kst, "type": "macro", "kind": e["kind"], "title": e["title"],
                    "source": e["source"], "url": e["url"]})
    return out


def parse_earnings(d):
    """나스닥 earnings-date 응답 → (YYYY-MM-DD, 'before'|'after'|None) 또는 None"""
    m = re.search(r"for \S+: (\w{3}) (\d{1,2}), (\d{4})", (d or {}).get("announcement") or "")
    if not m or m.group(1) not in MONTHS:
        return None
    day = f"{m.group(3)}-{MONTHS[m.group(1)]:02d}-{int(m.group(2)):02d}"
    text = ((d or {}).get("reportText") or "").lower()
    when = "after" if "after market close" in text else "before" if "before market open" in text else None
    return day, when


def selfcheck():
    assert to_kst("2026-12-09", "14:00", "ET") == "2026-12-10 04:00"  # 겨울(EST): +14시간
    assert to_kst("2027-06-16", "14:00", "ET") == "2027-06-17 03:00"  # 여름(EDT): +13시간
    assert to_kst("2027-01-15", "08:00", "KST") == "2027-01-15 08:00"
    assert not us_dst(date(2026, 11, 14)) and us_dst(date(2027, 3, 14)) and not us_dst(date(2027, 3, 13))
    assert parse_earnings({"announcement": "Earnings announcement* for NVDA: Nov 17, 2026",
                           "reportText": "expected* to report earnings on 11/17/2026 after market close."}) == ("2026-11-17", "after")
    assert parse_earnings({"announcement": None}) is None


def main():
    selfcheck()
    today = date.today().isoformat()
    until = (date.today() + timedelta(days=DAYS_AHEAD)).isoformat()
    events = macro_events(today, until)
    prev = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {"events": []}
    prev_earn = {e["ticker"]: e for e in prev["events"] if e["type"] == "earnings"}
    cs = json.load(open("jurini_app/assets/companies.json", encoding="utf-8"))["companies"]
    failed = 0
    for c in cs:
        tk = c["ticker"]
        try:
            got = parse_earnings(json.loads(fetch(f"https://api.nasdaq.com/api/analyst/{tk}/earnings-date"))["data"])
        except Exception as ex:
            print(f"  ! {tk}: {ex}", file=sys.stderr)
            failed += 1
            got = None
            if tk in prev_earn and prev_earn[tk]["date"] >= today:  # 못 받으면 지난번 것 유지
                events.append(prev_earn[tk])
        if got and today <= got[0] <= until:
            day, when = got
            if when == "after":  # 미국 장 마감 뒤 발표 = 한국 시간 다음 날 아침
                day = (date.fromisoformat(day) + timedelta(days=1)).isoformat()
            events.append({"date": day, "kst": None, "type": "earnings", "kind": "earnings", "ticker": tk, "when": when,
                           "title": f"{c['name_ko']} 실적 발표", "source": "나스닥(예상일)",
                           "url": f"https://www.nasdaq.com/market-activity/stocks/{tk.lower().replace('.', '-')}/earnings"})
        time.sleep(0.4)
    if failed > 25:
        sys.exit(f"절반 넘게 실패({failed}개) — 저장하지 않음")
    events.sort(key=lambda e: (e["date"], e["kst"] or "", e["title"]))
    data = {"asof": today, "note": "경제 지표는 각 기관 공식 일정, 실적 발표일은 예상일(회사 확정 전엔 바뀔 수 있음). 시각은 한국 시간.",
            "events": events}
    with open(OUT, "w", encoding="utf-8") as fp:
        json.dump(data, fp, ensure_ascii=False, indent=1)
    shutil.copy(OUT, COPY)
    print("저장:", OUT, len(events), "개 일정 (경제 지표", sum(e["type"] == "macro" for e in events), ")")


if __name__ == "__main__":
    main()
