# -*- coding: utf-8 -*-
"""미국 시총 Top 50 기업 데이터 -> JSON + Markdown 생성
1~10위: 이 파일에 직접 쓴 데이터. 11~50위: 글은 companies_top50.py, 숫자는 top50_numbers.json
(숫자를 새로 받으려면 먼저 python build_top50_numbers.py)"""
import json, os
from companies_top50 import more

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "jurini_app", "assets")  # 앱이 읽는 JSON
MD_OUT = ROOT  # 읽기용 Markdown
MCAP_ASOF = "2026-11-09"
VAL_ASOF = "2026-11-06"
SRC_MCAP = "finhacker.cz 미국 시가총액 순위 (2026-11-09 종가)"
SRC_FIN = "stockanalysis.com (S&P Global Market Intelligence 데이터), 2026-11-08 조회"

def P(label, end, rev, op, ni, ocf, capex):
    return {"label": label, "end_date": end, "revenue": rev, "operating_income": op,
            "net_income": ni, "operating_cash_flow": ocf, "capex": capex, "free_cash_flow": ocf - capex}

companies = [
# ---------------------------------------------------------------- 1 APPLE
{
 "id": "aapl", "rank": 1, "name_ko": "애플", "name_en": "Apple Inc.", "ticker": "AAPL", "exchange": "NASDAQ",
 "sector": "정보기술 / 소비자 전자기기", "market_cap_usd_b": 5094,
 "one_liner": "아이폰을 팔고, 그 아이폰 위에서 앱스토어·아이클라우드 같은 구독 서비스로 계속 돈을 버는 회사",
 "invest_points": [
   "전 세계 20억 대가 넘는 활성 기기가 서비스 매출(앱스토어, 아이클라우드, 애플뮤직 등)을 꾸준히 만들어 줌",
   "2026 회계연도 잉여현금흐름(FCF) 약 1,360억 달러, 이 현금으로 자사주 매입과 배당을 꾸준히 실행",
   "2026 회계연도 매출이 15% 늘며 역대 최고 기록, 아이폰 판매가 다시 크게 성장"],
 "cautions": [
   "매출의 절반 이상이 아이폰 한 제품에서 나옴",
   "앱스토어 수수료·구글 검색 계약 등을 두고 미국·유럽에서 규제와 소송이 진행 중",
   "PER 약 38배로, 성장 속도에 비해 주가가 비싸다는 평가가 있음"],
 "business": "아이폰, 맥(컴퓨터), 아이패드, 애플워치·에어팟 같은 기기를 설계해 판매하고, 그 기기에서 쓰는 앱스토어·아이클라우드·애플뮤직·애플페이 등 서비스로 반복 매출을 올림. 직접 공장을 운영하지 않고 생산은 폭스콘 같은 협력사에 맡김.",
 "revenue_mix": {"fiscal_year": "FY2026 (2026-09-26 종료)",
   "by_segment": [["아이폰", 53.1], ["서비스", 25.8], ["맥", 7.9], ["웨어러블·홈·액세서리", 7.4], ["아이패드", 5.8]],
   "by_region": [["미주", 41.4], ["유럽", 26.6], ["중화권", 17.2], ["기타 아시아태평양", 8.3], ["일본", 6.5]]},
 "growth_drivers": ["서비스 매출 성장 (이익률이 하드웨어보다 높음)", "아이폰 교체 수요와 기기 내 AI 기능(애플 인텔리전스)", "인도 등 신흥시장 확대"],
 "moat": "기기·운영체제(iOS)·서비스가 하나로 묶인 '생태계' 덕분에 한 번 쓰면 다른 회사 제품으로 옮기기 어려움(전환비용). 강력한 브랜드 가치로 비싼 가격에도 팔림.",
 "competitors": ["삼성전자", "구글(안드로이드·픽셀)", "샤오미", "마이크로소프트(PC)"],
 "financials": [P("FY2024", "2024-09-28", 391035, 123216, 93736, 118254, 9447),
                P("FY2025", "2025-09-27", 416161, 133050, 112010, 111482, 12715),
                P("FY2026", "2026-09-26", 478834, 158063, 132175, 145097, 9041)],
 "financial_note": "2026 회계연도 수치는 애플이 공시한 2026 회계연도 4분기 실적 보도자료(SEC 8-K) 기준.",
 "balance": {"asof": "2026-09-26", "cash_and_investments": 136935, "total_debt": 80111},
 "valuation": {"per": 38.1, "forward_per": 36.4, "pbr": 44.4, "roe": 142.3,
   "comment": "PER이 미국 대형주 평균(대략 20배 초반)보다 높은 편. 자사주를 많이 사서 자본이 작아졌기 때문에 PBR과 ROE가 매우 크게 나옴."},
 "shareholder_return": {"dividend_per_share": 1.08, "dividend_yield": 0.32, "payout_ratio": 12.0, "dividend_growth_years": 14,
   "frequency": "분기", "buyback": "매년 자사주를 대규모로 매입해 주식 수가 1년간 약 1.9% 줄어듦"},
 "risks": ["아이폰 의존도: 신제품 반응이 약하면 실적 전체가 흔들림",
           "중국: 매출 약 17%를 차지하는 동시에 생산 기지라 미·중 갈등에 노출",
           "규제: 앱스토어 수수료, 구글과의 기본 검색 계약에 대한 반독점 판결 영향",
           "AI 경쟁: 생성형 AI 기능에서 경쟁사보다 늦었다는 평가"],
 "upcoming": ["2027년 1월 말: 2027 회계연도 1분기(연말 성수기) 실적 발표 (예상)", "2027년 6월: 개발자 회의(WWDC)", "2027년 9월: 신형 아이폰 공개 (예상)"],
 "terms": ["market_cap", "ticker", "fiscal_year", "revenue", "operating_income", "operating_margin", "net_income",
           "operating_cash_flow", "capex", "fcf", "per", "forward_per", "pbr", "roe", "dividend_yield", "payout_ratio",
           "buyback", "moat", "switching_cost", "ecosystem", "services_revenue", "antitrust"],
},
# ---------------------------------------------------------------- 2 NVIDIA
{
 "id": "nvda", "rank": 2, "name_ko": "엔비디아", "name_en": "NVIDIA Corporation", "ticker": "NVDA", "exchange": "NASDAQ",
 "sector": "정보기술 / 반도체", "market_cap_usd_b": 4310,
 "one_liner": "AI를 학습시키고 돌리는 데 꼭 필요한 '두뇌 칩(GPU)'을 만들어 전 세계 데이터센터에 파는 회사",
 "invest_points": [
   "AI 데이터센터용 GPU 시장에서 압도적 1위, 매출이 3년 만에 약 5배로 성장",
   "영업이익률 60%대로 대형 기업 중 최고 수준의 수익성",
   "칩 + 소프트웨어(CUDA) + 네트워크 장비를 한 번에 파는 구조로 경쟁자가 따라오기 어려움"],
 "cautions": [
   "마이크로소프트·아마존·구글·메타 등 소수 빅테크의 투자 규모에 실적이 크게 좌우됨",
   "미국의 대중국 반도체 수출 규제로 중국 매출이 제한됨",
   "고객사들이 자체 AI 칩(구글 TPU 등)을 만들고 있어 장기 경쟁 심화 가능"],
 "business": "그래픽처리장치(GPU)를 설계하는 반도체 회사. 원래 게임용 그래픽카드로 유명했지만 지금은 매출 대부분이 AI 데이터센터에서 나옴. 공장 없이 설계만 하고 생산은 대만 TSMC에 맡기는 '팹리스' 회사.",
 "revenue_mix": {"fiscal_year": "FY2026 (2026-01-25 종료)",
   "by_segment": [["컴퓨팅·네트워킹(데이터센터)", 89.6], ["그래픽(게임·PC)", 10.4]],
   "by_region": [["미국", 69.3], ["대만", 19.6], ["중국(홍콩 포함)", 9.1], ["기타", 2.0]],
   "note": "지역은 제품이 최종 사용되는 곳이 아니라 대금을 청구한 고객의 위치 기준."},
 "growth_drivers": ["빅테크·AI 기업들의 데이터센터 투자 확대", "신형 GPU 세대 교체(블랙웰 → 루빈)", "국가 단위 AI 인프라(소버린 AI) 구축 수요"],
 "moat": "GPU 성능뿐 아니라 개발자들이 15년 넘게 써 온 CUDA 소프트웨어 생태계가 핵심. AI 개발 도구가 대부분 엔비디아 칩에 맞춰져 있어 다른 칩으로 바꾸기 어려움.",
 "competitors": ["AMD", "브로드컴(맞춤형 AI 칩)", "구글(TPU)", "인텔"],
 "financials": [P("FY2024", "2024-01-28", 60922, 32972, 29760, 28090, 1069),
                P("FY2025", "2025-01-26", 130497, 81453, 72880, 64089, 3236),
                P("FY2026", "2026-01-25", 215938, 130387, 120067, 102718, 6042),
                P("최근 12개월(TTM)", "2026-07-26", 302970, 197579, 192880, 134360, 7354)],
 "financial_note": "회계연도가 1월 말에 끝남. 예: FY2026 = 2025년 2월~2026년 1월.",
 "balance": {"asof": "2026-07-26", "cash_and_investments": 62469, "total_debt": 38860},
 "valuation": {"per": 23.6, "forward_per": 15.4, "pbr": 19.7, "roe": 117.2,
   "comment": "이익이 빠르게 늘어 PER은 시장 평균과 비슷하고, 선행 PER은 오히려 낮은 편. 다만 이 낮은 선행 PER은 '이익이 계속 크게 늘 것'이라는 예상이 맞을 때만 의미가 있음."},
 "shareholder_return": {"dividend_per_share": 1.00, "dividend_yield": 0.54, "payout_ratio": 6.6, "dividend_growth_years": 2,
   "frequency": "분기", "buyback": "자사주 매입으로 주식 수가 1년간 약 1% 감소. 2026년 배당을 크게 늘렸지만 배당수익률은 여전히 낮음"},
 "risks": ["AI 투자 사이클: 빅테크가 데이터센터 투자를 줄이면 매출이 급감할 수 있음",
           "고객 집중: 소수 대형 고객 비중이 높음",
           "수출 규제: 미·중 갈등으로 중국 판매 제한",
           "공급망: 생산을 대만 TSMC 한 곳에 크게 의존"],
 "upcoming": ["2026-11-17: 2027 회계연도 3분기 실적 발표", "2027년 3월: 개발자 행사 GTC (신제품 발표)"],
 "terms": ["market_cap", "gpu", "semiconductor", "fabless", "data_center", "fiscal_year", "revenue", "operating_margin",
           "net_income", "fcf", "capex", "per", "forward_per", "pbr", "roe", "dividend_yield", "buyback", "moat",
           "export_control", "customer_concentration", "ttm"],
},
# ---------------------------------------------------------------- 3 MICROSOFT
{
 "id": "msft", "rank": 3, "name_ko": "마이크로소프트", "name_en": "Microsoft Corporation", "ticker": "MSFT", "exchange": "NASDAQ",
 "sector": "정보기술 / 소프트웨어·클라우드", "market_cap_usd_b": 4049,
 "one_liner": "윈도우와 오피스(엑셀·워드)를 구독으로 팔고, 기업들에게 클라우드(애저)를 빌려주는 회사",
 "invest_points": [
   "오피스365·애저 등 매출 대부분이 매달·매년 반복되는 구독형이라 실적이 안정적",
   "클라우드 '애저'가 AI 수요로 빠르게 성장, 매출 성장률 연 18% 수준",
   "20년 연속 배당을 늘려 온 대표적인 배당성장주"],
 "cautions": [
   "AI 데이터센터 투자(CapEx)가 1년에 1,300억 달러 이상으로 급증해 잉여현금흐름이 줄고 있음",
   "오픈AI와의 협력 관계 변화가 AI 전략에 영향을 줄 수 있음",
   "클라우드 시장에서 아마존(AWS)·구글과 치열한 경쟁"],
 "business": "개인과 기업이 쓰는 소프트웨어(윈도우, 오피스, 팀즈), 클라우드 서비스(애저), 게임(엑스박스, 액티비전 블리자드), 검색(빙), 비즈니스 SNS(링크드인)를 운영. 코파일럿이라는 AI 비서를 여러 제품에 넣고 있음.",
 "revenue_mix": {"fiscal_year": "FY2026 (2026-06-30 종료)",
   "by_segment": [["생산성·비즈니스(오피스, 링크드인 등)", 42.2], ["인텔리전트 클라우드(애저 등)", 41.5], ["개인 컴퓨팅(윈도우, 엑스박스 등)", 16.3]],
   "by_region": [["미국", 51.5], ["기타 국가", 48.5]]},
 "growth_drivers": ["애저 클라우드와 AI 서비스 수요", "코파일럿 등 AI 기능을 넣은 오피스 구독료 인상", "기업들의 클라우드 전환"],
 "moat": "전 세계 회사들이 오피스·윈도우·팀즈를 업무 표준으로 쓰고 있어 바꾸기 매우 어려움. 기존 기업 고객 관계를 바탕으로 클라우드·AI도 함께 판매.",
 "competitors": ["아마존(AWS)", "구글(클라우드, 워크스페이스)", "오라클", "세일즈포스"],
 "financials": [P("FY2024", "2024-06-30", 245122, 109433, 88136, 118548, 44477),
                P("FY2025", "2025-06-30", 281724, 128528, 101832, 136162, 64551),
                P("FY2026", "2026-06-30", 331839, 155237, 133749, 182935, 115948),
                P("최근 12개월(TTM)", "2026-09-30", 346445, 163191, 142631, 195878, 135921)],
 "financial_note": "회계연도가 6월 30일에 끝남. 예: FY2026 = 2025년 7월~2026년 6월.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 64509, "total_debt": 133931},
 "valuation": {"per": 28.5, "forward_per": 26.3, "pbr": 8.6, "roe": 34.2,
   "comment": "시장 평균보다 약간 비싼 편이지만, 안정적인 구독 매출과 높은 이익률 덕분에 꾸준히 이 정도 프리미엄을 받아 왔음."},
 "shareholder_return": {"dividend_per_share": 3.92, "dividend_yield": 0.72, "payout_ratio": 20.5, "dividend_growth_years": 20,
   "frequency": "분기", "buyback": "자사주 매입을 하지만 규모는 크지 않음 (주식 수 1년간 약 0.2% 감소)"},
 "risks": ["AI 투자 회수: 막대한 데이터센터 투자가 기대만큼 매출로 돌아오지 않을 위험",
           "현금흐름 압박: 투자 증가로 잉여현금흐름이 3년 연속 감소",
           "경쟁: 클라우드·AI 시장의 가격 경쟁",
           "규제: 유럽 등에서 팀즈 끼워팔기, 클라우드 라이선스 관련 조사"],
 "upcoming": ["2027년 1월 말: 2027 회계연도 2분기 실적 발표 (예상)", "매 분기: 애저 성장률 발표가 주가에 큰 영향"],
 "terms": ["market_cap", "subscription", "cloud", "fiscal_year", "revenue", "operating_margin", "net_income",
           "operating_cash_flow", "capex", "fcf", "per", "forward_per", "pbr", "roe", "dividend_yield", "payout_ratio",
           "dividend_growth_stock", "moat", "switching_cost", "ttm"],
},
# ---------------------------------------------------------------- 4 ALPHABET
{
 "id": "googl", "rank": 4, "name_ko": "알파벳(구글)", "name_en": "Alphabet Inc.", "ticker": "GOOGL", "exchange": "NASDAQ",
 "sector": "커뮤니케이션 서비스 / 인터넷", "market_cap_usd_b": 3542,
 "one_liner": "구글 검색과 유튜브에 광고를 붙여 돈을 벌고, 클라우드와 AI(제미나이)로 영역을 넓히는 회사",
 "invest_points": [
   "전 세계 검색 시장 약 90%를 차지하는 구글 검색이 강력한 현금 창출원",
   "구글 클라우드가 AI 수요로 빠르게 성장 중",
   "현금이 부채보다 훨씬 많은 탄탄한 재무구조 (순현금 약 1,150억 달러)"],
 "cautions": [
   "AI 챗봇이 검색을 대체하면 핵심 광고 사업이 약해질 수 있음",
   "미국 법무부 반독점 소송에서 검색 독점 판결을 받아 사업 방식 제한 가능",
   "AI 투자(CapEx)가 급증해 잉여현금흐름이 크게 줄었음"],
 "business": "구글 검색, 유튜브, 안드로이드, 크롬, 지메일, 구글 지도 등 무료 서비스로 사용자를 모으고 광고로 돈을 범. 구글 클라우드, 유튜브 프리미엄 같은 구독, 픽셀폰 판매, 자율주행(웨이모) 같은 미래 사업(아더 베츠)도 운영.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["구글 검색 광고", 55.7], ["구글 클라우드", 14.6], ["구독·플랫폼·기기", 11.9], ["유튜브 광고", 10.0], ["구글 네트워크 광고", 7.4], ["아더 베츠(웨이모 등)", 0.4]],
   "by_region": [["미국", 48.2], ["유럽·중동·아프리카", 29.1], ["아시아태평양", 16.8], ["기타 미주", 5.9]]},
 "growth_drivers": ["구글 클라우드와 자체 AI 칩(TPU)·제미나이 모델", "유튜브 광고와 구독", "자율주행 택시 웨이모 확장"],
 "moat": "검색·유튜브·안드로이드·크롬으로 수십억 명의 데이터와 사용 습관을 확보. 자체 AI 모델과 자체 AI 칩까지 모두 가진 몇 안 되는 회사.",
 "competitors": ["마이크로소프트", "메타(광고)", "아마존(광고·클라우드)", "오픈AI(AI 검색)"],
 "financials": [P("FY2023", "2023-12-31", 307394, 84293, 73795, 101746, 32251),
                P("FY2024", "2024-12-31", 350018, 112390, 100118, 125299, 52535),
                P("FY2025", "2025-12-31", 402836, 129039, 132170, 164713, 91447),
                P("최근 12개월(TTM)", "2026-09-30", 471098, 156976, 235694, 179551, 159804)],
 "financial_note": "최근 12개월 순이익(2,357억 달러)이 영업이익보다 훨씬 큰 이유는 보유한 투자 지분(비상장·상장 기업 지분)의 가치 상승으로 약 1,290억 달러의 일회성 이익이 생겼기 때문. 본업 실력은 영업이익으로 보는 것이 정확.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 265098, "total_debt": 150331},
 "valuation": {"per": 14.9, "forward_per": 20.7, "pbr": 5.3, "roe": 44.3,
   "comment": "PER 14.9배는 일회성 투자이익 때문에 순이익이 부풀려져 낮아 보이는 것. 앞으로의 예상 이익 기준인 선행 PER(약 21배)이 더 현실적이며 시장 평균과 비슷한 수준."},
 "shareholder_return": {"dividend_per_share": 0.88, "dividend_yield": 0.31, "payout_ratio": 4.6, "dividend_growth_years": 1,
   "frequency": "분기", "buyback": "2024년부터 배당 시작. 자사주 매입도 하지만 최근 1년은 주식 수가 약 0.3% 늘어남"},
 "risks": ["AI 검색 경쟁: 챗GPT 등 AI 서비스가 검색 광고 시장을 잠식할 위험",
           "반독점: 미국·유럽의 검색·광고 기술 독점 소송 결과",
           "투자 부담: AI 데이터센터 투자로 잉여현금흐름 급감",
           "광고 경기: 경기가 나빠지면 기업들이 광고비부터 줄임"],
 "upcoming": ["2027년 2월 초: 2026년 4분기 실적 발표 (예상)", "반독점 소송 항소 결과"],
 "terms": ["market_cap", "advertising_revenue", "cloud", "revenue", "operating_income", "operating_margin", "net_income",
           "one_time_gain", "operating_cash_flow", "capex", "fcf", "net_cash", "per", "forward_per", "pbr", "roe",
           "dividend_yield", "dilution", "moat", "antitrust", "ttm"],
},
# ---------------------------------------------------------------- 5 AMAZON
{
 "id": "amzn", "rank": 5, "name_ko": "아마존", "name_en": "Amazon.com, Inc.", "ticker": "AMZN", "exchange": "NASDAQ",
 "sector": "임의소비재 / 전자상거래·클라우드", "market_cap_usd_b": 2885,
 "one_liner": "세계 최대 온라인 쇼핑몰이면서, 돈은 클라우드(AWS)와 광고에서 더 많이 버는 회사",
 "invest_points": [
   "클라우드 1위 AWS가 매출의 약 18%지만 영업이익의 큰 부분을 책임짐",
   "쇼핑몰 방문자를 활용한 광고 매출이 빠르게 성장 (이익률 높음)",
   "프라임 멤버십으로 고객을 묶어두는 강력한 생태계"],
 "cautions": [
   "AI 데이터센터 투자(최근 12개월 2,150억 달러)가 영업현금흐름보다 커서 잉여현금흐름이 마이너스",
   "투자 자금 마련으로 부채가 1년도 안 돼 약 1,780억 → 3,050억 달러로 급증",
   "배당이 없고, 소매 사업은 이익률이 낮음"],
 "business": "온라인 쇼핑몰(직접 판매 + 외부 판매자 입점), 프라임 구독(배송·영상·음악), 클라우드 서비스 AWS, 쇼핑몰 광고, 홀푸드 같은 오프라인 매장을 운영. 물류센터와 배송망을 직접 보유.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["온라인 직접판매", 37.6], ["외부 판매자 서비스(수수료·물류)", 24.0], ["AWS 클라우드", 18.0], ["광고", 9.6], ["구독(프라임 등)", 6.9], ["오프라인 매장", 3.1], ["기타", 0.8]],
   "by_region": [["북미", 59.5], ["해외", 22.6], ["AWS(지역 구분 없음)", 18.0]]},
 "growth_drivers": ["AWS의 AI 클라우드 수요", "광고 사업 확대 (프라임 비디오 광고 포함)", "물류 자동화로 소매 이익률 개선"],
 "moat": "규모의 경제: 거대한 물류망과 구매력 덕분에 싸고 빠르게 배송. AWS는 기업들의 IT 시스템이 깊이 연결돼 있어 다른 클라우드로 옮기기 어려움.",
 "competitors": ["마이크로소프트(애저)", "구글(클라우드)", "월마트", "쿠팡·테무·쉬인 등 이커머스"],
 "financials": [P("FY2023", "2023-12-31", 574785, 36852, 30425, 84946, 52729),
                P("FY2024", "2024-12-31", 637959, 68593, 59248, 115877, 82999),
                P("FY2025", "2025-12-31", 716924, 79975, 77670, 139514, 131819),
                P("최근 12개월(TTM)", "2026-09-30", 797455, 104366, 134779, 168300, 215192)],
 "financial_note": "최근 12개월 순이익이 영업이익보다 큰 것은 보유 투자 지분의 가치 상승 등 영업 외 이익이 포함됐기 때문. 잉여현금흐름은 설비투자가 커서 마이너스.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 114226, "total_debt": 304841},
 "valuation": {"per": 21.0, "forward_per": 26.2, "pbr": 4.6, "roe": 27.4,
   "comment": "PER은 시장 평균 수준이지만 영업 외 이익이 섞여 있음. 선행 PER(약 26배)이 본업 기준에 더 가까움. 잉여현금흐름이 마이너스라 현금 기준으로는 비싸 보일 수 있음."},
 "shareholder_return": {"dividend_per_share": None, "dividend_yield": None, "payout_ratio": None, "dividend_growth_years": None,
   "frequency": "배당 없음", "buyback": "자사주 매입 없음. 직원 주식보상으로 주식 수가 1년간 약 0.8% 늘어남(희석)"},
 "risks": ["투자 부담: AI 인프라 투자가 수익으로 이어지지 않으면 부채만 남을 위험",
           "부채 증가: 1년 사이 총부채가 크게 늘어 금리 부담 증가",
           "규제: 미국 FTC의 반독점 소송(판매자 대우, 가격 정책)",
           "경기: 소비가 줄면 쇼핑 매출 둔화"],
 "upcoming": ["2027년 2월 초: 2026년 4분기 실적 발표 (예상)", "매년 7월: 프라임 데이 (소매 실적 지표)"],
 "terms": ["market_cap", "ecommerce", "cloud", "advertising_revenue", "subscription", "revenue", "operating_income",
           "operating_margin", "net_income", "operating_cash_flow", "capex", "fcf", "net_debt", "per", "forward_per", "pbr",
           "roe", "dilution", "economies_of_scale", "moat", "antitrust", "ttm"],
},
# ---------------------------------------------------------------- 6 SPACEX
{
 "id": "spcx", "rank": 6, "name_ko": "스페이스X", "name_en": "Space Exploration Technologies Corp. (SpaceX)", "ticker": "SPCX", "exchange": "NASDAQ",
 "sector": "산업재 / 우주항공·통신", "market_cap_usd_b": 1930,
 "one_liner": "재사용 로켓으로 위성을 쏘아 올리고, 그 위성으로 전 세계에 인터넷(스타링크)을 파는 일론 머스크의 회사",
 "invest_points": [
   "로켓을 재사용하는 기술로 발사 비용을 크게 낮춰 세계 발사 시장 대부분을 차지",
   "위성 인터넷 스타링크 가입자가 빠르게 늘며 최대 매출원이 됨",
   "2026년 6월 역사상 최대 규모 IPO(약 750억 달러 조달)로 현금이 부채보다 많음"],
 "cautions": [
   "아직 순이익이 적자이고, 투자(CapEx)가 매우 커서 잉여현금흐름이 크게 마이너스",
   "상장한 지 반년도 안 돼 공개된 재무 데이터가 짧고, 출처마다 숫자가 다르게 나옴",
   "매출 대비 시가총액이 60배 이상으로 기대가 매우 크게 반영됨"],
 "business": "팰컨9·스타십 로켓으로 위성과 우주인을 실어 나르는 발사 사업, 수천 개 위성으로 인터넷을 제공하는 스타링크, 미국 정부·군 대상 사업을 운영. 2026년 AI 기업 xAI(챗봇 그록, 소셜미디어 X 포함)와 합쳐져 광고·AI 매출도 생김.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["소비자(스타링크 개인 가입)", 38.6], ["기업·정부(스타링크 등)", 22.4], ["발사 서비스", 13.8], ["광고(X)", 9.9], ["발사·개발 계약", 8.1], ["AI 솔루션", 7.3]],
   "by_region": [],
   "note": "지역별 매출은 공개 데이터에서 확인되지 않음. 비율은 사업부 매출액으로 계산."},
 "growth_drivers": ["스타링크 가입자 증가와 휴대폰 직접 연결 서비스", "대형 로켓 스타십 상용화", "AI(그록) 사업과 우주 데이터센터 구상"],
 "moat": "로켓 재사용 기술과 발사 횟수에서 경쟁사보다 몇 년 앞서 있음. 이미 궤도에 올린 수천 개 위성망은 다른 회사가 짧은 시간에 따라 하기 어려움.",
 "competitors": ["블루오리진", "아마존 카이퍼(위성 인터넷)", "유나이티드 론치 얼라이언스", "오픈AI·구글(AI 부문)"],
 "financials": [P("FY2023", "2023-12-31", 10387, 507, -4628, 4520, 4415),
                P("FY2024", "2024-12-31", 14015, 742, 18, 5776, 11163),
                P("FY2025", "2025-12-31", 18674, -2064, -4937, 6785, 20906),
                P("최근 12개월(TTM)", "2026-09-30", 32043, 575, -3431, 15762, 55053)],
 "financial_note": "상장 전 기간 수치는 상장 서류 기준으로 xAI 합병 효과가 섞여 있어 연도별 비교가 어렵고, 데이터 제공처마다 숫자가 다름. 앱 출시 전 공식 공시(SEC 10-Q)로 다시 확인 필요.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 89855, "total_debt": 39218},
 "valuation": {"per": None, "forward_per": None, "pbr": None, "roe": -25.2,
   "comment": "적자라서 PER을 계산할 수 없음. 시가총액이 최근 12개월 매출의 약 60배(PSR)로, 미래 성장 기대가 주가 대부분을 설명함."},
 "shareholder_return": {"dividend_per_share": None, "dividend_yield": None, "payout_ratio": None, "dividend_growth_years": None,
   "frequency": "배당 없음", "buyback": "자사주 매입 없음. 성장 투자에 현금을 모두 사용"},
 "risks": ["적자와 대규모 투자: 이익이 나기 전에 자금이 더 필요할 수 있음",
           "경영자 리스크: 일론 머스크 한 사람의 결정에 크게 좌우됨 (테슬라와도 연결)",
           "발사 사고: 로켓 폭발 등 사고 시 일정 지연과 신뢰 하락",
           "높은 기대치: 기대에 못 미치면 주가 변동이 매우 클 수 있음"],
 "upcoming": ["2026년 11~12월: 상장 후 실적 발표 일정 공지 예정", "스타십 정기 발사 일정"],
 "terms": ["market_cap", "ipo", "satellite_internet", "revenue", "operating_income", "net_income", "operating_cash_flow",
           "capex", "fcf", "net_cash", "psr", "per", "roe", "merger", "key_person_risk", "moat", "ttm"],
},
# ---------------------------------------------------------------- 7 META
{
 "id": "meta", "rank": 7, "name_ko": "메타 플랫폼스", "name_en": "Meta Platforms, Inc.", "ticker": "META", "exchange": "NASDAQ",
 "sector": "커뮤니케이션 서비스 / 소셜미디어", "market_cap_usd_b": 1639,
 "one_liner": "페이스북·인스타그램·왓츠앱을 무료로 제공하고, 매출의 98%를 광고로 버는 회사",
 "invest_points": [
   "매일 30억 명 이상이 메타 앱을 사용하는 압도적인 사용자 규모",
   "AI로 광고 타기팅이 좋아지며 매출이 연 20% 넘게 성장",
   "영업이익률 약 38~41%의 높은 수익성"],
 "cautions": [
   "매출 거의 전부가 광고라 경기 둔화에 민감",
   "AI 데이터센터와 메타버스(리얼리티 랩스)에 막대한 투자, 리얼리티 랩스는 매년 큰 적자",
   "청소년 보호, 개인정보 관련 규제와 소송"],
 "business": "페이스북, 인스타그램, 왓츠앱, 메신저, 스레드를 운영하며 광고를 판매. 리얼리티 랩스 부문은 VR 기기(퀘스트), AI 스마트 안경(레이밴 메타) 등을 개발. 자체 AI 모델 '라마'와 메타 AI 비서도 운영.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["광고", 97.6], ["기타", 1.3], ["리얼리티 랩스(VR·AR 기기)", 1.1]],
   "by_region": [["미국·캐나다", 39.2], ["아시아태평양", 26.8], ["유럽", 23.2], ["기타", 10.8]]},
 "growth_drivers": ["AI 기반 광고 추천·자동 광고 제작", "왓츠앱 비즈니스 메시지·스레드 광고", "AI 스마트 안경"],
 "moat": "친구·가족이 모두 쓰고 있어서 떠나기 어려운 '네트워크 효과'. 방대한 사용자 데이터로 광고 효율이 높음.",
 "competitors": ["구글(유튜브)", "틱톡", "스냅", "애플(기기·개인정보 정책)"],
 "financials": [P("FY2023", "2023-12-31", 134902, 46751, 39098, 71113, 27045),
                P("FY2024", "2024-12-31", 164501, 69380, 62360, 91328, 37256),
                P("FY2025", "2025-12-31", 200966, 83276, 60458, 115800, 69691),
                P("최근 12개월(TTM)", "2026-09-30", 241605, 91270, 75249, 133087, 104438)],
 "financial_note": "매출은 크게 늘었지만 AI 투자 증가로 잉여현금흐름은 2024년 이후 감소 중.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 82449, "total_debt": 114842},
 "valuation": {"per": 20.8, "forward_per": 18.5, "pbr": 5.7, "roe": 32.3,
   "comment": "빅테크 중에서는 PER이 낮은 편으로 시장 평균과 비슷. 투자 부담과 규제 위험이 할인 요인으로 반영된 것으로 해석됨."},
 "shareholder_return": {"dividend_per_share": 2.10, "dividend_yield": 0.34, "payout_ratio": 7.2, "dividend_growth_years": 1,
   "frequency": "분기", "buyback": "2024년부터 배당 시작. 자사주 매입으로 주식 수 1년간 약 0.8% 감소"},
 "risks": ["광고 의존: 경기 침체 시 광고 매출 감소",
           "투자 부담: AI·메타버스 투자가 이익과 현금흐름을 압박",
           "규제: 유럽 개인정보 규제, 미국 청소년 SNS 소송, 반독점 소송",
           "경쟁: 틱톡 등 짧은 영상 플랫폼과 사용 시간 경쟁"],
 "upcoming": ["2027년 1월 말: 2026년 4분기 실적 발표 (예상)", "연간 설비투자 계획 발표 (실적 발표 때)"],
 "terms": ["market_cap", "advertising_revenue", "network_effect", "revenue", "operating_income", "operating_margin",
           "net_income", "operating_cash_flow", "capex", "fcf", "net_debt", "per", "forward_per", "pbr", "roe",
           "dividend_yield", "buyback", "moat", "antitrust", "ttm"],
},
# ---------------------------------------------------------------- 8 BROADCOM
{
 "id": "avgo", "rank": 8, "name_ko": "브로드컴", "name_en": "Broadcom Inc.", "ticker": "AVGO", "exchange": "NASDAQ",
 "sector": "정보기술 / 반도체·소프트웨어", "market_cap_usd_b": 1524,
 "one_liner": "구글·메타 같은 빅테크에 맞춤형 AI 칩과 네트워크 칩을 만들어 주고, 기업용 소프트웨어(VM웨어)도 파는 회사",
 "invest_points": [
   "빅테크 전용 맞춤형 AI 칩(ASIC) 시장의 선두, 최근 분기 매출 85% 성장",
   "설비투자가 매우 적어 영업현금흐름 대부분이 잉여현금흐름으로 남음",
   "15년 연속 배당을 늘려온 배당성장주"],
 "cautions": [
   "VM웨어 인수로 생긴 부채가 약 590억 달러로 큼",
   "AI 칩 매출이 소수 대형 고객에 집중",
   "VM웨어 가격 인상에 대한 고객 불만과 이탈 가능성"],
 "business": "데이터센터·통신·스마트폰에 들어가는 다양한 반도체(네트워크 스위치 칩, 맞춤형 AI 칩, 와이파이 칩 등)를 설계·판매. 2023년 VM웨어를 인수해 기업 서버를 가상화하는 소프트웨어 사업도 큰 비중을 차지.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-11-02 종료)",
   "by_segment": [["반도체 솔루션", 57.7], ["인프라 소프트웨어(VM웨어 등)", 42.3]],
   "by_region": [["아시아태평양", 56.2], ["미주", 29.6], ["유럽·중동·아프리카", 14.2]],
   "note": "지역은 제품이 배송된 곳 기준이라 실제 최종 고객과 다를 수 있음."},
 "growth_drivers": ["빅테크 맞춤형 AI 칩 수요", "AI 데이터센터 네트워크 장비(이더넷 스위치)", "VM웨어 구독 전환"],
 "moat": "고객 맞춤형 칩 설계 경험과 네트워크 반도체 기술이 오랜 기간 쌓여 있음. 인수한 사업의 비용을 줄여 이익률을 높이는 경영 능력.",
 "competitors": ["엔비디아", "마벨 테크놀로지", "AMD", "시스코(네트워크)"],
 "financials": [P("FY2023", "2023-10-29", 35819, 16706, 14082, 18085, 452),
                P("FY2024", "2024-11-03", 51574, 15798, 5895, 19962, 548),
                P("FY2025", "2025-11-02", 63887, 26367, 23126, 27537, 623),
                P("최근 12개월(TTM)", "2026-08-02", 89104, 43496, 38265, 40653, 1250)],
 "financial_note": "회계연도가 10월 말~11월 초에 끝남. 2024년 이익 감소는 VM웨어 인수 비용과 세금 영향.",
 "balance": {"asof": "2026-08-02", "cash_and_investments": 23975, "total_debt": 59419},
 "valuation": {"per": 37.5, "forward_per": 16.9, "pbr": 14.1, "roe": 44.3,
   "comment": "현재 PER은 높지만 이익이 매우 빠르게 늘 것으로 예상돼 선행 PER은 약 17배로 낮아짐. 성장 예상이 맞는지가 핵심."},
 "shareholder_return": {"dividend_per_share": 2.60, "dividend_yield": 0.89, "payout_ratio": 33.2, "dividend_growth_years": 15,
   "frequency": "분기", "buyback": "직원 주식보상으로 주식 수가 1년간 약 1% 늘어남"},
 "risks": ["고객 집중: 맞춤형 AI 칩 고객이 몇 개 회사뿐",
           "부채: 인수합병으로 생긴 부채와 이자 부담",
           "AI 투자 사이클: 빅테크 투자 축소 시 영향",
           "무역 규제: 아시아 비중이 커서 미·중 갈등에 노출"],
 "upcoming": ["2026-12-10: 2026 회계연도 4분기 실적 발표", "실적 발표 때 다음 해 배당 인상 발표 (매년 12월 관례)"],
 "terms": ["market_cap", "semiconductor", "asic", "fiscal_year", "revenue", "operating_margin", "net_income",
           "operating_cash_flow", "capex", "fcf", "net_debt", "mna", "per", "forward_per", "pbr", "roe",
           "dividend_yield", "payout_ratio", "dividend_growth_stock", "dilution", "customer_concentration", "ttm"],
},
# ---------------------------------------------------------------- 9 TESLA
{
 "id": "tsla", "rank": 9, "name_ko": "테슬라", "name_en": "Tesla, Inc.", "ticker": "TSLA", "exchange": "NASDAQ",
 "sector": "임의소비재 / 전기차·에너지", "market_cap_usd_b": 1493,
 "one_liner": "전기차를 만들어 팔고, 에너지 저장장치·자율주행·로봇으로 미래 사업을 키우는 회사",
 "invest_points": [
   "전기차 대표 브랜드이자 에너지 저장장치(메가팩) 사업이 빠르게 성장",
   "현금 약 450억 달러로 부채(약 160억 달러)보다 훨씬 많음",
   "자율주행 로보택시·휴머노이드 로봇(옵티머스)이 성공하면 큰 성장 가능성"],
 "cautions": [
   "영업이익률이 3%대로 3년 사이 크게 하락 (가격 인하·경쟁 심화)",
   "PER이 약 390배로 현재 이익보다 미래 기대가 주가 대부분을 차지",
   "중국 전기차 업체(BYD 등)와 가격 경쟁"],
 "business": "모델3·모델Y 등 전기차를 생산·판매하는 것이 매출의 약 70%. 가정·전력회사용 배터리 저장장치(파워월·메가팩)와 태양광, 충전·보험·정비 서비스도 운영. 자율주행 소프트웨어(FSD)와 로보택시, 휴머노이드 로봇을 개발 중.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["자동차 판매", 69.4], ["에너지 저장·태양광", 13.5], ["서비스·기타", 13.2], ["탄소배출권 판매", 2.1], ["자동차 리스", 1.8]],
   "by_region": [["미국", 50.2], ["기타 국가", 27.7], ["중국", 22.1]]},
 "growth_drivers": ["에너지 저장장치(메가팩) 수요", "로보택시·자율주행 구독", "저가형 신차와 휴머노이드 로봇"],
 "moat": "전기차 브랜드 인지도, 자체 충전 네트워크(슈퍼차저), 수백만 대 차량에서 모은 자율주행 데이터.",
 "competitors": ["BYD", "현대차·기아", "폭스바겐", "웨이모(자율주행)"],
 "financials": [P("FY2023", "2023-12-31", 96773, 8891, 14999, 13256, 8899),
                P("FY2024", "2024-12-31", 97690, 7659, 7130, 14923, 11342),
                P("FY2025", "2025-12-31", 94827, 4355, 3794, 14747, 8527),
                P("최근 12개월(TTM)", "2026-09-30", 103570, 3134, 3220, 18710, 15407)],
 "financial_note": "2023년 순이익에는 일회성 세금 혜택(약 59억 달러)이 포함돼 있어 실제보다 크게 보임.",
 "balance": {"asof": "2026-09-30", "cash_and_investments": 45447, "total_debt": 16445},
 "valuation": {"per": 393.6, "forward_per": 167.6, "pbr": 15.9, "roe": 3.8,
   "comment": "PER이 시장 평균의 약 20배로 매우 비쌈. 자동차 회사가 아니라 AI·로봇 회사로 보는 투자자들의 기대가 반영된 것. 기대가 꺾이면 주가 변동이 큼."},
 "shareholder_return": {"dividend_per_share": None, "dividend_yield": None, "payout_ratio": None, "dividend_growth_years": None,
   "frequency": "배당 없음", "buyback": "자사주 매입 없음. 주식 수 1년간 약 0.5% 증가(희석)"},
 "risks": ["수익성 악화: 가격 경쟁으로 자동차 이익률 하락",
           "경영자 리스크: 일론 머스크의 정치 활동·다른 회사(스페이스X 등) 겸직",
           "자율주행 규제·사고: 로보택시 상용화 지연 가능성",
           "높은 밸류에이션: 기대치 하향 시 큰 주가 하락 위험"],
 "upcoming": ["2027년 1월 초: 4분기 차량 인도량 발표", "2027년 1월 말: 2026년 4분기 실적 발표 (예상)", "로보택시 서비스 지역 확대"],
 "terms": ["market_cap", "ev", "energy_storage", "carbon_credit", "revenue", "operating_income", "operating_margin",
           "net_income", "operating_cash_flow", "capex", "fcf", "net_cash", "per", "forward_per", "pbr", "roe",
           "dilution", "valuation", "key_person_risk", "moat", "ttm"],
},
# ---------------------------------------------------------------- 10 ELI LILLY
{
 "id": "lly", "rank": 10, "name_ko": "일라이 릴리", "name_en": "Eli Lilly and Company", "ticker": "LLY", "exchange": "NYSE",
 "sector": "헬스케어 / 제약", "market_cap_usd_b": 1329,
 "one_liner": "당뇨·비만 치료제 '마운자로'와 '젭바운드'로 급성장한 세계 최대 시가총액 제약회사",
 "invest_points": [
   "비만·당뇨 치료제(GLP-1 계열) 시장 선두, 매출이 2년 만에 약 2배",
   "영업이익률이 30% → 50% 수준으로 빠르게 상승",
   "먹는 비만약(오르포글리프론) 등 후속 신약 파이프라인"],
 "cautions": [
   "매출의 약 56%가 마운자로·젭바운드 두 제품에 집중",
   "약값 인하 압박 (미국 정부 정책, 노보노디스크와의 가격 경쟁)",
   "생산설비 투자로 부채가 늘고 현금은 적은 편"],
 "business": "신약을 연구·개발해 특허 기간 동안 독점 판매하는 제약회사. 비만·당뇨 치료제가 매출의 절반 이상이고, 항암제(버제니오 등), 면역질환 치료제, 알츠하이머 치료제(키썬라) 등도 판매.",
 "revenue_mix": {"fiscal_year": "FY2025 (2025-12-31 종료)",
   "by_segment": [["마운자로(당뇨)", 35.2], ["젭바운드(비만)", 20.8], ["항암제", 14.4], ["면역질환", 8.1], ["트루리시티(당뇨)", 6.6], ["자디앙스(당뇨)", 5.3], ["휴마로그(인슐린)", 3.3], ["기타", 6.4]],
   "by_region": [["미국", 66.7], ["유럽", 17.7], ["기타 국가", 9.3], ["일본", 3.3], ["중국", 3.0]]},
 "growth_drivers": ["비만 치료제 처방 확대와 보험 적용 확대", "먹는 비만약 출시", "알츠하이머·심혈관 등 신약"],
 "moat": "신약 특허로 일정 기간 독점 판매. GLP-1 약을 대량 생산할 수 있는 공장 능력이 경쟁사 진입을 막는 장벽.",
 "competitors": ["노보노디스크(위고비·오젬픽)", "암젠", "화이자", "머크"],
 "financials": [P("FY2023", "2023-12-31", 34124, 10325, 5240, 4240, 3448),
                P("FY2024", "2024-12-31", 45043, 17040, 10590, 8818, 5058),
                P("FY2025", "2025-12-31", 65179, 29696, 20640, 16813, 7841),
                P("최근 12개월(TTM)", "2026-06-30", 79666, 39608, 26711, 28083, 9893)],
 "financial_note": "최근 12개월은 2026년 2분기까지 기준. 3분기 실적(2026-10-29 발표) 반영 시 매출 약 865억 달러 수준.",
 "balance": {"asof": "2026-06-30", "cash_and_investments": 9746, "total_debt": 54908},
 "valuation": {"per": 43.9, "forward_per": 28.9, "pbr": 30.0, "roe": 86.0,
   "comment": "일반 제약회사 PER(보통 15배 안팎)보다 훨씬 높음. 비만약 성장이 계속될 것이라는 기대가 반영된 성장주 가격."},
 "shareholder_return": {"dividend_per_share": 6.92, "dividend_yield": 0.51, "payout_ratio": 22.5, "dividend_growth_years": 11,
   "frequency": "분기", "buyback": "자사주 매입으로 주식 수 1년간 약 0.6% 감소"},
 "risks": ["제품 집중: 비만·당뇨약 두 제품 의존도가 높음",
           "약가 규제: 미국 정부의 약값 협상·인하 정책",
           "경쟁: 노보노디스크와 신규 비만약 개발사들의 추격",
           "임상 실패: 신약 개발 실패 시 기대 하락"],
 "upcoming": ["2027년 2월 초: 2026년 4분기 실적 발표 (예상)", "먹는 비만약 판매 확대와 신약 임상 결과 발표"],
 "terms": ["market_cap", "glp1", "pipeline", "patent", "revenue", "operating_income", "operating_margin", "net_income",
           "operating_cash_flow", "capex", "fcf", "net_debt", "per", "forward_per", "pbr", "roe", "dividend_yield",
           "payout_ratio", "buyback", "moat", "customer_concentration", "ttm"],
},
]

