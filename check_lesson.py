"""배우기 수업 검사기

- 정해진 코스(A): jurini_app/assets/lessons.json
- AI 수업(B): docs/lesson_today.json, docs/lessons_ai.json, AI 추가 용어 docs/glossary_ai.json (있을 때만)
AI 예약 작업은 커밋 전에 반드시 실행한다. 실패하면 커밋하지 않는다.
실행: python check_lesson.py   (종료 코드 0 = 통과)
"""
import json
import os
import re
import sys

from check_news import BANNED, PRICE

A = "jurini_app/assets/lessons.json"
B_TODAY, B_ALL, B_TERMS = "docs/lesson_today.json", "docs/lessons_ai.json", "docs/glossary_ai.json"
CARD_MAX = 90


def lesson_problems(lesson, term_ids, ai=False):
    w = f"{lesson.get('id')} '{str(lesson.get('title'))[:15]}'"
    out = []
    if not (isinstance(lesson.get("id"), str) and isinstance(lesson.get("title"), str) and 0 < len(lesson["title"]) <= 30):
        out.append(f"{w}: id와 title(30자 이내) 필수")
    ts = lesson.get("terms")
    if not isinstance(ts, list) or not 1 <= len(ts) <= 6 or not set(ts) <= term_ids:
        out.append(f"{w}: terms는 용어사전에 있는 id 1~6개")
    cards = lesson.get("cards")
    if not isinstance(cards, list) or not 4 <= len(cards) <= 5:
        out.append(f"{w}: 카드는 4~5장")
        cards = []
    texts = []
    for c in cards:
        if not (isinstance(c, str) and 0 < len(c) <= CARD_MAX):
            out.append(f"{w}: 카드는 1~{CARD_MAX}자 ({str(c)[:20]})")
        texts.append(str(c))
    quiz = lesson.get("quiz")
    if not isinstance(quiz, list) or len(quiz) != 3:
        out.append(f"{w}: 퀴즈는 3문제")
        quiz = []
    for q in quiz:
        opts = q.get("options")
        if not (isinstance(q.get("q"), str) and isinstance(q.get("explain"), str) and isinstance(opts, list) and len(opts) == 4
                and len(set(opts)) == 4 and isinstance(q.get("answer"), int) and 0 <= q["answer"] < 4):
            out.append(f"{w}: 퀴즈는 질문·보기 4개(서로 다름)·정답 번호 0~3·설명")
        texts += [str(q.get("q")), str(q.get("explain")), *map(str, opts or [])]
    if any(BANNED.search(t) or PRICE.search(t) for t in texts):  # 문장마다 따로 (이어 붙이면 엉뚱하게 걸림)
        out.append(f"{w}: 투자 권유·주가 숫자 표현 금지")
    if ai:
        if lesson.get("stage") not in (1, 2, 3, 4, 5):
            out.append(f"{w}: stage는 1~5")
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", str(lesson.get("date", ""))):
            out.append(f"{w}: date는 YYYY-MM-DD")
        if lesson.get("verified") is not True or not any(str(u).startswith("https://") for u in lesson.get("sources") or []):
            out.append(f"{w}: 사실 확인(verified: true)과 확인한 출처(https) 필수")
    return out


def term_problems(t, known):
    w = f"용어 {t.get('id')}"
    out = []
    if not re.match(r"^[a-z0-9_]+$", str(t.get("id", ""))) or t.get("id") in known:
        out.append(f"{w}: id는 영문 소문자·숫자·_ , 기존 용어와 겹치면 안 됨")
    for k, mx in (("term", 30), ("definition", 160), ("example", 120), ("why", 160), ("category", 30)):
        if not (isinstance(t.get(k), str) and 0 < len(t[k]) <= mx):
            out.append(f"{w}: {k}는 1~{mx}자")
    if t.get("verified") is not True or not any(str(u).startswith("https://") for u in t.get("sources") or []):
        out.append(f"{w}: 사실 확인(verified: true)과 출처 필수")
    text = f"{t.get('definition', '')} {t.get('example', '')} {t.get('why', '')}"
    if BANNED.search(text) or PRICE.search(text):
        out.append(f"{w}: 투자 권유·주가 숫자 표현 금지")
    return out


def selfcheck():
    ok = {"id": "s1l1", "title": "주식이 뭐예요", "terms": ["market_cap"],
          "cards": ["카드 하나예요.", "카드 둘이에요.", "카드 셋이에요.", "카드 넷이에요."],
          "quiz": [{"q": "질문", "options": ["가", "나", "다", "라"], "answer": 1, "explain": "설명"}] * 3}
    ids = {"market_cap"}
    assert lesson_problems(ok, ids) == []
    assert lesson_problems({**ok, "cards": ok["cards"][:3]}, ids), "카드 3장을 못 잡음"
    assert lesson_problems({**ok, "cards": ok["cards"][:3] + ["가" * 91]}, ids), "91자 카드를 못 잡음"
    assert lesson_problems({**ok, "quiz": ok["quiz"][:2]}, ids), "퀴즈 2개를 못 잡음"
    assert lesson_problems({**ok, "quiz": [{**ok["quiz"][0], "answer": 4}] * 3}, ids), "범위 밖 정답을 못 잡음"
    assert lesson_problems({**ok, "terms": ["없는용어"]}, ids), "없는 용어를 못 잡음"
    assert lesson_problems({**ok, "cards": ok["cards"][:3] + ["주가가 오를 것 같아요."]}, ids), "금지 표현을 못 잡음"
    ai = {**ok, "stage": 4, "date": "2026-11-14", "verified": True, "sources": ["https://bls.gov"]}
    assert lesson_problems(ai, ids, ai=True) == []
    assert lesson_problems({**ai, "verified": False}, ids, ai=True), "확인 안 된 AI 수업을 못 잡음"
    assert lesson_problems({**ai, "sources": []}, ids, ai=True), "출처 없는 AI 수업을 못 잡음"
    assert lesson_problems({**ai, "stage": 6}, ids, ai=True), "단계 6을 못 잡음"


def main():
    selfcheck()
    load = lambda f: json.load(open(f, encoding="utf-8"))
    base = {t["id"] for t in load("jurini_app/assets/glossary.json")["terms"]}
    ai_terms = load(B_TERMS)["terms"] if os.path.exists(B_TERMS) else []
    errs = []
    for t in ai_terms:
        errs += term_problems(t, base)
    ids = base | {t["id"] for t in ai_terms}
    seen = set()
    for st in load(A)["stages"]:
        if not (isinstance(st.get("title"), str) and isinstance(st.get("goal"), str) and st.get("lessons")):
            errs.append(f"단계 {st.get('id')}: title·goal·lessons 필수")
        for l in st.get("lessons", []):
            if l.get("id") in seen:
                errs.append(f"{l.get('id')}: 수업 id 중복")
            seen.add(l.get("id"))
            errs += lesson_problems(l, ids)
    if os.path.exists(B_TODAY):
        errs += lesson_problems(load(B_TODAY), ids, ai=True)
    if os.path.exists(B_ALL):
        for l in load(B_ALL)["lessons"]:
            errs += lesson_problems(l, ids, ai=True)
    if errs:
        print("\n".join(errs[:60]))
        sys.exit(f"검사 실패 {len(errs)}건 — 커밋하지 말 것")
    print("통과:", len(seen), "개 정해진 수업")


if __name__ == "__main__":
    main()
