"""S&P 500 기본 카드 데이터 만들기 → jurini_app/assets/sp500.json

1) 위키백과에서 S&P 500 종목 목록(티커, 이름, 섹터, CIK)을 받는다.
2) 미국 SEC 공식 공시 데이터(XBRL companyfacts)에서 연간 재무 숫자를 뽑는다.
3) sp500_ko.txt (티커|한글 이름|한 줄 설명)를 붙인다.

실행: python build_sp500.py        (약 10~20분, 분기마다 한 번 돌리면 된다)
"""
import datetime as dt
import html
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).parent
OUT = ROOT / "jurini_app" / "assets" / "sp500.json"
KO = ROOT / "sp500_ko.txt"
UA = "jurini-study-app/0.1 (beginner investing education)"

SECTOR_KO = {
    "Information Technology": "정보기술", "Health Care": "헬스케어", "Financials": "금융",
    "Consumer Discretionary": "임의소비재", "Communication Services": "커뮤니케이션",
    "Industrials": "산업재", "Consumer Staples": "필수소비재", "Energy": "에너지",
    "Utilities": "유틸리티", "Real Estate": "부동산", "Materials": "소재",
}

# 회사마다 같은 숫자를 다른 이름표(태그)로 공시해서, 앞에 있는 태그부터 찾는다.
TAGS = {
    "revenue": ["Revenues", "RevenueFromContractWithCustomerExcludingAssessedTax",
                "RevenueFromContractWithCustomerIncludingAssessedTax", "SalesRevenueNet",
                "RevenuesNetOfInterestExpense"],
    "operating_income": ["OperatingIncomeLoss"],
    "net_income": ["NetIncomeLoss", "ProfitLoss"],
    "ocf": ["NetCashProvidedByUsedInOperatingActivities",
            "NetCashProvidedByUsedInOperatingActivitiesContinuingOperations"],
    "capex": ["PaymentsToAcquirePropertyPlantAndEquipment", "PaymentsToAcquireProductiveAssets"],
    "cash": ["CashAndCashEquivalentsAtCarryingValue",
             "CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents", "Cash"],
    "debt": ["LongTermDebt", "LongTermDebtNoncurrent", "LongTermDebtAndCapitalLeaseObligations"],
}


# 지주회사 전환 등으로 CIK가 바뀐 회사: 예전 CIK에 과거 공시가 남아 있어 합쳐서 쓴다.
OLD_CIKS = {"XOM": ["0000034088"]}


def company_facts(cik, ticker):
    merged = {}
    for c in [cik, *OLD_CIKS.get(ticker, [])]:
        for tag, v in json.loads(fetch(f"https://data.sec.gov/api/xbrl/companyfacts/CIK{c}.json"))["facts"].get("us-gaap", {}).items():
            for unit, es in v.get("units", {}).items():
                merged.setdefault(tag, {"units": {}})["units"].setdefault(unit, []).extend(es)
    return merged


def fetch(url):
    # Windows 기본 curl은 시스템 인증서를 써서 파이썬 인증서 문제를 피한다.
    r = subprocess.run(["curl", "-sfL", "-A", UA, url], capture_output=True, timeout=120)
    if r.returncode:
        raise RuntimeError(f"다운로드 실패({r.returncode}): {url}")
    return r.stdout


def sp500_list():
    t = fetch("https://en.wikipedia.org/wiki/List_of_S%26P_500_companies").decode("utf-8")
    tb = t[t.index('id="constituents"'):]
    tb = tb[:tb.index("</table>")]
    seen, out = set(), []
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", tb, re.S):
        c = [html.unescape(re.sub(r"<[^>]+>", "", x)).strip() for x in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)]
        if not c or c[6] in seen:  # GOOGL/GOOG처럼 한 회사에 티커가 2개면 첫 번째만
            continue
        seen.add(c[6])
        out.append({"ticker": c[0], "name_en": c[1], "gics": c[2], "industry": c[3], "cik": c[6]})
    assert len(out) >= 490, f"S&P 500 목록이 이상함: {len(out)}개"
    return out


def days(e):
    return (dt.date.fromisoformat(e["end"]) - dt.date.fromisoformat(e["start"])).days