# ---------- 11~50위: 글 + 자동으로 받은 숫자 합치기
NUM = json.load(open(os.path.join(ROOT, "top50_numbers.json"), encoding="utf-8"))
SRC_NUM = [f"나스닥 시가총액 ({NUM['asof']} 조회, 전날 종가)", "SEC EDGAR XBRL 공시(10-K·10-Q)", "야후 파이낸스 배당 기록"]
for i, t in enumerate(sorted(more, key=lambda t: -NUM["companies"][t["ticker"]]["market_cap_usd_b"]), len(companies) + 1):
    n = NUM["companies"][t["ticker"]]
    fin = []
    for r in n["financials"]:
        fcf = r["ocf"] - r["capex"] if r["ocf"] is not None and r["capex"] is not None else None
        fin.append({"label": r["label"], "end_date": r["end_date"], "revenue": r["revenue"], "operating_income": r["operating_income"],
                    "net_income": r["net_income"], "operating_cash_flow": r["ocf"], "capex": r["capex"], "free_cash_flow": fcf})
    sr = dict(n["shareholder_return"])
    sr["frequency"] = sr["frequency"] or "배당을 주지 않음"
    sr["buyback"] = t["buyback"]
    c = {k: v for k, v in t.items() if k not in ("valuation_comment", "buyback")}
    c.update(rank=i, market_cap_usd_b=n["market_cap_usd_b"], financials=fin, balance=dict(n["balance"]),
             valuation={**n["valuation"], "comment": t["valuation_comment"], "asof": NUM["asof"]},
             shareholder_return=sr, market_cap_asof=NUM["asof"], sources=SRC_NUM)
    companies.append(c)

