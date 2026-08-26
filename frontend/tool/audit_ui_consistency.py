#!/usr/bin/env python3
"""UI 일관성 정적 검수 — "불일치·비대칭" 클래스를 세어 리포트한다.

왜 이 파일이 있나 (2026-08-20 실측)
-----------------------------------
사용자 지적: "거래 추가 시 -1일 전/+1일 후 문구의 왼쪽 여백이 더 길다."
위젯 기하 측정 결과 버튼의 좌우 여백은 **정확히 같았다**(57.30 / 57.30).
어긋난 것은 **라벨**이다 — `*Button.icon` 은 `아이콘+간격+라벨` 을 한 덩어리로
중앙 정렬하므로 라벨만 보면 `아이콘폭 + 간격`(=24dp) 만큼 오른쪽으로 밀린다.

`check_ui_scaling.py` 는 "리터럴이 몇 개냐"를 센다. 이 파일은 "같은 역할인데 값·구조가
갈렸냐"를 센다. 크기 체계가 갖춰져도 **비대칭·중복 축**은 따로 남기 때문이다.

사용법
------
    python3 tool/audit_ui_consistency.py            # 요약
    python3 tool/audit_ui_consistency.py --detail   # 위치 전부
    python3 tool/audit_ui_consistency.py --class A  # 특정 클래스만
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "lib"

# ── 클래스 정의 ──────────────────────────────────────────────────────────────
# A: 폭을 채우는 자리의 `*Button.icon` → 라벨이 아이콘폭+간격만큼 오른쪽으로 밀린다
BUTTON_ICON = re.compile(r"\b(?:Text|Outlined|Elevated|Filled)Button\.icon\(")
FULL_WIDTH_HINT = re.compile(
    r"Expanded\(|SizedBox\(\s*width:\s*double\.infinity|"
    r"minimumSize:\s*(?:const\s+)?Size\.fromHeight|"
    r"CrossAxisAlignment\.stretch|double\.infinity"
)

# B: 좌우 비대칭 여백
ONLY_LR = re.compile(r"EdgeInsets\.only\(([^)]*)\)")
FROM_LTRB = re.compile(r"EdgeInsets\.fromLTRB\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)")

# C: 버튼 style 의 수평 패딩 0 (세로만 지정) — 라벨이 테두리에 붙거나 테마 패딩과 갈린다.
# ★`styleFrom(` 스코프 안에서만 센다. 일반 `Padding(vertical:)` 은 정당한 사용이라
# 넓게 잡으면 노이즈가 53건 중 40건이었다(2026-08-20 실측).
VERTICAL_ONLY_PADDING = re.compile(r"padding:\s*(?:const\s+)?EdgeInsets\.symmetric\(\s*vertical:")
STYLE_FROM = re.compile(r"\bstyleFrom\(|\bButtonStyle\(")

# D: 테마 밀도와 경쟁하는 국소 override
LOCAL_DENSITY = re.compile(r"visualDensity:\s*(?:const\s+)?VisualDensity")

# E: 프레임워크 타일 — 밀도 계약 밖
LIST_TILE = re.compile(r"\bListTile\(|\bCheckboxListTile\(|\bSwitchListTile\(|\bRadioListTile\(")

# F: 하드코딩 색
HARD_COLOR = re.compile(r"Color\(0x[0-9a-fA-F]{8}\)|Colors\.[a-z]+(?:\[\d+\]|\.shade\d+)?")

# G: 화면이 직접 폭을 읽는다(컨테이너 폭 판정 위반)
WIDTH_READ = re.compile(r"MediaQuery\.(?:of\(context\)\.size|sizeOf\(context\))\.width")

# H: 같은 역할에 값이 몇 종류인가 — "불일치" 의 직접 지표
VALUE_KINDS = {
    "radius": re.compile(r"BorderRadius\.circular\(\s*([\d.]+)"),
    "sizedBox": re.compile(r"SizedBox\(\s*(?:width|height):\s*([\d.]+)"),
    "edgeAll": re.compile(r"EdgeInsets\.all\(\s*([\d.]+)"),
}

CLASSES = {
    "A": "폭 채우는 자리의 Button.icon — 라벨이 중앙에서 벗어난다",
    "B": "좌우 비대칭 여백 (only/fromLTRB)",
    "C": "버튼 padding 이 세로만 지정 (수평 0)",
    "D": "국소 visualDensity override — 테마 밀도와 경쟁",
    "E": "ListTile 계열 — 타일 밀도 계약 밖",
    "F": "하드코딩 색",
    "G": "화면이 MediaQuery 폭을 직접 읽는다",
    "H": "같은 역할에 값이 여러 종류 (토큰 사다리는 7종 — 2026-08-26 `block` 신설)",
}

BASELINE = ROOT / "tool/ui_consistency_baseline.json"


def code_lines(path: pathlib.Path) -> list[tuple[int, str]]:
    out = []
    for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        s = line.lstrip()
        if s.startswith("//") or s.startswith("///"):
            continue
        out.append((i, line))
    return out


def asym_only(body: str) -> tuple[float, float] | None:
    left = re.search(r"\bleft:\s*([\d.]+)", body)
    right = re.search(r"\bright:\s*([\d.]+)", body)
    lv = float(left.group(1)) if left else 0.0
    rv = float(right.group(1)) if right else 0.0
    if not left and not right:
        return None
    if abs(lv - rv) < 0.01:
        return None
    return lv, rv


def scan():
    hits: dict[str, list[tuple[str, int, str]]] = collections.defaultdict(list)
    kinds: dict[str, collections.Counter] = {k: collections.Counter() for k in VALUE_KINDS}
    for path in sorted(UI_DIR.rglob("*.dart")):
        rel = path.relative_to(ROOT).as_posix()
        lines = code_lines(path)
        text_by_no = dict(lines)
        for no, line in lines:
            if BUTTON_ICON.search(line):
                # 앞뒤 4줄에 폭을 채우는 힌트가 있으면 A
                window = " ".join(
                    text_by_no.get(n, "") for n in range(no - 4, no + 8)
                )
                if FULL_WIDTH_HINT.search(window):
                    hits["A"].append((rel, no, line.strip()[:110]))
            for m in ONLY_LR.finditer(line):
                got = asym_only(m.group(1))
                if got:
                    hits["B"].append((rel, no, f"only(left:{got[0]}, right:{got[1]})"))
            for m in FROM_LTRB.finditer(line):
                l, _t, r, _b = (float(x) for x in m.groups())
                if abs(l - r) >= 0.01:
                    hits["B"].append((rel, no, f"fromLTRB(l={l}, r={r})"))
            if VERTICAL_ONLY_PADDING.search(line):
                back = " ".join(text_by_no.get(n, "") for n in range(no - 4, no + 1))
                if STYLE_FROM.search(back):
                    hits["C"].append((rel, no, line.strip()[:110]))
            if LOCAL_DENSITY.search(line):
                hits["D"].append((rel, no, line.strip()[:110]))
            if LIST_TILE.search(line):
                hits["E"].append((rel, no, line.strip()[:110]))
            for m in HARD_COLOR.finditer(line):
                hits["F"].append((rel, no, m.group(0)))
            # `bb_scale.dart` 는 폭 조회의 **인가된 단독 소유자**다(BbScaleScope 폴백).
            if WIDTH_READ.search(line) and rel != "lib/core/theme/bb_scale.dart":
                hits["G"].append((rel, no, line.strip()[:110]))
            for kind, pat in VALUE_KINDS.items():
                for v in pat.findall(line):
                    if v not in ("0", "0.0", "1", "1.0", "0.5"):
                        kinds[kind][v] += 1
    for kind, counter in kinds.items():
        for value, n in sorted(counter.items(), key=lambda kv: -kv[1]):
            hits["H"].append((f"{kind}={value}", n, f"{n} sites"))
    return hits


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--detail", action="store_true")
    ap.add_argument("--class", dest="klass")
    ap.add_argument("--update", action="store_true", help="기준선 갱신(줄었을 때만)")
    args = ap.parse_args()

    hits = scan()
    print("=" * 66)
    print("  UI 일관성 검수")
    print("=" * 66)
    for key, desc in CLASSES.items():
        if args.klass and args.klass != key:
            continue
        rows = hits.get(key, [])
        files = {r[0] for r in rows}
        print(f"\n[{key}] {desc}")
        print(f"    건수 {len(rows)} · 파일 {len(files)}")
        if not rows:
            continue
        per_file = collections.Counter(r[0] for r in rows)
        for rel, n in per_file.most_common(8 if not args.detail else 10_000):
            print(f"      {n:4d}  {rel}")
        if args.detail:
            for rel, no, snip in rows:
                print(f"        {rel}:{no}  {snip}")

    # ── ratchet ─────────────────────────────────────────────────────────────
    counts = {k: len(hits.get(k, [])) for k in CLASSES}
    if args.update:
        BASELINE.write_text(json.dumps(counts, indent=2, sort_keys=True) + "\n")
        print("\n기준선 갱신:", counts)
        return 0
    if not BASELINE.exists():
        print("\n⚠ 기준선 없음 — `--update` 로 생성하라")
        return 0
    base = json.loads(BASELINE.read_text())
    grown = {k: (base.get(k), v) for k, v in counts.items() if v > base.get(k, 0)}
    print("\n" + "=" * 66)
    if grown:
        for k, (was, now) in grown.items():
            print(f"❌ [{k}] {was} → {now} 로 늘었다 — {CLASSES[k]}")
        print("UI 일관성 래칫 실패: 위 클래스를 기준선 이하로 되돌려라")
        return 1
    lowered = {k: (base.get(k), v) for k, v in counts.items() if v < base.get(k, 0)}
    if lowered:
        for k, (was, now) in lowered.items():
            print(f"✅ [{k}] {was} → {now} 로 줄었다")
        print("`--update` 로 기준선을 낮춰라")
    print("UI 일관성 래칫 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
