"""증권사 예측(컨센서스) EPS vs 실제 EPS → docs/surprise.json (+ 앱 복사본 jurini_app/assets/surprise.json)

대상: 자세한 노트가 있는 미국 50개. 출처: 나스닥 API(최근 4분기 어닝 서프라이즈, 다음 분기 예측).
매출·영업이익 예측치는 유료 데이터(FactSet·FnGuide 등)에만 있어 아직 넣지 않는다.
shortcut: 나스닥 데이터는 상업 사용 조건 확인 필요. 광고 출시 전에 허가된 데이터로 바꾼다.
매일 .github/workflows/daily.yml이 build_valuation.py 다음에 실행. 실행: python build_surprise.py (약 2분)
"""
import json
import os
import shutil
import sys
import time
from datetime import datetime

from build_sp500 import fetch

OUT = "docs/surprise.json"
COPY = "jurini_app/assets/surprise.json"
MONTHS = {m: i for i, m in enumerate(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}


def num(x):
    try:
        return float(str(x).replace("$", "").replace(",", ""))
    except (TypeError, ValueError):
        return None


def quarter(s):  # "Sep 2026" → "2026-09"
    m, y = s.split()
    return f"{y}-{MONTHS[m]:02d}"


def parse(surprise, forecast):
    rows = []
    for r in (surprise or {}).get("earningsSurpriseTable", {}).get("rows", []) or []:
        eps, est = num(r.get("eps")), num(r.get("consensusForecast"))
        if eps is None or est is None:
            continue
        d = datetime.strptime(r["dateReported"], "%m/%d/%Y").date().isoformat()
        pct = round((eps - est) / abs(est) * 100, 1) if est else None
        rows.append({"q": quarter(r["fiscalQtrEnd"]), "date": d, "eps": eps, "est": est, "pct": pct})
    nxt = None
    for r in (forecast or {}).get("quarterlyForecast", {}).get("rows", []) or []:
        est = num(r.get("consensusEPSForecast"))
        if est is not None:
            nxt = {"q": quarter(r["fiscalEnd"]), "est": est, "n": r.get("noOfEstimates")}
            break
    rows.sort(key=lambda x: x["q"])
    return {"rows": rows[-4:], "next": nxt}


def selfcheck():
    s = {"earningsSurpriseTable": {"rows": [
        {"fiscalQtrEnd": "Sep 2026", "dateReported": "11/2/2026", "eps": 2.05, "consensusForecast": "1.98", "percentageSurprise": "3.54"},
        {"fiscalQtrEnd": "Jun 2026", "dateReported": "7/30/2026", "eps": -0.5, "consensusForecast": "-0.4"},
        {"fiscalQtrEnd": "Mar 2026", "dateReported": "4/30/2026", "eps": "N/A", "consensusForecast": "1.0"}]}}
    f = {"quarterlyForecast": {"rows": [{"fiscalEnd": "Dec 2026", "consensusEPSForecast": 2.94, "noOfEstimates": 10}]}}
    got = parse(s, f)
    assert got["rows"] == [{"q": "2026-06", "date": "2026-07-30", "eps": -0.5, "est": -0.4, "pct": -25.0},
                           {"q": "2026-09", "date": "2026-11-02", "eps": 2.05, "est": 1.98, "pct": 3.5}], got
    assert got["next"] == {"q": "2026-12", "est": 2.94, "n": 10}
    assert parse(None, None) == {"rows": [], "next": None}


def main():
    selfcheck()
    prev = json.load(open(OUT, encoding="utf-8"))["companies"] if os.path.exists(OUT) else {}
    out, failed = {}, 0
    for c in json.load(open("jurini_app/assets/companies.json", encoding="utf-8"))["companies"]:
        tk = c["ticker"]
        sym = tk  # 버크셔(BRK.B)처럼 예측치가 없는 회사는 기록 없음으로 남는다
        try:
            s = json.loads(fetch(f"https://api.nasdaq.com/api/company/{sym}/earnings-surprise"))["data"]
            f = json.loads(fetch(f"https://api.nasdaq.com/api/analyst/{sym}/earnings-forecast"))["data"]
            got = parse(s, f)
            if not got["rows"] and tk in prev:
                got = prev[tk]  # 오늘 못 받으면 지난번 것 유지
            out[tk] = got
        except Exception as e:
            print(f"  ! {tk}: {e}", file=sys.stderr)
            failed += 1
            if tk in prev:
                out[tk] = prev[tk]
        time.sleep(0.5)
    if failed > 25:
        sys.exit(f"절반 넘게 실패({failed}개) — 저장하지 않음")
    data = {"asof": datetime.now().date().isoformat(), "source": "나스닥(증권사 예측 평균 EPS vs 실제 EPS)", "companies": out}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fp:
        json.dump(data, fp, ensure_ascii=False, indent=1)
    shutil.copy(OUT, COPY)
    print("저장:", OUT, len(out), "개 회사, 기록 있는 회사", sum(1 for v in out.values() if v["rows"]))


if __name__ == "__main__":
    main()