glossary = {
 "market_cap": ("시가총액", "회사 전체의 가격. 주가 × 발행 주식 수. 회사를 통째로 사려면 드는 돈이라고 생각하면 됨.", "애플 시가총액 약 5조 달러 = 애플 주식을 전부 사는 데 드는 돈"),
 "ticker": ("티커", "주식시장에서 회사를 부르는 짧은 영어 약칭.", "애플 = AAPL, 엔비디아 = NVDA"),
 "fiscal_year": ("회계연도(FY)", "회사가 1년 실적을 계산하는 기간. 1~12월이 아닌 회사도 많음.", "애플 FY2026 = 2025년 10월 ~ 2026년 9월"),
 "ttm": ("최근 12개월(TTM)", "가장 최근 4개 분기를 합친 실적. 회계연도보다 최신 흐름을 보여줌.", "2026년 9월까지 최근 12개월 매출"),
 "revenue": ("매출", "물건이나 서비스를 팔아서 들어온 돈 전체. 비용을 빼기 전 금액.", "커피 100잔 × 5,000원 = 매출 50만 원"),
 "operating_income": ("영업이익", "매출에서 원가, 인건비, 마케팅비 등 본업에 든 비용을 뺀 돈. 회사의 '본업 실력'.", "매출 50만 원 - 재료비·월세·월급 40만 원 = 영업이익 10만 원"),
 "operating_margin": ("영업이익률", "매출 중 영업이익이 차지하는 비율. 높을수록 장사를 효율적으로 한다는 뜻.", "매출 100, 영업이익 30 → 영업이익률 30%"),
 "net_income": ("순이익", "영업이익에서 이자, 세금, 투자 손익 등을 모두 반영하고 최종적으로 남은 이익.", "주주 몫으로 남는 최종 이익"),
 "one_time_gain": ("일회성 이익", "본업과 관계없이 한 번만 생긴 이익. 보유 주식 가치 상승, 자산 매각 등. 순이익을 일시적으로 부풀림.", "알파벳이 보유한 투자 지분 가치가 올라 순이익이 영업이익보다 커짐"),
 "operating_cash_flow": ("영업현금흐름", "본업으로 실제 회사 통장에 들어온 현금. 장부상 이익과 다를 수 있음.", "외상으로 팔면 매출은 있어도 현금은 아직 안 들어옴"),
 "capex": ("설비투자(CapEx)", "공장, 데이터센터, 장비처럼 오래 쓸 자산을 사는 데 쓴 돈.", "AI 데이터센터 건설비"),
 "fcf": ("잉여현금흐름(FCF)", "영업현금흐름 - 설비투자. 회사가 자유롭게 쓸 수 있는 '진짜 남는 현금'. 배당·자사주 매입의 재원.", "통장에 들어온 현금 100 - 시설 투자 30 = 잉여현금 70"),
 "net_cash": ("순현금", "보유 현금이 빚보다 많은 상태. 현금 - 부채가 플러스.", "현금 100억, 부채 40억 → 순현금 60억"),
 "net_debt": ("순부채", "빚이 보유 현금보다 많은 상태. 부채 - 현금이 플러스.", "현금 40억, 부채 100억 → 순부채 60억"),
 "per": ("PER(주가수익비율)", "주가가 1년 순이익의 몇 배인지. 시가총액 ÷ 순이익. 낮을수록 이익 대비 싸다는 뜻이지만 성장성도 함께 봐야 함.", "PER 20배 = 지금 이익이 그대로면 투자금 회수에 20년"),
 "forward_per": ("선행 PER", "현재 이익 대신 앞으로 1년 예상 이익으로 계산한 PER. 예상이 틀릴 수 있음.", "이익이 2배 될 걸로 예상되면 선행 PER은 현재 PER의 절반"),
 "pbr": ("PBR(주가순자산비율)", "주가가 회사 순자산(자산 - 부채)의 몇 배인지. 1배보다 낮으면 장부 가치보다 싸게 거래된다는 뜻.", "자사주를 많이 사면 순자산이 줄어 PBR이 커짐"),
 "roe": ("ROE(자기자본이익률)", "주주가 맡긴 돈(자기자본)으로 1년에 얼마나 벌었는지. 순이익 ÷ 자기자본.", "ROE 20% = 자본 100으로 1년에 20을 범"),
 "psr": ("PSR(주가매출비율)", "시가총액이 매출의 몇 배인지. 적자라서 PER을 못 쓸 때 주로 사용.", "시총 600, 매출 10 → PSR 60배"),
 "valuation": ("밸류에이션", "회사의 가치를 평가하는 것. 주가가 비싼지 싼지 판단하는 과정.", "PER, PBR 등을 비교"),
 "dividend_yield": ("배당수익률", "주가 대비 1년 배당금 비율. 은행 이자율과 비슷한 개념.", "주가 100달러, 배당 3달러 → 3%"),
 "payout_ratio": ("배당성향", "순이익 중 배당으로 나눠준 비율.", "순이익 100 중 30을 배당 → 30%"),
 "dividend_growth_stock": ("배당성장주", "배당금을 여러 해 연속으로 늘려 온 주식.", "마이크로소프트 20년 연속 배당 증가"),
 "buyback": ("자사주 매입", "회사가 자기 주식을 시장에서 사들이는 것. 주식 수가 줄어 남은 주주의 지분 가치가 커짐.", "애플은 매년 수백억 달러 규모로 자사주 매입"),
 "dilution": ("주식 희석", "새 주식 발행(직원 보상 등)으로 주식 수가 늘어 기존 주주의 지분 비율이 줄어드는 것.", "주식 수 1% 증가 → 내 지분 가치 약간 감소"),
 "moat": ("해자(경제적 해자)", "경쟁자가 쉽게 따라오지 못하게 막는 회사만의 강점. 성을 둘러싼 물길에서 나온 말.", "브랜드, 특허, 네트워크 효과, 전환비용"),
 "switching_cost": ("전환비용", "다른 회사 제품으로 바꿀 때 드는 비용과 불편함. 클수록 고객이 떠나기 어려움.", "아이폰 사진·앱·애플워치를 다 옮겨야 하는 번거로움"),
 "ecosystem": ("생태계", "여러 제품과 서비스가 서로 연결돼 함께 쓸수록 편해지는 구조.", "아이폰-맥-에어팟-아이클라우드"),
 "network_effect": ("네트워크 효과", "사용자가 많아질수록 서비스 가치가 더 커지는 현상.", "친구들이 다 인스타그램을 써서 나도 써야 함"),
 "economies_of_scale": ("규모의 경제", "많이 생산·판매할수록 하나당 비용이 낮아지는 효과.", "아마존 물류센터가 많을수록 배송비 단가 하락"),
 "services_revenue": ("서비스 매출", "기기 판매가 아니라 앱, 구독, 결제 수수료 등에서 나오는 매출. 반복적이고 이익률이 높음.", "앱스토어 수수료, 아이클라우드 요금"),
 "subscription": ("구독 모델", "매달·매년 정해진 요금을 받는 판매 방식. 매출이 안정적이고 예측하기 쉬움.", "오피스365, 넷플릭스, 프라임 멤버십"),
 "cloud": ("클라우드", "회사가 직접 서버를 사지 않고 인터넷으로 컴퓨터 자원을 빌려 쓰는 서비스.", "AWS, 애저, 구글 클라우드"),
 "data_center": ("데이터센터", "수많은 서버 컴퓨터를 모아 놓은 거대한 건물. 클라우드와 AI 서비스가 여기서 돌아감.", "AI 학습용 GPU 수만 개가 들어간 시설"),
 "gpu": ("GPU(그래픽처리장치)", "원래 게임 그래픽용 칩이지만, 많은 계산을 동시에 처리할 수 있어 AI 학습에 핵심이 된 반도체.", "엔비디아 블랙웰"),
 "asic": ("ASIC(맞춤형 반도체)", "특정 용도·특정 고객만을 위해 설계한 칩. 범용 칩보다 효율이 높음.", "구글 TPU(브로드컴과 공동 설계)"),
 "semiconductor": ("반도체", "전기를 통하게도, 막게도 할 수 있는 물질로 만든 칩. 모든 전자기기의 두뇌와 기억장치.", "CPU, GPU, 메모리"),
 "fabless": ("팹리스", "반도체 공장 없이 설계만 하고 생산은 위탁하는 회사.", "엔비디아, 브로드컴 → 생산은 TSMC"),
 "export_control": ("수출 규제", "정부가 특정 국가로 특정 제품을 팔지 못하게 막는 것.", "미국의 대중국 첨단 AI 칩 수출 제한"),
 "customer_concentration": ("고객 집중(의존도)", "매출의 많은 부분이 소수 고객이나 소수 제품에서 나오는 것. 그 고객·제품이 흔들리면 실적도 흔들림.", "AI 칩 매출 대부분이 빅테크 몇 곳"),
 "antitrust": ("반독점 규제", "한 회사가 시장을 독차지해 경쟁을 막는 것을 정부가 제재하는 것.", "미국 법무부의 구글 검색 독점 소송"),
 "advertising_revenue": ("광고 매출", "서비스를 무료로 제공하고 광고주에게 광고를 팔아 버는 돈.", "구글 검색 광고, 인스타그램 광고"),
 "ecommerce": ("전자상거래(이커머스)", "인터넷으로 물건을 사고파는 것.", "아마존, 쿠팡"),
 "ipo": ("IPO(기업공개)", "비상장 회사가 처음으로 주식을 증권시장에 상장해 일반 투자자에게 파는 것.", "스페이스X 2026년 6월 나스닥 상장"),
 "merger": ("합병", "두 회사가 하나로 합쳐지는 것.", "스페이스X와 xAI 합병"),
 "mna": ("인수합병(M&A)", "다른 회사를 사거나 합치는 것. 빠른 성장 수단이지만 부채가 늘 수 있음.", "브로드컴의 VM웨어 인수(약 690억 달러)"),
 "satellite_internet": ("위성 인터넷", "지상 케이블 대신 우주의 위성으로 인터넷을 연결하는 서비스. 산간·바다·비행기에서도 사용 가능.", "스타링크"),
 "key_person_risk": ("핵심 인물 리스크", "회사가 특정 한 사람(주로 CEO)에게 크게 의존해 그 사람의 결정·건강·평판이 주가를 흔드는 위험.", "일론 머스크"),
 "ev": ("전기차(EV)", "휘발유 대신 배터리 전기로 모터를 돌려 달리는 자동차.", "테슬라 모델Y"),
 "energy_storage": ("에너지 저장장치(ESS)", "전기를 대용량 배터리에 저장했다가 필요할 때 쓰는 장치.", "테슬라 메가팩"),
 "carbon_credit": ("탄소배출권", "온실가스를 배출할 수 있는 권리. 전기차 회사는 남는 권리를 다른 자동차 회사에 팔 수 있음.", "테슬라의 규제 크레딧 매출"),
 "glp1": ("GLP-1 치료제", "식욕을 줄이고 혈당을 낮추는 호르몬을 흉내 낸 약. 당뇨와 비만 치료에 사용.", "마운자로, 젭바운드, 위고비"),
 "pipeline": ("파이프라인(신약)", "개발 중인 신약 후보 목록. 제약회사의 미래 매출원.", "임상 3상 중인 먹는 비만약"),
 "holding_company": ("지주회사", "다른 회사들의 주식을 가지고 그 회사들을 거느리는 회사.", "버크셔 해서웨이가 철도·보험·에너지 회사를 소유"),
 "insurance_float": ("플로트(보험 자금)", "보험회사가 보험료를 먼저 받고 보험금은 나중에 내주기 때문에, 그 사이 굴릴 수 있는 큰돈.", "버크셔는 플로트로 주식과 국채에 투자"),
 "net_interest_income": ("순이자이익", "은행이 대출로 받은 이자에서 예금자에게 준 이자를 뺀 돈. 은행의 가장 큰 수입원.", "대출 이자 5% - 예금 이자 2% = 3%만큼 이익"),
 "investment_bank": ("투자은행", "기업의 상장·인수합병을 돕고 주식·채권을 사고파는 일을 하는 금융회사.", "골드만삭스, 모건스탠리"),
 "payment_network": ("결제 네트워크", "카드 결제 때 가게-은행-카드사 사이의 승인과 정산을 연결해 주는 시스템. 결제마다 수수료를 받음.", "비자, 마스터카드"),
 "membership": ("회원제 모델", "연회비를 받는 대신 회원에게 싼 가격이나 혜택을 주는 방식. 회비가 안정적인 이익이 됨.", "코스트코 연회비, 월마트+"),
 "memory": ("메모리 반도체", "데이터를 기억하는 반도체. 일할 때 쓰는 D램과 꺼져도 남는 낸드가 있음. 값이 크게 오르내림.", "마이크론, 삼성전자, SK하이닉스"),
 "semi_equipment": ("반도체 장비", "반도체 공장에서 웨이퍼에 회로를 새기고 깎고 검사하는 기계.", "어플라이드 머티어리얼즈, 램리서치, ASML"),
 "foundry": ("파운드리", "다른 회사가 설계한 반도체를 대신 만들어 주는 위탁생산 사업.", "TSMC, 인텔 파운드리"),
 "cybersecurity": ("사이버보안", "컴퓨터·네트워크·데이터를 해킹과 바이러스에서 지키는 기술과 서비스.", "방화벽, 백신 프로그램"),
 "saas": ("SaaS(구독형 소프트웨어)", "프로그램을 사서 설치하는 대신 인터넷으로 접속해 매달·매년 요금을 내고 쓰는 소프트웨어.", "크라우드스트라이크, 세일즈포스"),
 "streaming": ("스트리밍", "영상·음악을 내려받지 않고 인터넷으로 바로 재생하는 서비스.", "넷플릭스, 유튜브"),
 "oil_price": ("유가", "원유 1배럴(약 159리터)의 가격. 석유회사 이익을 가장 크게 좌우함.", "유가가 오르면 엑슨모빌 이익 증가"),
 "refining": ("정유", "땅에서 뽑은 원유를 끓이고 나눠 휘발유·경유·항공유 등으로 만드는 일.", "정유공장, 주유소"),
 "defense": ("방위산업(방산)", "전투기·미사일·군함 같은 무기와 군사 장비를 만드는 산업. 주 고객은 정부.", "RTX, 록히드마틴"),
 "backlog": ("수주잔고", "이미 주문은 받았지만 아직 만들어 넘기지 않은 물량. 앞으로의 매출을 미리 보여 줌.", "수주잔고 2,000억 달러 = 몇 년 치 일감"),
 "cyclical": ("경기민감주", "경기가 좋을 때 이익이 크게 늘고 나쁠 때 크게 주는 회사의 주식.", "메모리 반도체, 건설 장비, 석유"),
 "dividend_king": ("배당왕", "50년 넘게 매년 배당금을 늘려 온 회사. 25년 이상은 '배당 귀족'이라고 부름.", "코카콜라, P&G, 존슨앤드존슨"),
 "consumer_staples": ("필수소비재", "경기와 상관없이 늘 사야 하는 물건(음식, 세제, 생필품). 경기가 나빠도 실적이 안정적.", "P&G, 코카콜라, 월마트"),
 "biosimilar": ("바이오시밀러", "특허가 끝난 바이오의약품을 다른 회사가 비슷하게 만든 복제약. 값이 싸서 원래 약의 매출을 줄임.", "휴미라 바이오시밀러"),
 "medicare": ("메디케어", "미국 정부가 65세 이상 노인에게 제공하는 공공 의료보험. 민간 보험사가 대신 운영하기도 함.", "유나이티드헬스의 메디케어 어드밴티지"),
 "pbm": ("PBM(약제급여관리)", "보험사 대신 제약회사·약국과 약값을 협상하고 처방약 비용을 관리하는 사업.", "옵텀Rx, CVS 케어마크"),
 "smoke_free": ("비연소 담배", "불을 붙여 태우지 않는 담배 제품. 가열담배, 니코틴 파우치, 전자담배 등.", "아이코스, 진(ZYN)"),
 "aftermarket": ("애프터마켓(정비 매출)", "제품을 판 뒤에 부품 교체·정비·업그레이드로 계속 버는 매출. 이익률이 높고 안정적.", "항공기 엔진 정비"),
 "one_time_cost": ("일회성 비용", "본업과 별개로 한 번만 생긴 큰 비용. 소송 합의금, 인수 관련 비용 등. 순이익을 일시적으로 줄임.", "신약 회사를 인수하면서 한꺼번에 처리한 연구개발 비용"),
 "patent": ("특허", "발명을 일정 기간(보통 20년) 독점적으로 사용할 수 있는 권리. 만료되면 복제약이 나옴.", "신약 특허 만료 → 매출 급감(특허 절벽)"),
}

