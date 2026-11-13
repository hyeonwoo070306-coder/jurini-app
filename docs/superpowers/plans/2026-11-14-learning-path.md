# 주린이 걸음마 (매일 10분 배우기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱 중심을 '매일 10분 배우기'로 옮긴다: 5단계 고정 코스(A) + 매일 AI 수업(B, 사실 확인 통과분만) + 뉴스→배우기 연결 + 연결 탭 검색·업종 묶음.

**Architecture:** 화면 코드는 `lib/main.dart`에 `part 'learn.dart';`로 배우기 기능만 새 파일로 뺀다(전역 변수·도우미 공유). 고정 수업은 앱 안 `assets/lessons.json`, AI 결과물은 깃허브 `docs/*.json`을 앱이 켤 때 받는다(못 받으면 없이 동작). 모든 AI 결과는 Python 검사기를 통과해야 커밋된다.

**Tech Stack:** Flutter(Dart 3), `shared_preferences`(진도 저장, 새 의존성), Python 3 검사기, Claude Code 예약 작업(RemoteTrigger).

**Spec:** `docs/superpowers/specs/2026-11-14-learning-path-design.md`

## Global Constraints
- 모든 문장: 중학생도 이해할 한국어, '~해요'체. 화면마다 `disclaimer`("투자 공부용 정보이며 매수·매도 추천이 아닙니다.").
- 금지: 주가 숫자, 목표가, 매수/매도/추천, "오를 것/내릴 것" 류 주가 예측 → `check_news.BANNED`, `check_news.PRICE` 재사용.
- 디자인: CLAUDE.md 디자인 토큰(`P.dark`), Pretendard, 카드 테두리 없음, 누르는 칸 48dp 이상. UI 작업 전 디자인 스킬(impeccable) 사용.
- 수업 하나 = 카드 4~5장(장당 90자 이내) + 퀴즈 3문제. 하루 수업 수 제한 없음.
- 진도는 폰 안에만(로그인 없음). 끊겼다고 벌주는 문구 금지.
- 하단 탭 5개 순서: 배우기 / 기업 / 연결 / 용어사전 / 뉴스, 첫 화면 = 배우기.
- 화면을 막는 팝업 금지(오늘의 시장 한눈에 칸으로 대신).
- AI 수업·용어: `verified: true` + `sources`(https 1개 이상) 없으면 검사기 거절. 확인된 AI 용어는 `docs/glossary_ai.json`에 영구, AI 수업 보관 60일.
- 텍스트 위젯은 `txt()`(한국어 줄바꿈), 테스트에서 찾을 땐 `find.textContaining(kt(...))`.

## Review Focus
1. 인터넷 없이 처음 켬: 배우기 탭이 앱 안 데이터만으로 뜨고, AI 수업·오늘의 시장 칸은 조용히 빠진다 (Task 4 테스트).
2. 진도 저장값이 비었거나 깨진 JSON: 처음 상태로 시작, 앱이 죽지 않는다 (Task 4 테스트).
3. 코스 25개를 다 끝냄: ①이 AI 수업으로 바뀌고, AI 수업도 없으면 "오늘은 복습만 해요" 안내 (Task 4 테스트).
4. 예전 뉴스 데이터(terms·learn·market 없음): 칩·칸 없이 그대로 보인다 (Task 2, 6 테스트).
5. '이번 주 며칠'은 같은 날 여러 수업을 해도 하루로 센다, 월요일 시작 (Task 4 테스트).

---

### Task 1: 연결 탭 검색창 + 업종별 묶음

**Files:**
- Modify: `jurini_app/lib/main.dart` (`_LinksState.build`의 회사 칩 줄)
- Test: `jurini_app/test/screens_test.dart`

**Interfaces:**
- Produces: `Map<String, List<String>> linkedBySector()` — 업종(회사 `group` ?? `sector` ?? '기타') → 연결 있는 티커 목록(연결 많은 순).

