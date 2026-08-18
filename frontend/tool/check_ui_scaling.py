#!/usr/bin/env python3
"""UI 크기 리터럴 ratchet 게이트 — 고정 px 가 다시 새어 들어오는 것을 막는다.

왜 이 파일이 있나
-----------------
2026-08-14 실측: `lib/ui` 101파일 중 `CalSizes` 를 쓰는 파일은 **30개**뿐이고
크기 리터럴이 fontSize 144 · EdgeInsets 150 · SizedBox 102 · radius 70 건 있었다.
같은 값이 `fontSize: 12`(26곳)와 `12 * scale`(4곳)로 **공존**했다.

토큰(`BbType`/`BbSpace`)을 **추가**하는 것만으로는 이 상태가 고쳐지지 않는다.
같은 자리의 리터럴이 남아 있으면 그게 경쟁 경로이고, 축이 3개에서 4개로 늘 뿐이다
(하네스 `ui_pattern` 인시던트 2026-08-11 과 같은 실패 모드: "경로를 추가했다"가
아니라 "경쟁 경로를 0개로 만들었다"가 완료 기준이다).

그래서 이 게이트는 두 가지를 동시에 강제한다.

1. **ratchet** — 영역별 리터럴 수가 기준선보다 **늘면 exit 1**. 줄면 통과하고
   기준선을 낮추라고 안내한다.
2. **시범 범위 잔존 0** — `PILOT_FILES` 는 리터럴이 **0** 이어야 한다. ratchet 만
   있으면 "다른 파일에서 줄이고 여기서 늘리기"가 통과하므로 이관 완료한 파일은
   따로 못 박는다.

허용 목록(L4)
-------------
`0` `1` `0.5` `44` 만 허용한다(hairline/보더 · 의미상 없음/최소 · 터치 타깃 하한).
그 밖에 불가피한 고정 px 는 같은 줄에 `// ui-fixed: <이유>` 를 달면 제외되지만
**건수는 리포트**된다 — 숨지 못하게.

알려진 한계
-----------
스캔은 **줄 단위**라 여러 줄로 쪼개진 `EdgeInsets.symmetric(\\n horizontal: 12,\\n ...)`
는 세지 못한다. 따라서 `dart format` 이 줄을 합치거나 쪼개면 총계가 몇 건 흔들린다
(실제로 407 ↔ 404 로 움직였다). ratchet 으로 쓰는 데는 문제가 없다 — 포맷이 CI 로
고정돼 있어 같은 상태에서는 같은 값이 나온다. **기준선 갱신은 `dart format` 뒤에**
할 것.

사용법
------
    python3 tool/check_ui_scaling.py             # 검사(기본)
    python3 tool/check_ui_scaling.py --update    # 기준선 갱신(줄었을 때만 쓸 것)
    python3 tool/check_ui_scaling.py --report    # 파일별 상세
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "lib"
BASELINE = ROOT / "tool/ui_scaling_baseline.json"

# L4 허용 목록 — 이 값들은 크기가 아니라 경계/하한/무(無)다.
ALLOWED = {"0", "0.0", "1", "1.0", "0.5", "44", "44.0"}

# 예외 주석. 같은 줄에 있으면 그 줄은 세지 않고 별도 집계된다.
ESCAPE_HATCH = re.compile(r"//\s*ui-fixed:")

_NUM = r"(?<![\w.])(\d+(?:\.\d+)?)"

PATTERNS: dict[str, re.Pattern[str]] = {
    # fontSize: 12  /  fontSize: 12.5
    "fontSize": re.compile(r"\bfontSize:\s*" + _NUM),
    # EdgeInsets.all(8) / .symmetric(horizontal: 12) / .only(top: 4) / .fromLTRB(...)
    "edgeInsets": re.compile(r"\bEdgeInsets\.\w+\([^)]*?" + _NUM),
    # SizedBox(width: 8) / SizedBox(height: 12)
    "sizedBox": re.compile(r"\bSizedBox\([^)]*?\b(?:width|height):\s*" + _NUM),
    # BorderRadius.circular(6)
    "radius": re.compile(r"\bBorderRadius\.circular\(\s*" + _NUM),
    # Icon(size: 18)
    "iconSize": re.compile(r"\bsize:\s*" + _NUM),
}

# ★시범 이관 완료 파일 — 리터럴 잔존이 0 이어야 한다(구조적 수정 S2).
PILOT_FILES = [
    # 2026-08-18 회차 시범 범위 — 분석 탭 크롬. 이 파일들은 리터럴 0 이어야 한다.
    "lib/features/analysis/presentation/pages/analysis_page.dart",
    "lib/core/widgets/bb_tab.dart",
    "lib/core/widgets/month_navigator.dart",
]


def area_of(rel: str) -> str:
    """`lib/features/<area>/...` → `<area>`. 그 밖은 `_<top>`."""
    parts = rel.split("/")
    if len(parts) > 2 and parts[1] == "features":
        return parts[2]
    if len(parts) > 1:
        return f"_{parts[1]}"
    return "_other"


def scan() -> tuple[dict[str, int], dict[str, int], int]:
    """(영역별 건수, 파일별 건수, ui-fixed 주석 건수)."""
    per_area: dict[str, int] = {}
    per_file: dict[str, int] = {}
    escaped = 0

    for path in sorted(UI_DIR.rglob("*.dart")):
        rel = path.relative_to(ROOT).as_posix()
        count = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = line.lstrip()
            # 주석 줄은 세지 않는다(문서에 적힌 숫자는 코드가 아니다).
            if stripped.startswith("//") or stripped.startswith("///"):
                continue
            if ESCAPE_HATCH.search(line):
                escaped += 1
                continue
            for pattern in PATTERNS.values():
                for value in pattern.findall(line):
                    if value not in ALLOWED:
                        count += 1
        if count:
            per_file[rel] = count
            per_area[area_of(rel)] = per_area.get(area_of(rel), 0) + count

    return per_area, per_file, escaped


def load_baseline() -> dict:
    if not BASELINE.exists():
        return {}
    return json.loads(BASELINE.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update", action="store_true", help="기준선을 현재 값으로 갱신")
    parser.add_argument("--report", action="store_true", help="파일별 상세 출력")
    args = parser.parse_args()

    per_area, per_file, escaped = scan()
    total = sum(per_area.values())

    if args.report:
        for rel, count in sorted(per_file.items(), key=lambda kv: -kv[1]):
            print(f"  {count:4d}  {rel}")
        print()

    if args.update:
        BASELINE.write_text(
            json.dumps(
                {"total": total, "areas": dict(sorted(per_area.items()))},
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"✅ 기준선 갱신: total={total}, 영역 {len(per_area)}개 → {BASELINE}")
        return 0

    baseline = load_baseline()
    if not baseline:
        print("기준선이 없다. 먼저 `--update` 로 박아라.", file=sys.stderr)
        return 2

    failures: list[str] = []

    # ── ① ratchet: 영역별로 늘었는가 ────────────────────────────────────────
    base_areas: dict[str, int] = baseline.get("areas", {})
    for area in sorted(set(base_areas) | set(per_area)):
        now = per_area.get(area, 0)
        was = base_areas.get(area, 0)
        if now > was:
            failures.append(f"[{area}] 크기 리터럴이 늘었다: {was} → {now} (+{now - was})")

    # ── ② 시범 범위 잔존 0 ──────────────────────────────────────────────────
    for rel in PILOT_FILES:
        count = per_file.get(rel, 0)
        if count:
            failures.append(f"[시범범위] {rel} 에 리터럴 {count}건 잔존 — 0 이어야 한다")

    print(f"UI 크기 리터럴: total={total} (기준선 {baseline.get('total', '?')})")
    if escaped:
        print(f"  ui-fixed 예외 주석: {escaped}건")
    for area, count in sorted(per_area.items(), key=lambda kv: -kv[1]):
        was = base_areas.get(area, 0)
        mark = "=" if count == was else ("↓" if count < was else "↑")
        print(f"  {mark} {area}: {count} (기준선 {was})")

    if failures:
        print("\n🚫 UI 크기 게이트 실패:", file=sys.stderr)
        for f in failures:
            print(f"   - {f}", file=sys.stderr)
        print(
            "\n   크기는 CalType/CalSpace 토큰으로 적는다"
            "(lib/ui/shared/themes/ui_scale.dart).\n"
            "   불가피하면 같은 줄에 `// ui-fixed: <이유>` 를 달아라.",
            file=sys.stderr,
        )
        return 1

    if total < baseline.get("total", total):
        print(
            f"\n✅ 통과 — 리터럴이 {baseline['total']} → {total} 로 줄었다. "
            "`--update` 로 기준선을 낮춰 되돌아가는 것도 막아라."
        )
    else:
        print("\n✅ 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
