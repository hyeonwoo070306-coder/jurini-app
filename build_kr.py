"""한국 상장회사(코스피·코스닥) 기본 카드 → jurini_app/assets/kr.json

한국거래소 KIND의 '상장법인목록'에서 회사명·종목코드·업종·주요제품·상장일을 받는다.
dart_key.txt(깃허브에 안 올라감)가 있으면 금융감독원 DART 오픈API에서 최근 3년 연간 재무(연결 우선)를 붙인다.
시가총액은 아직 없다.
실행: python build_kr.py   (약 1~2분, 분기마다 / 상장·상폐가 생기면 다시 실행)
"""
import html
import io
import json
import os
import re
import subprocess
import time
import zipfile
import xml.etree.ElementTree as ET
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


KEY_FILE = "dart_key.txt"
DART = "https://opendart.fss.or.kr/api/"
ACC = {"revenue": ("매출액", "영업수익", "수익(매출액)"), "operating_income": ("영업이익", "영업이익(손실)"),
       "net_income": ("당기순이익(손실)", "당기순이익"), "total_assets": ("자산총계",), "total_debt": ("부채총계",),
       "equity": ("자본총계",)}


def dart(path, key):
    r = subprocess.run(["curl", "-sfL", "-A", "jurini-study-app/0.1", DART + path + ("&" if "?" in path else "?") + "crtfc_key=" + key],
                       capture_output=True, timeout=120)
    if r.returncode:
        raise RuntimeError(f"DART 다운로드 실패({r.returncode}): {path}")  # 키는 메시지에 넣지 않는다
    return r.stdout


def eok(v):  # "1,234,000,000" 원 → 억 원 (없으면 None)
    v = (v or "").replace(",", "").strip()
    return round(int(v) / 1e8, 1) if re.fullmatch(r"-?\d+", v) else None


def pick(rows, year):
    """한 회사의 DART 행들 → 3년 재무 + 재무상태. 연결(CFS)이 있으면 연결, 없으면 별도(OFS)."""
    fs = "CFS" if any(r["fs_div"] == "CFS" for r in rows) else "OFS"
    got = {}
    for r in rows:
        if r["fs_div"] != fs:
            continue
        for k, names in ACC.items():
            if r["account_nm"] in names and k not in got:
                got[k] = (eok(r.get("bfefrmtrm_amount")), eok(r.get("frmtrm_amount")), eok(r.get("thstrm_amount")))
    if "revenue" not in got and "net_income" not in got:
        return None
    fin = []
    for i, y in enumerate((year - 2, year - 1, year)):
        rev, op, ni = (got.get(k, (None,) * 3)[i] for k in ("revenue", "operating_income", "net_income"))
        if rev is None and ni is None:
            continue
        fin.append({"label": f"FY{y}", "revenue": rev, "operating_income": op, "net_income": ni,
                    "operating_margin_pct": round(op / rev * 100, 1) if op is not None and rev else None})
    bal = {k: got.get(k, (None,) * 3)[2] for k in ("total_assets", "total_debt", "equity")}
    bal["asof"] = f"{year}년 말"
    return {"financials": fin, "balance": bal, "fs": "연결" if fs == "CFS" else "별도"}


def add_financials(cards, key, year):
    zf = zipfile.ZipFile(io.BytesIO(dart("corpCode.xml", key)))
    root = ET.fromstring(zf.read(zf.namelist()[0]))
    corp = {e.findtext("stock_code").strip(): e.findtext("corp_code") for e in root.iter("list") if (e.findtext("stock_code") or "").strip()}
    todo = [c for c in cards if c["ticker"] in corp]
    for y in (year, year - 1):  # 올해 사업보고서가 아직 없는 회사는 한 해 전 것으로
        for i in range(0, len(todo), 100):
            batch = todo[i:i + 100]
            d = json.loads(dart(f"fnlttMultiAcnt.json?corp_code={','.join(corp[c['ticker']] for c in batch)}&bsns_year={y}&reprt_code=11011", key))
            if d["status"] not in ("000", "013"):  # 013 = 자료 없음
                raise RuntimeError(f"DART 오류 {d['status']} {d.get('message')}")
            rows = {}
            for r in d.get("list", []):
                rows.setdefault(r["stock_code"], []).append(r)
            for c in batch:
                got = pick(rows.get(c["ticker"], []), y)
                if got:
                    c.update(got)
            time.sleep(0.3)
        todo = [c for c in todo if "financials" not in c]
        print(y, "년 사업보고서 반영 후 남은 회사", len(todo))


def selfcheck():
    page = "<tr><th>회사명</th></tr><tr><td>삼성전자</td><td>유가</td><td>005930</td><td>통신 및 방송 장비 제조업</td><td>휴대폰, 반도체 등</td><td>1975-06-11</td><td>12월</td></tr>"
    rows = parse(page)
    assert card(rows[0], "코스피") == {"id": "kr_005930", "ticker": "005930", "name_ko": "삼성전자", "market": "코스피",
                                      "sector": "통신 및 방송 장비 제조업", "one_liner": "휴대폰, 반도체", "listed": "1975-06-11",
                                      "fiscal_month": "12월"}, rows
    rows = [{"fs_div": "OFS", "account_nm": "매출액", "thstrm_amount": "300,000,000,000", "frmtrm_amount": "200,000,000,000", "bfefrmtrm_amount": "-"},
            {"fs_div": "CFS", "account_nm": "매출액", "thstrm_amount": "500,000,000,000", "frmtrm_amount": "400,000,000,000", "bfefrmtrm_amount": ""},
            {"fs_div": "CFS", "account_nm": "영업이익", "thstrm_amount": "-50,000,000,000", "frmtrm_amount": "40,000,000,000"},
            {"fs_div": "CFS", "account_nm": "부채총계", "thstrm_amount": "120,000,000,000"}]
    got = pick(rows, 2025)
    assert got["fs"] == "연결" and [f["label"] for f in got["financials"]] == ["FY2024", "FY2025"], got
    assert got["financials"][1] == {"label": "FY2025", "revenue": 5000.0, "operating_income": -500.0, "net_income": None,
                                    "operating_margin_pct": -10.0}, got
    assert got["balance"]["total_debt"] == 1200.0 and eok("-") is None


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
    source = "한국거래소 KIND 상장법인목록"
    if os.path.exists(KEY_FILE):
        add_financials(out, open(KEY_FILE).read().strip(), date.today().year - 1)
        source += " · 금융감독원 DART 사업보고서(연결 우선, 단위 억 원)"
    # 최근 매출이 큰 회사부터 (시가총액이 없어서 매출로 대신 줄 세움)
    out.sort(key=lambda c: (-(c["financials"][-1]["revenue"] or 0) if c.get("financials") else 1, c["name_ko"]))
    meta = {"source": source, "asof": date.today().isoformat(), "count": len(out), "unit": "억 원"}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "companies": out}, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