- [ ] **Step 1: 실패하는 테스트** `'연결: 검색하면 회사가 좁혀지고 업종 묶음을 펼쳐 고른다'`
  - `linkedBySector().values.expand((x) => x).toSet()`가 `linkedIds().toSet()`와 같다.
  - 검색창에 `'엔비'` 입력 → `find.widgetWithText(ChoiceChip, '엔비디아')` 1개, `'애플'` 칩 0개.
  - 업종 묶음(ExpansionTile) 하나를 열고 첫 회사를 누르면 `'이어진 회사 N곳'` 제목이 그 회사로 바뀐다.
- [ ] **Step 2:** `C:/flutter/bin/flutter test test/screens_test.dart` → 새 테스트 FAIL.
- [ ] **Step 3:** 구현. 맨 위 TextField(힌트 "회사 이름이나 티커로 찾기"); 검색어가 있으면 결과 칩만, 없으면 업종별 `ExpansionTile`(제목 "업종 · N곳") 안에 칩. 고른 뒤 그림·카드는 지금 그대로.
- [ ] **Step 4:** `flutter analyze` 0건, `flutter test` 전부 PASS.
- [ ] **Step 5:** 커밋 `연결 탭: 회사 검색, 업종별 묶음`.

### Task 2: 뉴스에 '오늘의 시장' 칸 + 뉴스별 관련 용어(terms·learn)

**Files:**
- Modify: `check_news.py`, `jurini_app/lib/main.dart`(`validNews`, `NewsPage`), 뉴스 예약 작업 프롬프트(RemoteTrigger `trig_01GFcC4Fbiyqms6iG4s7WRLA`)
- Test: `check_news.py` selfcheck, `jurini_app/test/screens_test.dart`

**Interfaces:**
- Produces (news.json 형식): 최상위 `"market": [item…]`(2~4개, 금리·물가·환율·증시 전체 흐름), 모든 item에 선택 필드 `"terms": [용어 id 1~3개]`, `"learn": "이 뉴스를 그 용어로 읽는 법" (120자 이내)`. item의 기존 필드(date,type,title,impact,source,url) 그대로.
- Produces (Dart): `List<J> marketNews()` — `news['market']`가 없으면 `[]`.

- [ ] **Step 1: selfcheck에 실패 케이스 추가** — `terms`에 사전에 없는 id → 오류, `learn` 121자 → 오류, `market` 5개 → 오류, `market` 없음 → 통과(예전 데이터 호환).
- [ ] **Step 2:** `python check_news.py` → selfcheck AssertionError.
- [ ] **Step 3:** 구현. 용어 id 집합 = `glossary.json` ∪ `docs/glossary_ai.json`(없으면 빈 집합). `problems()`가 `market`도 같은 규칙으로 검사.
- [ ] **Step 4:** Dart 테스트 `'뉴스: 오늘의 시장 칸, 예전 데이터도 그대로'` — `news`에 `market` 2개 넣으면 뉴스 탭 맨 위 `'오늘의 시장'` 제목과 두 제목이 보임; `market` 없는 데이터면 제목 없음, 예외 없음. `validNews`가 `market`을 보존하는지도 확인.
- [ ] **Step 5:** 구현: 뉴스 탭 '뉴스' 화면, 안내문 아래 '오늘의 시장' 칸(기존 `groupRow` 카드 모양, 회사 로고 대신 `Icons.public`). `python check_news.py`, `flutter test` PASS.
- [ ] **Step 6:** 뉴스 예약 작업 프롬프트에 추가: "`market` 2~4개(시장 전체 흐름, 왜 움직였는지), 모든 항목에 `terms`(용어사전 id만, jurini_app/assets/glossary.json·docs/glossary_ai.json에서 고름)와 `learn`." `RemoteTrigger update` 후 `run` 한 번, `list_runs`/`get_run_log`로 커밋 확인.
- [ ] **Step 7:** 커밋 `뉴스: 오늘의 시장 칸, 뉴스별 관련 용어`.

### Task 3: 5단계 코스 수업 25개(A) + 수업 검사기

