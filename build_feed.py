"""뉴스 탭용 회사별 최신 뉴스 제목 → docs/feed.json (매시간 .github/workflows/feed.yml이 실행)

대상: 자세한 노트가 있는 미국 50개 + 한국 매출 상위 30개.
출처: 구글 뉴스 RSS(한국어). 제목·언론사·시간·링크만 저장하고 본문은 저장하지 않는다(원문은 링크로 연다).
shortcut: 구글 뉴스 RSS는 개인·비상업 용도 조건이 있음. 광고를 붙여 출시하기 전에 네이버 검색 API(뉴스) 등
          상업 사용이 허용된 API로 fetch_news()만 바꾼다.
앱 규칙에 맞게 주가 숫자·목표가·매수/매도 추천이 들어간 제목은 뺀다.
실행: python build_feed.py   (약 2분)
"""
import html
import json
import os
import re
import sys
import time
import urllib.parse
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime

from build_sp500 import fetch

OUT = "docs/feed.json"
PER_COMPANY = 5
DAYS = 7
# 주가 숫자(예: "주가 325달러", "5만원 돌파")와 매수·매도 추천만 거른다. "영업이익 10조원" 같은 실적 숫자는 둔다.
BANNED = re.compile(r"목표가|목표주가|매수|매도|추천|급등주|테마주|주가\D{0,6}\d|\d[\d,.]*\s*(만|천)?\s*(달러|원)\s*(선|대)?\s*(돌파|마감|붕괴|회복|터치|안착)|\$\s*\d")


def clean_title(t, source):
    t = html.unescape(t).strip()
    suffix = " - " + source
    return t[: -len(suffix)] if source and t.endswith(suffix) else t


def parse_rss(xml, now):
    out = []
    for it in re.findall(r"<item>(.*?)</item>", xml, re.S):
        def g(tag):
            m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", it, re.S)
            return html.unescape(m.group(1)).strip() if m else ""
        try:
            when = parsedate_to_datetime(g("pubDate")).astimezone(timezone.utc)
        except (TypeError, ValueError):
            continue
        src = g("source")
        title = clean_title(g("title"), src)
        if not title or BANNED.search(title) or when < now - timedelta(days=DAYS) or not g("link").startswith("https://"):
            continue
        out.append({"t": title, "src": src, "date": when.strftime("%Y-%m-%dT%H:%M:%SZ"), "url": g("link")})
    out.sort(key=lambda x: x["date"], reverse=True)
    seen, uniq = set(), []
    for x in out:  # 같은 제목(다른 언론사 재전송)은 하나만
        if x["t"] not in seen:
            seen.add(x["t"])
            uniq.append(x)
    return uniq[:PER_COMPANY]


def fetch_news(name, now):
    name = re.sub(r"\(.*?\)", "", name).strip()  # "P&G(프록터앤드갬블)" → "P&G"
    q = f'"{name}" (주가 OR 실적 OR 주식 OR 공시) when:{DAYS}d'
    url = "https://news.google.com/rss/search?" + urllib.parse.urlencode({"q": q, "hl": "ko", "gl": "KR", "ceid": "KR:ko"})
    return parse_rss(fetch(url).decode("utf-8", errors="replace"), now)


def selfcheck():
    now = datetime(2026, 11, 12, tzinfo=timezone.utc)
    xml = """<item><title>엔비디아 실적 발표 앞두고 - 연합뉴스</title><link>https://n.example/a</link>
<pubDate>Wed, 11 Nov 2026 22:53:19 GMT</pubDate><source url="x">연합뉴스</source></item>
<item><title>엔비디아 목표가 325달러 - A</title><link>https://n.example/b</link><pubDate>Wed, 11 Nov 2026 20:00:00 GMT</pubDate><source>A</source></item>
<item><title>옛날 뉴스 - B</title><link>https://n.example/c</link><pubDate>Mon, 01 Jan 2026 00:00:00 GMT</pubDate><source>B</source></item>
<item><title>엔비디아 실적 발표 앞두고 - 연합뉴스</title><link>https://n.example/d</link><pubDate>Wed, 11 Nov 2026 21:00:00 GMT</pubDate><source>연합뉴스</source></item>"""
    got = parse_rss(xml, now)
    assert got == [{"t": "엔비디아 실적 발표 앞두고", "src": "연합뉴스", "date": "2026-11-11T22:53:19Z", "url": "https://n.example/a"}], got
    assert BANNED.search("삼성전자 주가 10만원") and BANNED.search("엔비디아 200달러 돌파") and BANNED.search("목표가 상향")
    assert not BANNED.search("삼성전자 3분기 영업이익 12조원") and not BANNED.search("넷플릭스 구독료 1만원으로 인상")


def main():
    selfcheck()
    now = datetime.now(timezone.utc)
    us = json.load(open("jurini_app/assets/companies.json", encoding="utf-8"))["companies"]
    kr = [c for c in json.load(open("jurini_app/assets/kr.json", encoding="utf-8"))["companies"] if c.get("financials")][:30]
    targets = [(c["ticker"], c["name_ko"], "미국") for c in us] + [(c["ticker"], c["name_ko"], "한국") for c in kr]
    prev = json.load(open(OUT, encoding="utf-8"))["companies"] if os.path.exists(OUT) else {}
    companies, failed = {}, 0
    for tk, name, market in targets:
        try:
            items = fetch_news(name, now)
        except Exception as e:  # 한 회사가 실패하면 지난번 뉴스를 그대로 둔다
            print(f"  ! {tk}: {e}", file=sys.stderr)
            items, failed = prev.get(tk, {}).get("items", []), failed + 1
        companies[tk] = {"name": name, "market": market, "items": items}
        time.sleep(1)  # 구글에 부담 주지 않게 천천히
    if failed > len(targets) // 2:
        sys.exit(f"절반 넘게 실패({failed}개) — 저장하지 않음")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"asof": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "source": "구글 뉴스(한국어) 제목 모음", "companies": companies},
                  f, ensure_ascii=False, indent=1)
    print("저장:", OUT, len(companies), "개 회사,", sum(len(c["items"]) for c in companies.values()), "개 뉴스")


if __name__ == "__main__":
    main()
