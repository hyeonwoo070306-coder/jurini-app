"""Top 50 상세 기업의 숫자 받기 → top50_numbers.json (build.py가 읽음)

- 재무(3개 회계연도 + 최근 12개월), 현금·부채, 자본, 배당: SEC 공시(XBRL)
- 시가총액·주가: 나스닥 스크리너 (전날 종가)
- 배당 기록: 야후 파이낸스 (최근 정기배당 × 1년 지급 횟수)
- PER·PBR·ROE·배당수익률·배당성향: 위 숫자로 직접 계산 (선행 PER은 예상치라 넣지 않음)

실행: python build_top50_numbers.py   (약 3분)
"""
import datetime as dt
import json
import time
from pathlib import Path

import build_sp500 as sp

ROOT = Path(__file__).parent
OUT = ROOT / "top50_numbers.json"
TICKERS = ["BRK.B", "WMT", "JPM", "AMD", "MU", "V", "JNJ", "XOM", "MA", "ABBV", "COST", "CVX", "KO", "PLTR",
           "PG", "CSCO", "MRK", "ORCL", "UNH", "HD", "BAC", "GE", "INTC", "PM", "AMAT", "MS", "LRCX", "CAT",
           "PANW", "TXN", "TMO", "RTX", "NFLX", "GS", "WFC", "AMGN", "LIN", "ANET", "CRWD", "IBM"]
BANKS = {"JPM", "BAC", "MS", "GS", "WFC", "BRK.B"}  # 예금·보험금이 본업이라 현금/부채 비교가 의미 없음

sp.TAGS.update({
    "securities": ["MarketableSecuritiesCurrent", "AvailableForSaleSecuritiesDebtSecuritiesCurrent", "ShortTermInvestments"],
    "securities_lt": ["MarketableSecuritiesNoncurrent", "AvailableForSaleSecuritiesDebtSecuritiesNoncurrent"],
    "short_debt": ["CommercialPaper", "ShortTermBorrowings"],
    "debt_total": ["LongTermDebt"],
    "debt_nc": ["LongTermDebtNoncurrent", "LongTermDebtAndCapitalLeaseObligations", "LongTermNotesPayable",
                "SeniorLongTermNotes"],
    "debt_current": ["LongTermDebtCurrent", "LongTermDebtAndCapitalLeaseObligationsCurrent", "NotesPayableCurrent"],
    "equity": ["StockholdersEquity", "StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest"],
})
FLOW = ("revenue", "operating_income", "net_income", "ocf", "capex")


def entries(facts, key, unit="USD"):
    for tag in sp.TAGS[key]:
        es = facts.get(tag, {}).get("units", {}).get(unit, [])
        if es:
            yield tag, es


def ttm(facts, key, fy_end):
    """최근 12개월 = 마지막 회계연도 + 올해 누적(10-Q) - 작년 같은 기간 누적. 새 분기가 없으면 None."""
    for _, es in entries(facts, key):
        ytd = [e for e in es if e.get("form", "").startswith("10-Q") and "start" in e and e["end"] > fy_end
               and 80 <= sp.days(e) <= 290]
        if not ytd:
            continue
        cur = max(ytd, key=lambda e: (e["end"], sp.days(e)))
        prev_end = dt.date.fromisoformat(cur["end"]) - dt.timedelta(days=364)
        prev = [e for e in es if "start" in e and abs(sp.days(e) - sp.days(cur)) <= 10
                and abs((dt.date.fromisoformat(e["end"]) - prev_end).days) <= 10]
        fy = sp.annual(facts, key).get(fy_end)
        if prev and fy is not None:
            return cur["end"], fy + cur["val"] - max(prev, key=lambda e: e["filed"])["val"]
    return None