**Files:**
- Create: `jurini_app/assets/lessons.json`, `check_lesson.py`
- Modify: `glossary_more.py`(빠진 용어 `stock`(주식) 추가), `jurini_app/pubspec.yaml`(asset), `CLAUDE.md`
- Test: `check_lesson.py` selfcheck

**Interfaces:**
- Produces (lessons.json): `{"stages":[{"id":1..5,"title","goal"(이 단계를 마치면 읽을 수 있는 뉴스 예시 문장),"lessons":[{"id":"s1l1","title","terms":[id…],"cards":[str×4~5],"quiz":[{"q","options":[str×4],"answer":0..3,"explain"}]×3}]}]}`
- Produces (Python): `lesson_problems(lesson: dict, term_ids: set, ai: bool=False) -> list[str]` — `ai=True`면 `stage`(1~5), `date`, `verified is True`, `sources`(https 1개 이상) 추가 검사. `main()`은 `assets/lessons.json`(A)과, 있으면 `docs/lesson_today.json`·`docs/lessons_ai.json`·`docs/glossary_ai.json`(B)을 검사.
- 단계·용어: 스펙 5-1의 순서와 용어. 단계당 4~6개, 합계 약 25개. 퀴즈 3문제 중 1개 이상은 "이 뉴스 제목이 무슨 뜻일까요?" 형 (단계 goal과 연결).

- [ ] **Step 1: selfcheck 실패 케이스** — 카드 3장, 카드 91자, 퀴즈 2개, answer 4, 없는 용어 id, 금지 표현(`'오를 것'`), ai=True인데 `verified` 없음 → 각각 오류 1개 이상. 올바른 샘플 → `[]`.
- [ ] **Step 2:** `python check_lesson.py` → 파일 없음/AssertionError.
- [ ] **Step 3:** `check_lesson.py` 구현(BANNED·PRICE는 `check_news`에서 import).
- [ ] **Step 4:** `glossary_more.py`에 `stock` 추가(분야 '주식 기본'), `python build.py`.
- [ ] **Step 5:** 수업 25개 작성 → `lessons.json`. 숫자·사실(예: FOMC 연 8회)은 공식 출처로 확인.
- [ ] **Step 6:** 사실 확인: 새 서브에이전트에게 `lessons.json` 전체를 주고 "틀리거나 오해 소지 있는 문장만 목록으로(근거 url)" 요청 → 지적 반영.
- [ ] **Step 7:** `python check_lesson.py` → `통과`. pubspec에 `assets/lessons.json` 추가.
- [ ] **Step 8:** 커밋 `배우기: 5단계 수업 25개, 수업 검사기`.

### Task 4: 배우기 탭 (첫 화면, 오늘의 시장 한눈에, 오늘의 10분, 수업 화면, 진도 저장)

**Files:**
- Create: `jurini_app/lib/learn.dart` (`part of 'main.dart';`)
- Modify: `jurini_app/lib/main.dart`(`part 'learn.dart';`, `lessons` 전역 로드, `Shell` 탭 순서·첫 화면, `QuizPage`는 배우기 탭 안으로), `jurini_app/pubspec.yaml`(`shared_preferences`)
- Test: `jurini_app/test/learn_test.dart`

**Interfaces:**
- Consumes: `lessons.json` 형식(Task 3), `marketNews()`(Task 2), `calendar` 전역, `makeQuiz`.
- Produces:
  - `class Progress { Set<String> done; Set<String> learned; Map<String,int> wrong; Set<String> days; String toJson(); static Progress fromJson(String? s); }` — `fromJson`은 null·깨진 값이면 빈 진도.
  - `Future<Progress> loadProgress()` / `Future<void> saveProgress(Progress p)` — prefs 키 `'progress_v1'`.
  - `J? nextLesson(J lessons, Progress p)` — 아직 안 끝낸 첫 수업, 다 끝냈으면 null.
  - `int weekDays(Progress p, DateTime now)` — 이번 주(월요일 시작) 공부한 날 수.
  - `List<J> reviewTerms(Progress p, Map<String, dynamic> glossary, Random rnd)` — 틀린 용어 먼저, 그다음 배운 용어에서 무작위, 최대 3개.
  - `void finishLesson(Progress p, J lesson, List<String> wrongTermIds, DateTime now)` — done·learned·days 갱신, 맞힌 용어는 wrong에서 지움.
  - 위젯: `LearnPage`, `LessonPage(J lesson, {bool ai})`.