def annual(facts, key):
    """연간(10-K, 약 1년짜리) 값들을 {기말일: 값}으로. 같은 기말일은 가장 최근 공시를 쓴다."""
    out = {}
    for tag in TAGS[key]:
        for e in facts.get(tag, {}).get("units", {}).get("USD", []):
            if e.get("form", "").startswith("10-K") and "start" in e and 340 <= days(e) <= 390:
                cur = out.get(e["end"])
                if cur is None or (cur[0] == tag and e["filed"] > cur[1]):
                    out[e["end"]] = (tag, e["filed"], e["val"])
    return {k: v[2] for k, v in out.items()}


def latest_instant(facts, key):
    """여러 태그 중 가장 최근 기말일 값. 1년 반보다 오래된 값은 버린다(예전에만 쓰던 태그)."""
    best = None
    for tag in TAGS[key]:
        for e in facts.get(tag, {}).get("units", {}).get("USD", []):
            if e.get("form", "")[:4] in ("10-K", "10-Q") and "start" not in e:
                if best is None or e["end"] > best["end"]:
                    best = e
    if best and (dt.date.today() - dt.date.fromisoformat(best["end"])).days > 550:
        return None
    return best


def m(v):  # 달러 → 백만 달러 (companies.json과 같은 단위)
    return None if v is None else round(v / 1e6)


def financials(cik, ticker=""):
    facts = company_facts(cik, ticker)
    s = {k: annual(facts, k) for k in ("revenue", "operating_income", "net_income", "ocf", "capex")}
    ends = sorted(set(s["revenue"]) | set(s["net_income"]), reverse=True)[:3][::-1]
    rows = []
    for end in ends:
        g = {k: s[k].get(end) for k in s}
        fcf = g["ocf"] - g["capex"] if g["ocf"] is not None and g["capex"] is not None else None
        rows.append({
            "label": f"FY{end[:4]}", "end_date": end,
            "revenue": m(g["revenue"]), "operating_income": m(g["operating_income"]),
            "net_income": m(g["net_income"]), "capex": m(g["capex"]), "free_cash_flow": m(fcf),
            "operating_margin_pct": round(g["operating_income"] / g["revenue"] * 100, 1)
            if g["revenue"] and g["operating_income"] is not None else None,
        })
    cash, debt = latest_instant(facts, "cash"), latest_instant(facts, "debt")
    c, d = (m(cash["val"]) if cash else None), (m(debt["val"]) if debt else None)
    # 투자자산(유가증권)은 빠진 '현금성 자산'이라 순현금은 계산하지 않는다(애플처럼 오해 소지).
    balance = {"asof": max([x["end"] for x in (cash, debt) if x], default=None), "cash": c, "long_term_debt": d}
    return rows, balance


def main():
    ko = {}
    if KO.exists():
        for line in KO.read_text(encoding="utf-8").splitlines():
            if line.strip():
                tk, name, one = line.split("|")
                ko[tk] = (name, one)
    companies = []
    lst = sp500_list()
    for i, c in enumerate(lst, 1):
        try:
            fin, bal = financials(c["cik"], c["ticker"])
        except Exception as e:  # 한 회사가 실패해도 나머지는 계속
            print(f"  ! {c['ticker']}: {e}", file=sys.stderr)
            fin, bal = [], {}
        name_ko, one = ko.get(c["ticker"], (c["name_en"], ""))
        companies.append({
            "id": c["ticker"].lower(), "ticker": c["ticker"], "name_ko": name_ko, "name_en": c["name_en"],
            "sector": SECTOR_KO.get(c["gics"], c["gics"]), "industry": c["industry"], "one_liner": one,
            "financials": fin, "balance": bal,
        })
        print(f"{i}/{len(lst)} {c['ticker']} {len(fin)}년", flush=True)
        time.sleep(0.15)  # SEC 요청 한도(초당 10회) 지키기
    missing = [c["ticker"] for c in companies if c["ticker"] not in ko]
    if missing:
        print(f"한글 설명 없는 종목 {len(missing)}개: {' '.join(missing)}", file=sys.stderr)
    OUT.write_text(json.dumps({
        "meta": {"asof": dt.date.today().isoformat(), "unit": "USD_million",
                 "source": "SEC EDGAR XBRL 공시(10-K·10-Q) 자동 추출, S&P 500 목록은 위키백과"},
        "companies": companies,
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"저장: {OUT} ({len(companies)}개)")


if __name__ == "__main__":
    main()