# ---------- 계산
for c in companies:
    prev = None
    for p in c["financials"]:
        p["operating_margin_pct"] = round(p["operating_income"] / p["revenue"] * 100, 1) if p["operating_income"] is not None and p["revenue"] else None
        p["revenue_growth_pct"] = None
        if prev and prev["revenue"] and p["revenue"] is not None and not p["label"].startswith("최근"):
            p["revenue_growth_pct"] = round((p["revenue"] / prev["revenue"] - 1) * 100, 1)
        if not p["label"].startswith("최근"):
            prev = p
    b = c["balance"]
    b["net_cash"] = b["cash_and_investments"] - b["total_debt"] if b["cash_and_investments"] is not None and b["total_debt"] is not None else None
    for t in c["terms"]:
        assert t in glossary, (c["id"], t)

# ---------- JSON
os.makedirs(OUT, exist_ok=True)
meta = {"title": "미국 시가총액 Top 50 기업 정보", "market_cap_asof": MCAP_ASOF, "valuation_asof": VAL_ASOF,
        "currency": "USD", "financial_unit": "USD_million", "market_cap_unit": "USD_billion",
        "sources": [SRC_MCAP, SRC_FIN, "Apple FY2026 4분기 실적 보도자료 (SEC 8-K)"] + SRC_NUM,
        "disclaimer": "이 자료는 투자 공부를 위한 정보 제공용이며 특정 종목의 매수·매도 추천이 아닙니다. 수치는 기준일 이후 달라질 수 있습니다."}