def numbers(cik, ticker, mcap):
    for attempt in range(3):  # SEC가 가끔 빈 응답을 줘서 다시 시도
        facts = sp.company_facts(cik, ticker)
        s = {k: sp.annual(facts, k) for k in FLOW}
        ends = sorted(set(s["revenue"]) | set(s["net_income"]), reverse=True)[:3][::-1]
        if ends:
            break
        time.sleep(3)
    else:
        raise RuntimeError(f"{ticker}: SEC 재무 숫자를 못 찾음")
    m = sp.m
    rows = [{"label": f"FY{e[:4]}", "end_date": e, **{k: m(s[k].get(e)) for k in FLOW}} for e in ends]
    if ticker in BANKS:  # 은행 현금흐름은 예금·대출 흐름이라 잉여현금 개념이 맞지 않음
        for r in rows:
            r["ocf"] = r["capex"] = None
    t = {k: ttm(facts, k, ends[-1]) for k in FLOW}
    if t["revenue"] or t["net_income"]:
        end = (t["revenue"] or t["net_income"])[0]
        rows.append({"label": "최근 12개월(TTM)", "end_date": end,
                     **{k: m(t[k][1]) if t[k] and not (ticker in BANKS and k in ("ocf", "capex")) else None for k in FLOW}})
    last = rows[-1]

    def val(key):
        e = sp.latest_instant(facts, key)
        return e["val"] if e else 0
    eq = sp.latest_instant(facts, "equity")
    if ticker in BANKS:
        balance = {"asof": eq and eq["end"], "cash_and_investments": None, "total_debt": None}
    else:
        cash = val("cash") + val("securities") + val("securities_lt")
        debt = (val("debt_total") or val("debt_nc") + val("debt_current")) + val("short_debt")
        balance = {"asof": eq and eq["end"], "cash_and_investments": m(cash), "total_debt": m(debt)}

    ni = last["net_income"]
    equity = m(eq["val"]) if eq else None
    mc = mcap / 1e6  # 백만 달러
    return {
        "financials": rows, "balance": balance,
        "market_cap_usd_b": round(mcap / 1e9),
        "valuation": {
            "per": round(mc / ni, 1) if ni and ni > 0 else None,
            "forward_per": None,
            "pbr": round(mc / equity, 1) if equity and equity > 0 else None,
            "roe": round(ni / equity * 100, 1) if ni and equity and equity > 0 else None,
        },
    }


def dividends(ticker):
    """야후 배당 기록 → (1년 배당금, 지급 주기). 1년 배당금 = 최근 정기배당 × 1년 지급 횟수.
    shortcut: 연속 배당 증가 연수는 분할·특별배당 때문에 자동 계산이 자주 틀려서 넣지 않는다."""
    sym = ticker.replace(".", "-")
    r = json.loads(sp.fetch(f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?range=5y&interval=1mo&events=div"))
    ev = (r["chart"]["result"][0].get("events") or {}).get("dividends", {})
    pays = sorted((dt.date.fromtimestamp(v["date"]), v["amount"]) for v in ev.values())
    today = dt.date.today()
    recent = [a for d, a in pays if (today - d).days <= 730]
    if not recent or (today - pays[-1][0]).days > 400:  # 2년 넘게 안 줬으면 배당 없음
        return None, None
    freq = max(1, round(len(recent) / 2))
    med = sorted(recent)[len(recent) // 2]
    last = pays[-1][1] if pays[-1][1] <= med * 2 else med  # 마지막이 특별배당이면 평소 금액으로
    return round(last * freq, 2), {1: "연 1회", 2: "반기", 4: "분기", 12: "월"}.get(freq, f"연 {freq}회")


def main():
    screener = json.loads(sp.fetch("https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&download=true"))
    rows = {r["symbol"].replace("/", "."): r for r in screener["data"]["rows"]}
    ciks = {c["ticker"]: c["cik"] for c in sp.sp500_list()}
    out = {"asof": dt.date.today().isoformat(), "companies": {}}
    for i, tk in enumerate(TICKERS, 1):
        r = rows[tk]
        price = float(r["lastsale"].replace("$", "").replace(",", ""))
        n = numbers(ciks[tk], tk, float(r["marketCap"]))
        dps, freq = dividends(tk)
        ni = n["financials"][-1]["net_income"]
        shares_m = float(r["marketCap"]) / price / 1e6
        n["shareholder_return"] = {
            "dividend_per_share": dps,
            "dividend_yield": round(dps / price * 100, 2) if dps else None,
            "payout_ratio": round(dps * shares_m / ni * 100, 1) if dps and ni and ni > 0 else None,
            "dividend_growth_years": None,
            "frequency": freq,
        }
        n["price"] = price
        out["companies"][tk] = n
        print(f"{i}/{len(TICKERS)} {tk} 시총 {n['market_cap_usd_b']}B PER {n['valuation']['per']}", flush=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print("저장:", OUT)


if __name__ == "__main__":
    main()
