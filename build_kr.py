"""한국 상장회사(코스피·코스닥) 기본 카드 → jurini_app/assets/kr.json

한국거래소 KIND의 '상장법인목록'에서 회사명·종목코드·업종·주요제품·상장일을 받는다.
재무 숫자와 시가총액은 아직 없다(다음 단계: DART 오픈API 키 필요).
실행: python build_kr.py   (1분 이내, 상장·상폐가 생기면 다시 실행)
"""
import html
import json
import re
from datetime import date

from build_sp500 import fetch

OUT = "jurini_app/assets/kr.json"
MARKETS = {"stockMkt": "코스피", "kosdaqMkt": "코스닥"}
URL = "https://kind.krx.co.kr/corpgeneral/corpList.do?method=download&marketType={}"


def parse(page):
    rows = []
    for r in re.findall(r"<tr>(.*?)</tr>", page, re.S):
        cells = [html.unescape(re.sub(r"<.*?>", "", c)).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) >= 7 and cells[0] != "회사명":
            rows.append(cells)
    return rows


def card(cells, market):
    name, _, code, sector, product, listed, fy = cells[:7]
    return {"id": "kr_" + code, "ticker": code, "name_ko": name, "market": market, "sector": sector,
            "one_liner": product.rstrip(" 등") if product else sector, "listed": listed, "fiscal_month": fy}


def selfcheck():
    page = "<tr><th>회사명</th></tr><tr><td>삼성전자</td><td>유가</td><td>005930</td><td>통신 및 방송 장비 제조업</td><td>휴대폰, 반도체 등</td><td>1975-06-11</td><td>12월</td></tr>"
    rows = parse(page)
    assert card(rows[0], "코스피") == {"id": "kr_005930", "ticker": "005930", "name_ko": "삼성전자", "market": "코스피",
                                      "sector": "통신 및 방송 장비 제조업", "one_liner": "휴대폰, 반도체", "listed": "1975-06-11",
                                      "fiscal_month": "12월"}, rows


def main():
    selfcheck()
    out = []
    for key, market in MARKETS.items():
        rows = parse(fetch(URL.format(key)).decode("euc-kr", errors="replace"))
        # 스팩(기업인수목적회사)은 실제 사업이 없는 껍데기 회사라 뺀다
        cards = [card(c, market) for c in rows if "스팩" not in c[0]]
        assert len(cards) > 500, (market, len(cards))  # 목록이 비정상적으로 적으면 저장하지 않는다
        print(market, len(cards))
        out += cards
    out.sort(key=lambda c: c["name_ko"])
    meta = {"source": "한국거래소 KIND 상장법인목록", "asof": date.today().isoformat(), "count": len(out)}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "companies": out}, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