for c in companies[:10]:  # 11위부터는 위에서 기준일·출처를 이미 붙임
    c["market_cap_asof"] = MCAP_ASOF
    c["valuation"]["asof"] = VAL_ASOF
    c["sources"] = [SRC_MCAP, SRC_FIN] + (["Apple FY2026 실적 보도자료 (SEC 8-K)"] if c["id"] == "aapl" else [])
with open(f"{OUT}/companies.json", "w", encoding="utf-8") as f:
    json.dump({"meta": meta, "companies": companies}, f, ensure_ascii=False, indent=2)

from glossary_macro import CATS, MACRO
glossary.update({k: v[:3] for k, v in MACRO.items()})
used = {t for c in companies for t in c["terms"]} | set(MACRO)
cat_of = {k: cat for cat, ks in CATS.items() for k in ks}
assert used <= set(cat_of), sorted(used - set(cat_of))  # 새 용어는 glossary_macro.CATS에 분야를 정해 줘야 함
order = list(CATS)
used = sorted(used, key=lambda k: (order.index(cat_of[k]), glossary[k][0]))
gl = [{"id": k, "category": cat_of[k], "term": glossary[k][0], "definition": glossary[k][1], "example": glossary[k][2],
       **({"market_effect": MACRO[k][3]} if k in MACRO else {}),
       "used_by": [c["ticker"] for c in companies if k in c["terms"]]} for k in used]
