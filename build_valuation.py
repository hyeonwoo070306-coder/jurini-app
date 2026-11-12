# 매일 미국 장 마감 뒤 실행 (.github/workflows/daily.yml):
# 나스닥 종가 기준 시가총액으로 50개 회사의 시가총액·PER·PBR·배당수익률을 다시 계산해 docs/valuation.json에 쓴다.
# 이익·자본은 분기마다 build_top50_numbers.py → build.py로 바뀌므로, 여기서는 "주가가 변한 비율"만큼만 지표를 옮긴다.
import json
import os
from datetime import datetime, timedelta, timezone

from build_sp500 import fetch

BASE = "jurini_app/assets/companies.json"
OUT = "docs/valuation.json"
URL = "https://api.nasdaq.com/api/screener/stocks?tableonly=true&limit=10000&download=true"
MAX_DAY_MOVE = 0.5  # 하루에 시가총액이 50% 넘게 바뀌었다고 나오면 받은 숫자가 잘못된 것으로 보고 그날은 반영하지 않는다


def r1(x): return None if x is None else round(x, 1)


def revalue(c, row, prev):
    """c: 앱에 들어 있는 회사 데이터, row: 나스닥 한 줄, prev: 어제 결과(없으면 None). 이상하면 None."""
    try:
        mcap = float(row["marketCap"]) / 1e9
        price = float(row["lastsale"].replace("$", "").replace(",", ""))
    except (KeyError, ValueError, TypeError, AttributeError):
        return None
    ref = prev["market_cap_usd_b"] if prev else c["market_cap_usd_b"]
    if mcap <= 0 or price <= 0 or abs(mcap / ref - 1) > MAX_DAY_MOVE and prev:
        return None
    k = mcap / c["market_cap_usd_b"]
    # shortcut: 1~10위는 PER 기준일(11-06)과 시가총액 기준일(11-09)이 3일 달라 그만큼 오차가 있음. 다음 분기 build.py 갱신 때 사라짐.
    v, dps = c["valuation"], c["shareholder_return"].get("dividend_per_share")
    return {"market_cap_usd_b": round(mcap),
            "per": r1(v["per"] and v["per"] * k), "forward_per": r1(v["forward_per"] and v["forward_per"] * k),
            "pbr": r1(v["pbr"] and v["pbr"] * k),
            "dividend_yield": round(dps / price * 100, 2) if dps else None}


def selfcheck():
    c = {"market_cap_usd_b": 100, "valuation": {"per": 20.0, "forward_per": None, "pbr": 4.0},
         "shareholder_return": {"dividend_per_share": 2.0}}
    out = revalue(c, {"marketCap": "110000000000", "lastsale": "$50.00"}, None)
    assert out == {"market_cap_usd_b": 110, "per": 22.0, "forward_per": None, "pbr": 4.4, "dividend_yield": 4.0}, out
    assert revalue(c, {"marketCap": "300000000000", "lastsale": "$50"}, {"market_cap_usd_b": 100}) is None  # 하루 3배 → 버림
    assert revalue(c, {"marketCap": "NA", "lastsale": "$50"}, None) is None


def main():
    selfcheck()
    base = json.load(open(BASE, encoding="utf-8"))["companies"]
    prev = json.load(open(OUT, encoding="utf-8"))["companies"] if os.path.exists(OUT) else {}
    rows = {r["symbol"].replace("/", "."): r for r in json.loads(fetch(URL))["data"]["rows"]}
    out = {}
    for c in base:
        tk = c["ticker"]
        new = revalue(c, rows[tk], prev.get(tk)) if tk in rows else None
        if new:
            out[tk] = new
        elif tk in prev:
            out[tk] = prev[tk]  # 오늘 숫자를 못 믿으면 어제 숫자 유지
            print("어제 숫자 유지:", tk)
        else:
            print("건너뜀:", tk)
    for i, tk in enumerate(sorted(out, key=lambda t: -out[t]["market_cap_usd_b"]), 1):
        out[tk]["rank"] = i
    # shortcut: 미국 공휴일에도 돌면 전날 종가에 오늘 날짜가 붙음. 문제가 되면 휴장일 목록을 넣는다.
    # 미국 동부 시간의 날짜 (윈도우엔 시간대 데이터가 없어 UTC-5로 계산; 장 마감 뒤 실행이라 서머타임이어도 날짜는 같음)
    asof = (datetime.now(timezone.utc) - timedelta(hours=5)).date().isoformat()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"asof": asof, "source": "나스닥 종가 기준 시가총액으로 계산", "companies": out}, f, ensure_ascii=False, indent=1)
    print(asof, len(out), "개 회사")


if __name__ == "__main__":
    main()
