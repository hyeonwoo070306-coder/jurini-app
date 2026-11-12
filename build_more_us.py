"""나스닥 100 중 S&P 500에 없는 회사 기본 카드 → jurini_app/assets/us_more.json

목록은 나스닥 공식 API, 회사번호(CIK)는 SEC 검색, 재무는 build_sp500.financials(SEC XBRL)를 그대로 쓴다.
해외 회사(ASML·ARM 등 20-F/40-F 공시)는 미국 회계기준(us-gaap) 숫자가 없어 재무가 비어 있을 수 있다.
나스닥 100 전체 티커 목록도 meta.nasdaq100에 넣어 앱이 '나스닥100' 표시를 붙인다.
실행: python build_more_us.py   (1분 이내, 분기마다 build_sp500.py 다음에)
"""
import json
import sys
import time
import datetime as dt

import build_sp500 as sp

OUT = "jurini_app/assets/us_more.json"
SKIP = {"GOOG", "SPCX"}  # GOOG는 GOOGL과 같은 회사, 스페이스X는 자세한 노트가 따로 있음
# 티커: (한글 이름, 섹터, 한 줄 설명)
KO = {
    "ASML": ("ASML", "정보기술", "반도체를 새기는 최첨단 노광 장비(EUV)를 세계에서 유일하게 만드는 네덜란드 회사"),
    "ARM": ("ARM", "정보기술", "스마트폰 칩 대부분에 쓰이는 반도체 설계도를 만들고 사용료를 받는 영국 회사"),
    "MSTR": ("스트래티지", "정보기술", "기업용 분석 소프트웨어를 팔면서 회사 돈 대부분을 비트코인에 투자하는 회사"),
    "ALNY": ("앨나일람 파마슈티컬스", "헬스케어", "병을 일으키는 유전자 신호를 꺼서 치료하는 RNA 치료제를 만드는 회사"),
    "MELI": ("메르카도리브레", "임의소비재", "중남미 최대 온라인 쇼핑몰이자 간편결제(메르카도파고) 회사"),
    "NBIS": ("네비우스 그룹", "정보기술", "AI 학습용 GPU 클라우드를 빌려주는 네덜란드 회사"),
    "SHOP": ("쇼피파이", "정보기술", "누구나 온라인 쇼핑몰을 쉽게 열 수 있게 해 주는 캐나다 소프트웨어 회사"),
    "CCEP": ("코카콜라 유로퍼시픽 파트너스", "필수소비재", "유럽·호주 등에서 코카콜라를 병에 담아 파는 세계 최대 병입 회사"),
    "PDD": ("PDD 홀딩스", "임의소비재", "중국 쇼핑앱 '핀둬둬'와 해외 쇼핑앱 '테무'를 운영하는 회사"),
    "RKLB": ("로켓랩", "산업재", "작은 위성을 우주로 쏘는 로켓과 위성 부품을 만드는 회사"),
    "TRI": ("톰슨로이터", "산업재", "로이터 통신과 법률·세무 전문가용 정보 서비스를 파는 캐나다 회사"),
    "FER": ("페로비알", "산업재", "도로·공항을 짓고 통행료·이용료를 받아 운영하는 스페인 인프라 회사"),
    "ALAB": ("아스테라 랩스", "정보기술", "AI 서버 안에서 칩끼리 데이터를 빠르게 주고받게 해 주는 연결 칩 회사"),
    "CRWV": ("코어위브", "정보기술", "엔비디아 GPU를 대량으로 갖추고 AI 회사에 빌려주는 클라우드 회사"),
}


def cik_of(ticker, hits):
    """SEC 검색 결과에서 티커가 정확히 같은 회사의 CIK(10자리). 없으면 None."""
    for h in hits:
        if ticker in (h["_source"].get("tickers") or "").split(", "):  # 한 회사가 티커 여러 개(MSTR, STRK…)일 수 있음
            return h["_id"].zfill(10)
    return None


def selfcheck():
    hits = [{"_id": "921114", "_source": {"tickers": "ARMP"}}, {"_id": "1973239", "_source": {"tickers": "ARM"}},
            {"_id": "1050446", "_source": {"tickers": "STRK, MSTR"}}]
    assert cik_of("ARM", hits) == "0001973239" and cik_of("MSTR", hits) == "0001050446" and cik_of("XYZ", hits) is None


def main():
    selfcheck()
    sp_tk = {c["ticker"] for c in json.load(open(sp.OUT, encoding="utf-8"))["companies"]}
    rows = json.loads(sp.fetch("https://api.nasdaq.com/api/quote/list-type/nasdaq100"))["data"]["data"]["rows"]
    ndx = sorted(r["symbol"].replace("/", ".") for r in rows)
    assert len(ndx) >= 95, len(ndx)  # 목록이 이상하면 저장하지 않는다
    out = []
    for r in rows:
        tk = r["symbol"].replace("/", ".")
        if tk in sp_tk or tk in SKIP:
            continue
        name_ko, sector, one = KO.get(tk, (r["companyName"], r.get("sector") or "", ""))
        if tk not in KO:
            print("한글 설명 없음(KO에 추가):", tk, file=sys.stderr)
        fin, bal = [], {}
        cik = cik_of(tk, json.loads(sp.fetch(f"https://efts.sec.gov/LATEST/search-index?keysTyped={tk}"))["hits"]["hits"])
        if cik:
            try:
                fin, bal = sp.financials(cik, tk)
            except Exception as e:  # 한 회사가 실패해도 나머지는 계속
                print(f"  ! {tk}: {e}", file=sys.stderr)
        out.append({"id": tk.lower(), "ticker": tk, "name_ko": name_ko, "name_en": r["companyName"], "sector": sector,
                    "one_liner": one, "financials": fin, "balance": bal})
        print(tk, cik, len(fin), "년")
        time.sleep(0.2)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"meta": {"asof": dt.date.today().isoformat(), "nasdaq100": ndx,
                            "source": "SEC EDGAR XBRL 공시 자동 추출, 나스닥 100 목록은 나스닥"},
                   "companies": out}, f, ensure_ascii=False, indent=1)
    print("저장:", OUT, len(out), "개")


if __name__ == "__main__":
    main()
