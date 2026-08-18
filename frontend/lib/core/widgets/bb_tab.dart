import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_scale.dart';

/// 아이콘 + 라벨을 **가로**로 배치하는 탭.
///
/// 왜 이 헬퍼가 있나 `[1차: SDK material/tabs.dart 직접 확인]`:
/// `Tab(icon: …, text: …)` 는 `icon != null && text != null` 분기를 타서
/// `calculatedHeight = _kTextAndIconTabHeight`(**72**)를 쓴다(198-205행).
/// 아이콘을 `Tab.icon` 이 아니라 `Tab.child` 안의 `Row` 로 넣으면 `icon == null`
/// 이므로 `_kTabHeight`(**46**)가 된다 — **아이콘을 잃지 않고 26dp 를 돌려받는다**.
/// 나아가 `Tab` 은 `height` 파라미터를 이미 갖고 `preferredSize` 가 그대로
/// 반환하므로(221·234-235행) **토큰 주입이 프레임워크 지원 경로**다.
///
/// 분석 탭은 TabBar 가 2단 중첩이라 이 교체만으로 **−52dp** 다.
///
/// ★새 탭은 반드시 이 함수를 쓴다. `Tab(icon:` 직접 사용은 가드가 막는다
/// (`chrome_contract_guard_test.dart`).
Tab bbTab(
  BuildContext context, {
  required IconData icon,
  required String label,
}) {
  final type = context.bbType;
  return Tab(
    height: type.tabHeight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: type.iconSm),
        SizedBox(width: context.bbSpace.sm),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