with open(f"{OUT}/glossary.json", "w", encoding="utf-8") as f:
    json.dump({"meta": {"title": "경제용어 사전 (분야별)", "count": len(gl), "categories": order}, "terms": gl}, f, ensure_ascii=False, indent=2)

# ---------- Markdown
def eok(m):  # million USD -> 억 달러
    if m is None: return "-"
    return f"{m/100:,.0f}억 달러"
def num(v, suf=""):
    return "-" if v is None else f"{v:,.1f}{suf}" if isinstance(v, float) else f"{v}{suf}"
def tril(b): return f"약 {b/1000:.2f}조 달러"

L = [f"# 미국 시가총액 Top 50 기업 정보", "",
     f"- 시가총액·순위 기준일: **{MCAP_ASOF} 종가**", f"- PER 등 밸류에이션 기준일: **{VAL_ASOF} 종가**",
     "- 재무 수치 단위: 억 달러 (1억 달러 ≈ 1,400억 원 안팎, 환율에 따라 변동)",
     f"- 출처: {SRC_MCAP}; {SRC_FIN}", f"- {meta['disclaimer']}", "",
     "| 순위 | 기업 | 티커 | 시가총액 | 한 줄 설명 |", "|---|---|---|---|---|"]
for c in companies:
    L.append(f"| {c['rank']} | {c['name_ko']} | {c['ticker']} | {tril(c['market_cap_usd_b'])} | {c['one_liner']} |")
