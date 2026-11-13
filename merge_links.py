"""기업 연결 데이터: links_research/links_*.json(조사 원본) → jurini_app/assets/links.json

규칙: 회사 공시(10-K·10-Q·사업보고서)나 공식 발표만. 출처가 홈페이지뿐이면 뺀다. 같은 두 회사·같은 종류는 하나만.
이름 없는 고객(UNNAMED)은 회사마다 따로 점을 만든다. 실행: python merge_links.py
"""
import glob, json, re, sys
from urllib.parse import urlparse
S = "links_research/"
A = "jurini_app/assets/"
app = set()
for f in ("companies.json", "sp500.json", "us_more.json", "kr.json"):
    app |= {c["ticker"] for c in json.load(open(A + f, encoding="utf-8"))["companies"]}
BANNED = re.compile(r"목표가|매수|매도|추천|사세요|파세요")
nodes, links, seen, n_unnamed = {}, [], set(), 0
for path in sorted(glob.glob(S + "links_[0-9].json")):
    d = json.load(open(path, encoding="utf-8"))
    for k, v in d.get("nodes", {}).items():
        if k not in app and k != "UNNAMED":
            nodes.setdefault(k, {"ko": v["ko"], "note": v.get("note", "")})
    for l in d["links"]:
        assert l["kind"] in ("supply", "partner", "compete"), l
        for f in ("from", "to", "what", "if_from", "if_to", "source", "url"):
            assert l.get(f), (path, f, l)
        assert l["url"].startswith("https://"), l["url"]
        if urlparse(l["url"]).path.strip("/") in ("", "worldwide/en/newsroom"):
            print("  - 출처가 홈페이지뿐이라 뺌:", l["from"], l["to"], l["source"])  # 원문을 못 짚는 연결은 싣지 않는다
            continue
        text = " ".join(str(l.get(f) or "") for f in ("what", "if_from", "if_to", "share"))
        assert not BANNED.search(text), text
        key = (frozenset((l["from"], l["to"])), l["kind"])
        if "UNNAMED" not in (l["from"], l["to"]):
            if key in seen:
                continue
            seen.add(key)
        for side in ("from", "to"):  # 이름 없는 고객은 회사마다 따로 (서로 이어진 것처럼 보이지 않게)
            if l[side] == "UNNAMED":
                n_unnamed += 1
                l[side] = f"UNNAMED{n_unnamed}"
                nodes[l[side]] = {"ko": "이름 비공개 고객", "note": "공시에 이름을 밝히지 않은 큰 고객"}
        links.append({k: l.get(k) for k in ("from", "to", "kind", "what", "if_from", "if_to", "share", "source", "url")})
used = {x for l in links for x in (l["from"], l["to"])}
nodes = {k: v for k, v in nodes.items() if k in used}
missing = used - app - set(nodes)
assert not missing, missing
json.dump({"asof": "2026-11-13", "note": "회사 공시(10-K·10-Q·사업보고서)와 공식 발표 기준", "nodes": nodes, "links": links},
          open(A + "links.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("links", len(links), "nodes", len(nodes), "files", len(glob.glob(S + "links_[0-9].json")))
