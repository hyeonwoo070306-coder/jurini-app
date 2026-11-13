# 주린이 기업 노트 로고 키트

**생각:** 노트의 여백선이 새싹으로 자란다. 주식을 막 시작한 사람이 회사를 공부하며 자라는 노트. (2026-11-13, 시안 C 채택)

## 파일
| 파일 | 쓰는 곳 |
|---|---|
| `jurini-symbol.svg` / `-dark.svg` | 심볼 (밝은 바탕 / 어두운 바탕) |
| `jurini-horizontal.svg` / `-dark.svg` | 가로 로고 (심볼 + 글자). 앱 소개, 웹, 카드뉴스 |
| `jurini-stacked.svg` / `-dark.svg` | 세로 로고. 정사각형 자리 |
| `jurini-app-icon.svg` | 앱 아이콘 (남색 타일) |
| `jurini-adaptive-foreground.svg` | 안드로이드 적응형 아이콘 전경 (배경색 `#121831`) |
| `android/mipmap-*/ic_launcher.png` | 안드로이드 런처 아이콘 5개 크기. `jurini_app/android/app/src/main/res/`에 덮어쓰면 적용 (아직 적용 안 함) |
| `play/play-store-icon-512.png` | 플레이스토어 등록용 512px |
| `*-black.svg`, `*-white.svg`, `*-mono-4f6bff.svg`, `*-square.svg` + PNG | 한 가지 색 버전, 프로필 사진용 |

다시 만들기: `python brand/make_brand.py` (fonttools 필요) → 변형은 로고 디자인 스킬의 `export_variants.py`.

## 색
| 이름 | HEX | 쓰는 곳 |
|---|---|---|
| 남색 (잉크) | `#121831` | 밝은 바탕의 심볼·글자, 앱 아이콘 타일 |
| 새싹 파랑 (밝은 바탕) | `#4F6BFF` | 밝은 바탕의 잎 |
| 새싹 파랑 (어두운 바탕) | `#7C9CFF` | 어두운 바탕의 잎 = 앱 포인트색 |
| 흰 잉크 | `#F2F4F6` | 어두운 바탕의 심볼·글자 |

## 글자
Pretendard ExtraBold를 윤곽선으로 바꿔 넣음 (SIL OFL, 로고 사용 가능). 글자 사이는 기본보다 2% 좁힘.

## 규칙
- **여백:** 로고 둘레에 노트 줄 하나 굵기(심볼 높이의 약 8%)의 2배 이상 비운다.
- **최소 크기:** 심볼 16px, 가로 로고 높이 24px.
- **잎만 색**을 바꿀 수 있다. 줄·여백선은 잉크색 하나.
- 하지 말 것: 늘이거나 기울이기, 그림자·그라데이션 넣기, 잎을 다른 모양으로 바꾸기, 화살표·차트와 함께 쓰기, 사진 위에 대비 없이 올리기.

## 남은 일
- 출시 전 특허청(키프리스)에서 비슷한 상표 검색.
- 앱에 적용: `android/` 아이콘을 앱 res 폴더에 복사하고 새 APK 빌드.