- [ ] **Step 1: 실패하는 단위 테스트** (`learn_test.dart`)
  - `Progress.fromJson(null)`, `fromJson('{깨짐')` → `done.isEmpty`.
  - `nextLesson`: 아무것도 안 했으면 `'s1l1'`; `s1l1` 끝내면 `'s1l2'`; 전부 끝내면 null.
  - `weekDays`: 같은 날 두 번 → 1; 지난주 일요일 + 이번 주 월·수 → 2 (now=수요일).
  - `reviewTerms`: wrong에 있는 용어가 첫 번째; learned가 비면 `[]`.
  - `finishLesson` 후 `toJson`/`fromJson` 왕복이 같은 값.
- [ ] **Step 2:** `flutter test test/learn_test.dart` → FAIL(없는 이름).
- [ ] **Step 3:** 위 함수들 구현, `shared_preferences` 추가(`flutter pub add shared_preferences`).
- [ ] **Step 4:** 단위 테스트 PASS.
- [ ] **Step 5: 위젯 테스트**(`SharedPreferences.setMockInitialValues({})`)
  - 첫 화면이 배우기 탭: `MaterialApp(home: Shell())`에서 `'오늘의 10분'` 보임, 하단 첫 탭 라벨 `'배우기'`, `'퀴즈'` 탭 없음.
  - 오늘의 시장 한눈에: `calendar`에 오늘 일정 1개 + `news['market']` 1개 → 둘 다 보임; 둘 다 없으면 칸이 사라지고 예외 없음(Review Focus 1).
  - ① 누르면 `LessonPage`: 카드 넘김 → 퀴즈 3문제 → 끝 화면 → 돌아오면 ①이 다음 수업 제목.
  - 모든 수업 done + AI 수업 없음 → ①자리 `'오늘은 복습만 해요'`(Review Focus 3).
  - '자유 퀴즈' 버튼 → 기존 `QuizPage`.
- [ ] **Step 6:** UI 구현(impeccable 기준, 기존 `groupRow`·`box`·`explain` 재사용). 배우기 탭 순서: 오늘의 시장 한눈에(`accentSoft` 칸) → 오늘의 10분(① 수업 ② 뉴스 읽기: 배운 용어와 겹치는 `terms`를 가진 뉴스 우선, 없으면 market 첫 뉴스, `learn` 문장 표시 ③ 복습 퀴즈 3문제) → 이번 주 N일 · 5단계 중 N단계 → 코스 지도(단계별 수업 목록, 끝낸 것 체크) → 보너스 AI 수업(Task 5) → 자유 퀴즈 → 맨 아래 한 줄 "진도는 이 폰에만 저장돼요. 앱을 지우면 사라져요." 수업 카드는 `PageView`, 용어는 `term()` 형광펜.
- [ ] **Step 7:** 실제 글꼴 스크린샷(임시 golden 테스트, 확인 후 삭제)로 배우기 탭·수업 화면 확인, 어색한 줄바꿈·겹침 수정.
- [ ] **Step 8:** `flutter analyze` 0건, `flutter test` 전부 PASS. 커밋 `배우기 탭: 첫 화면, 오늘의 10분, 수업, 진도 저장`.

### Task 5: 매일 AI 수업(B) + 사실 확인 + AI 용어

**Files:**
- Create: 예약 작업(RemoteTrigger create). `docs/lesson_today.json` 등은 작업이 처음 돌 때 생긴다(그 전엔 파일 없음 = 앱은 보너스 칸을 숨김).
- Modify: `jurini_app/lib/main.dart`(`loadLive`: `lesson_today.json`·`lessons_ai.json`·`glossary_ai.json` 받기 + 검증), `jurini_app/lib/learn.dart`(보너스 수업 칸, AI 수업 보관함, 사전 합치기), `CLAUDE.md`
- Test: `check_lesson.py` selfcheck(이미 Task 3), `jurini_app/test/learn_test.dart`

