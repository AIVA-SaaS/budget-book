import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_scale.dart';

/// Layout density tier derived from the logical screen width.
enum BbDensityTier { compact, regular, wide }

/// The single place the app reads screen width to pick layout metrics.
///
/// Screens must not call `MediaQuery...size.width` themselves — guard S3
/// (`tile_contract_guard_test.dart`) fails the build if they do.
///
/// 2026-08-18: 폭 읽기의 단일 지점은 이제 `bb_scale.dart` 다. 이 클래스는 **타일
/// 밀도(L1 컨테이너 역산)** 를 담당하고, 폭은 [BbScaleScope] 를 경유해 받는다 —
/// 웹에서 화면 폭(2560)과 콘텐츠 폭(960)이 다르기 때문이다.
@immutable
class BbDensity {
  const BbDensity({
    required this.tier,
    required this.tilePaddingH,
    required this.tilePaddingV,
    required this.avatarSize,
    required this.avatarIconSize,
    required this.actionIconSize,
    required this.actionSlotSize,
    required this.toggleSlotWidth,
    required this.gap,
    required this.titleFontSize,
    required this.metricFontSize,
    required this.chipFontSize,
    required this.chipPaddingH,
    required this.headerLabelFontSize,
    required this.headerValueFontSize,
  });

  final BbDensityTier tier;

  /// Horizontal padding inside an entity tile.
  final double tilePaddingH;

  /// Vertical padding inside an entity tile.
  final double tilePaddingV;

  final double avatarSize;
  final double avatarIconSize;

  /// Rendered size of an action icon (toggle / menu / drag handle).
  final double actionIconSize;

  /// Tap target edge for an action slot. Never below 40dp (guard S4).
  final double actionSlotSize;

  /// Width reserved for the active toggle. A Material 3 [Switch] track is
  /// 52dp wide and cannot be narrowed by scaling — `Transform.scale` only
  /// repaints, it does not shrink the reserved width (2026-05-04 오진).
  final double toggleSlotWidth;

  /// Standard gap between tile elements.
  final double gap;

  final double titleFontSize;
  final double metricFontSize;
  final double chipFontSize;
  final double chipPaddingH;

  /// Summary-header label / value sizes (총자산·부채·순자산 cards).
  final double headerLabelFontSize;
  final double headerValueFontSize;

  /// `< 400dp` — phones in portrait, including the 320dp worst case.
  static const BbDensity compact = BbDensity(
    tier: BbDensityTier.compact,
    tilePaddingH: 10,
    tilePaddingV: 8,
    avatarSize: 32,
    avatarIconSize: 18,
    actionIconSize: 20,
    actionSlotSize: 40,
    toggleSlotWidth: 52,
    gap: 6,
    titleFontSize: 14,
    metricFontSize: 13,
    chipFontSize: 10,
    chipPaddingH: 5,
    headerLabelFontSize: 11,
    headerValueFontSize: 15,
  );

  /// `400 – 839dp` — large phones, small tablets.
  static const BbDensity regular = BbDensity(
    tier: BbDensityTier.regular,
    tilePaddingH: 14,
    tilePaddingV: 10,
    avatarSize: 38,
    avatarIconSize: 20,
    actionIconSize: 22,
    actionSlotSize: 44,
    toggleSlotWidth: 52,
    gap: 8,
    titleFontSize: 15,
    metricFontSize: 14,
    chipFontSize: 11,
    chipPaddingH: 6,
    headerLabelFontSize: 12,
    headerValueFontSize: 17,
  );

  /// `>= 840dp` — tablets and web.
  static const BbDensity wide = BbDensity(
    tier: BbDensityTier.wide,
    tilePaddingH: 16,
    tilePaddingV: 12,
    avatarSize: 40,
    avatarIconSize: 22,
    actionIconSize: 24,
    actionSlotSize: 48,
    toggleSlotWidth: 56,
    gap: 10,
    titleFontSize: 16,
    metricFontSize: 15,
    chipFontSize: 12,
    chipPaddingH: 8,
    headerLabelFontSize: 12,
    headerValueFontSize: 19,
  );

  static const double compactMaxWidth = 400;
  static const double regularMaxWidth = 840;

  /// Tier boundaries: `<400` compact, `[400, 840)` regular, `>=840` wide.
  static BbDensity forWidth(double width) {
    if (width < compactMaxWidth) return compact;
    if (width < regularMaxWidth) return regular;
    return wide;
  }

  /// 유효 콘텐츠 폭 기준. 폭 조회는 `bb_scale.dart` 가 단독으로 소유한다 —
  /// 이 클래스는 그 값을 받아 타일 밀도만 정한다.
  static BbDensity of(BuildContext context) =>
      forWidth(BbType.of(context).width);
}

/// `context.density.titleFontSize`
extension BbDensityContext on BuildContext {
  BbDensity get density => BbDensity.of(this);
}