L.append("")
for c in companies:
    v, s, b, rm = c["valuation"], c["shareholder_return"], c["balance"], c["revenue_mix"]
    L += ["---", "", f"## {c['rank']}. {c['name_ko']} ({c['name_en']})", "",
          f"**{c['ticker']}** · {c['exchange']} · {c['sector']} · 시가총액 {tril(c['market_cap_usd_b'])} ({c['market_cap_asof']})", "",
          f"> {c['one_liner']}", "",
          "**투자 포인트**"] + [f"- {x}" for x in c["invest_points"]] + ["", "**주의할 점**"] + [f"- {x}" for x in c["cautions"]] + [
          "", "### 무슨 일을 하나", c["business"], "", f"### 돈은 어디서 버나 (기준: {rm['fiscal_year']})",
          "사업별: " + ", ".join(f"{n} {p}%" for n, p in rm["by_segment"])]
    if rm["by_region"]:
        L.append("\n지역별: " + ", ".join(f"{n} {p}%" for n, p in rm["by_region"]))
    if rm.get("note"): L.append(f"\n※ {rm['note']}")
    L += ["", "성장 동력: " + " / ".join(c["growth_drivers"]), "",
          "### 경쟁력(해자)과 경쟁사", c["moat"], "", "경쟁사: " + ", ".join(c["competitors"]), "",
          "### 실적과 현금흐름 (단위: 억 달러)", "",
          "| 기간 | 매출 | 매출 성장률 | 영업이익 | 영업이익률 | 순이익 | 영업현금흐름 | 설비투자 | 잉여현금흐름 |",
          "|---|---|---|---|---|---|---|---|---|"]
    for p in c["financials"]:
        g = "-" if p["revenue_growth_pct"] is None else f"{p['revenue_growth_pct']}%"
        e = lambda m: "-" if m is None else f"{m/100:,.0f}"
        L.append(f"| {p['label']} ({p['end_date']}) | {e(p['revenue'])} | {g} | {e(p['operating_income'])} | {num(p['operating_margin_pct'], '%')} | {e(p['net_income'])} | {e(p['operating_cash_flow'])} | {e(p['capex'])} | {e(p['free_cash_flow'])} |")
    if c.get("financial_note"): L += ["", f"※ {c['financial_note']}"]
    nc = b["net_cash"]
    L += ["", f"현금·투자자산 {eok(b['cash_and_investments'])} / 총부채 {eok(b['total_debt'])}"
          + ("" if nc is None else " → " + (f"순현금 {eok(nc)}" if nc >= 0 else f"순부채 {eok(-nc)}")) + f" ({b['asof']} 기준)", "",
          f"### 밸류에이션 ({v['asof']} 종가 기준)", "",
          f"PER {num(v['per'], '배')} · 선행 PER {num(v['forward_per'], '배')} · PBR {num(v['pbr'], '배')} · ROE {num(v['roe'], '%')}", "",
          v["comment"], "", "### 주주환원"]
    if s["dividend_per_share"] is None:
        L.append(f"- 배당: {s['frequency']}")
    else:
        L.append(f"- 배당: 연 ${s['dividend_per_share']:.2f} ({s['frequency']} 지급), 배당수익률 {s['dividend_yield']}%, 배당성향 {num(s['payout_ratio'], '%')}"
                 + ("" if s.get("dividend_growth_years") is None else f", {s['dividend_growth_years']}년 연속 배당 증가"))
    L += [f"- 자사주: {s['buyback']}", "", "### 리스크"] + [f"- {x}" for x in c["risks"]] + [
          "", "### 앞으로 볼 일정"] + [f"- {x}" for x in c["upcoming"]] + [
          "", "### 연결 용어", ", ".join(glossary[t][0] for t in c["terms"]), ""]
with open(f"{MD_OUT}/us-top50.md", "w", encoding="utf-8") as f:
    f.write("\n".join(L))

G = ["# 경제용어 사전 (분야별)", "", f"총 {len(gl)}개", ""]
for cat in order:
    G += ["", f"## {cat}", "", "| 용어 | 쉬운 설명 | 예시 | 시장에 주는 영향 | 등장 기업 |", "|---|---|---|---|---|"]
    G += [f"| {t['term']} | {t['definition']} | {t['example']} | {t.get('market_effect', '')} | {', '.join(t['used_by'])} |" for t in gl if t["category"] == cat]
with open(f"{MD_OUT}/glossary.md", "w", encoding="utf-8") as f:
    f.write("\n".join(G) + "\n")
print("companies", len(companies), "terms", len(gl))