**Interfaces:**
- Consumes: `lesson_problems(..., ai=True)`(Task 3), `LessonPage(lesson, ai: true)`(Task 4).
- Produces:
  - `docs/lesson_today.json` = 수업 1개(Task 3 형식 + `stage`, `date`, `verified`, `sources`, `news_url`).
  - `docs/lessons_ai.json` = `{"lessons":[…최근 60일]}`, `docs/glossary_ai.json` = `{"terms":[{id,term,definition,example,why,category,verified,sources}]}`.
  - Dart: `bool validAiLesson(J j)`, `void mergeAiGlossary(J g)` — `terms`·`G`에 `ai: true`로 추가(같은 id가 이미 있으면 무시).
- [ ] **Step 1: 실패하는 테스트** — `validAiLesson`: verified 없음 → false, 올바른 것 → true. `mergeAiGlossary`: 새 id 추가되고 기존 id 덮어쓰지 않음. 용어 팝업에 `'AI가 추가한 용어'` 표시. 보너스 칸: AI 수업 stage 4, 진도 2단계 → `'4단계 내용이에요'` 안내.
- [ ] **Step 2:** FAIL 확인 → 구현 → PASS.
- [ ] **Step 3:** 예약 작업 만들기(매일 07:30 KST = `30 22 * * *`, Sonnet 5.5, 이 저장소, 커넥터 없음). 프롬프트 단계: (1) `git pull --rebase` (2) `docs/news.json`(market 우선)에서 배울 거리 큰 뉴스 1개로 수업 작성, 사전에 없는 용어는 새 용어로 (3) **사실 확인 단계**: 카드·퀴즈·새 용어의 사실 문장마다 WebSearch(공식 도메인 우선)로 확인, 틀리면 고치고 확인 못 하면 뺌, 확인 출처를 `sources`에, 끝나면 `verified: true` (4) `python check_lesson.py` 통과 (5) `lesson_today.json` 쓰기, `lessons_ai.json`에 추가(60일 넘은 것 삭제), 새 용어는 `glossary_ai.json`에 추가 (6) 이 세 파일만 커밋·푸시. 금지 표현 규칙 포함.
- [ ] **Step 4:** `run` 한 번 → `get_run_log`로 확인 → 만들어진 수업을 직접 읽어 품질 확인.
- [ ] **Step 5:** 커밋 `배우기: 매일 AI 수업(사실 확인), AI 추가 용어`.

### Task 6: 뉴스 → 배우기 칩, 마무리

**Files:**
- Modify: `jurini_app/lib/main.dart`(`NewsPage` 카드, `newsCard`, `openTerm`), `CLAUDE.md`
- Test: `jurini_app/test/screens_test.dart`

**Interfaces:**
- Consumes: 뉴스 item `terms`·`learn`(Task 2), `lessons`(Task 3), `LessonPage`(Task 4).
- Produces: `J? lessonForTerm(String termId)` — 그 용어를 `terms`에 가진 첫 A 수업.
- [ ] **Step 1: 실패하는 테스트** — terms 있는 뉴스 카드에 `'이 뉴스 이해하기'`와 용어 칩; 칩 누르면 용어 팝업에 `'수업으로 배우기'` 버튼(그 용어를 다루는 수업이 있을 때만); terms 없는 예전 뉴스 → 칩 없음, 예외 없음(Review Focus 4).
- [ ] **Step 2:** FAIL → 구현 → PASS.
- [ ] **Step 3:** CLAUDE.md 갱신(배우기 탭, 새 파일·예약 작업 3개, 탭 순서), `flutter analyze`/`flutter test` 전부 PASS.
- [ ] **Step 4:** 커밋·푸시, release APK 빌드해 바탕화면 `주린이기업노트.apk`로 복사(USB 연결돼 있으면 `adb install -r`).
