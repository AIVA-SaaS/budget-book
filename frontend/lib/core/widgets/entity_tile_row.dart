import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/asset_edit_mode_scope.dart';
import 'package:budget_book/core/widgets/one_line_label.dart';

/// Semantic tone for a badge or a metric. Resolved against [BbColors] — a
/// caller can never pass a raw palette color for these.
/// 진행 트랙 높이 — 값 유무와 무관하게 고정이다(행 간 높이 동일성).
const double kEntityProgressHeight = 6.0;

enum EntityTone {
  neutral,
  income,
  expense,
  transfer,
  budget,
  savings,
  warn,
  positive,
  negative,
  muted,
}

/// A small labelled badge (`기본`, `저축`, `비활성` …).
@immutable
class EntityBadge {
  const EntityBadge({
    required this.label,
    this.tone = EntityTone.neutral,
    this.color,
  });

  final String label;
  final EntityTone tone;

  /// A user-chosen color that has **already** been passed through
  /// `context.bb.readable()`. Overrides [tone] when given.
  final Color? color;
}

/// A labelled figure. [value] is already formatted — the tile never
/// reformats or abbreviates amounts.
@immutable
class EntityMetric {
  const EntityMetric({
    required this.value,
    this.label,
    this.tone = EntityTone.neutral,
  });

  final String value;
  final String? label;
  final EntityTone tone;

  String get display => label == null ? value : '$label $value';
}


/// A progress track shown between the title row and the subtitle.
///
/// ★값 타입이다 — 호출부가 임의 위젯을 끼워 넣지 못한다(가드 S1). 과거
/// `ui_pattern` 실패가 전부 "한 곳에 얹기" 형태였기 때문이다.
@immutable
class EntityProgress {
  const EntityProgress({
    required this.value,
    this.tone = EntityTone.neutral,
  });

  /// 0.0 ~ 1.0. 값이 없는 행도 **자리를 비우지 말고 0 을 넘겨라** — 자리를 비우면
  /// 그 행만 잉크가 낮아져 `박스 = max(잉크 + 2 × xs, 슬롯 44)` 가 행마다 갈린다.
  /// 2026-08-26 예산 화면의 "위아래 항목 높이가 다르다" 가 정확히 그 결함이었다.
  final double value;

  final EntityTone tone;
}

/// An always-visible overflow (⋮) menu placed in the trailing slot.
///
/// 슬롯은 세로 흐름 **밖**이라 행 높이를 늘리지 않는다(2026-08-24 계약).
/// [EntityTileActions] 와 달리 편집 모드가 아니어도 보인다.
@immutable
class EntityOverflowMenu {
  const EntityOverflowMenu({required this.items, required this.onSelected});

  final List<EntityMenuAction> items;
  final ValueChanged<String> onSelected;
}

/// One entry of the tile's overflow menu.
@immutable
class EntityMenuAction {
  const EntityMenuAction({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

/// A single always-visible icon action.
///
/// Deliberately narrow: one icon, one tooltip, one callback. Screens that have
/// no edit mode (e.g. the 자산 현황 card in 분석>예산) still need one live
/// affordance, and this keeps that from becoming a general widget slot.
@immutable
class EntityViewAction {
  const EntityViewAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// The three edit-mode slots: active toggle, overflow menu, drag handle.
@immutable
class EntityTileActions {
  const EntityTileActions({
    this.isActive,
    this.onActiveChanged,
    this.menu = const <EntityMenuAction>[],
    this.onMenuSelected,
    this.reorderIndex,
  });

  final bool? isActive;
  final ValueChanged<bool>? onActiveChanged;
  final List<EntityMenuAction> menu;
  final ValueChanged<String>? onMenuSelected;

  /// Index for [ReorderableDragStartListener]; null hides the drag handle.
  final int? reorderIndex;
}

/// The single row layout for every asset-tab entity (payment method,
/// category, pocket).
///
/// **Deliberately not a [ListTile]** — `ListTile` owns 32dp of horizontal
/// padding, a 16dp title gap and an unbounded trailing slot, which is how the
/// name got squeezed to 124dp on a 360dp phone. This widget owns the width
/// contract instead.
///
/// The API is sealed to value types (guard S1): [title] is a `String`, not a
/// `Widget`, so no caller can inject a layout that breaks the one-line rule.
class EntityTileRow extends StatelessWidget {
  const EntityTileRow({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const <EntityBadge>[],
    this.trailingMetric,
    this.metrics = const <EntityMetric>[],
    this.leadingIcon,
    this.leadingColor,
    this.dimmed = false,
    this.inactiveLabel = '비활성',
    this.onTap,
    this.actions,
    this.viewAction,
    this.progress,
    this.overflowMenu,
    this.keepMetricInline = false,
  });

  final String title;

  /// Secondary caption (`마감일: 15일, 결제일: 25일`). One line, shrink to fit.
  final String? subtitle;

  final List<EntityBadge> badges;

  /// The headline figure shown on the title row (balance, amount).
  final EntityMetric? trailingMetric;

  /// Additional figures rendered as chips below the title.
  final List<EntityMetric> metrics;

  final IconData? leadingIcon;

  /// Avatar tint. User-chosen colors must already be corrected via
  /// `context.bb.readable()` (guard S6).
  final Color? leadingColor;

  /// Renders the row as inactive: faded plus an [inactiveLabel] badge.
  final bool dimmed;

  final String inactiveLabel;

  final VoidCallback? onTap;

  /// Edit-mode actions. Only rendered while [AssetEditModeScope] is on.
  final EntityTileActions? actions;

  /// An always-visible icon action, shown only in view mode.
  final EntityViewAction? viewAction;

  /// ★진행 표시 슬롯 (2026-08-26 신설 — 예산 타일 이관).
  ///
  /// 제목과 부제목 **사이**에 들어간다. 이 슬롯을 쓰는 화면은 **모든 행에
  /// 빠짐없이** 넘겨야 한다 — 어떤 행에만 넘기면 그 행만 잉크가 낮아져
  /// 행 높이가 갈린다.
  final EntityProgress? progress;

  /// 항상 보이는 ⋮ 메뉴. 슬롯(세로 흐름 밖)이라 행 높이에 관여하지 않는다.
  final EntityOverflowMenu? overflowMenu;

  final bool keepMetricInline;

  @override
  Widget build(BuildContext context) {
    final editing = AssetEditModeScope.of(context) && actions != null;
    final space = context.bbSpace;
    final box = context.bbBox;
    final type = context.bbType;
    final bb = context.bb;
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;

    final effectiveBadges = <EntityBadge>[
      ...badges,
      if (dimmed) EntityBadge(label: inactiveLabel, tone: EntityTone.warn),
    ];

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Chrome the title row cannot use: padding, avatar, gaps.
        // ★액션·슬롯은 이제 이 Column 밖에 있다(아래 `body` 의 형제). 이
        // LayoutBuilder 가 이미 슬롯 폭을 뺀 제약을 받으므로 여기서 또 빼면
        // 이중 차감이다. 폭 항등식은 보존된다 `[증명]`:
        //   종전 (full − 2xl) − (2xl + slot + md)
        //   == 지금 (full − 2xl − slot − md) − 2xl
        // 그래서 금액을 제목 행에 둘지(inlineMetric) 판정은 바뀌지 않는다.
        var chrome = space.xl * 2;
        if (leadingIcon != null) chrome += box.avatar + space.md;
        final available = constraints.maxWidth - chrome;

        // In edit mode the action lane owns the right side, so the amount
        // moves out of the title row entirely.
        var inlineMetric = !editing && trailingMetric != null;
        var metricWidth = 0.0;
        if (inlineMetric) {
          metricWidth = OneLineLabel.measureWidth(
            text: trailingMetric!.display,
            fontSize: type.body,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
            textScaler: textScaler,
          );
          final titleFloor = OneLineLabel.measureWidth(
            text: title,
            fontSize: OneLineLabel.defaultMinFontSize,
            style: baseStyle,
            textScaler: textScaler,
          );
          // Squeezing both would truncate the name — the name wins and the
          // amount drops to the chip strip (still exact, never abbreviated).
          if (!keepMetricInline &&
              titleFloor + space.md + metricWidth > available) {
            inlineMetric = false;
            metricWidth = 0;
          }
        }

        final stackedMetrics = <EntityMetric>[
          if (!inlineMetric && trailingMetric != null) trailingMetric!,
          ...metrics,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  _Avatar(
                    icon: leadingIcon!,
                    color: leadingColor ?? scheme.primary,
                  ),
                  SizedBox(width: space.md),
                ],
                Expanded(
                  child: OneLineLabel(
                    title,
                    baseFontSize: type.section,
                    style: baseStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (inlineMetric) ...[
                  SizedBox(width: space.md),
                  SizedBox(
                    width: metricWidth,
                    child: OneLineLabel(
                      trailingMetric!.display,
                      baseFontSize: type.body,
                      textAlign: TextAlign.right,
                      style: baseStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            _toneForeground(bb, scheme, trailingMetric!.tone),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!editing && progress != null) ...[
              SizedBox(height: space.md / 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(space.xs / 2),
                child: LinearProgressIndicator(
                  value: progress!.value.clamp(0.0, 1.0),
                  minHeight: kEntityProgressHeight,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: _toneForeground(bb, scheme, progress!.tone),
                ),
              ),
            ],
            if (!editing && subtitle != null) ...[
              SizedBox(height: space.md / 2),
              OneLineLabel(
                subtitle!,
                baseFontSize: type.caption + 1,
                style: baseStyle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (!editing &&
                (effectiveBadges.isNotEmpty || stackedMetrics.isNotEmpty)) ...[
              SizedBox(height: space.md / 2),
              _ChipStrip(
                badges: effectiveBadges,
                metrics: stackedMetrics,
              ),
            ],
          ],
        );
      },
    );

    // ★행 리듬의 **단일 소유자** — 세 지표를 한 규칙으로 묶는다 `[측정 2026-08-24]`:
    //   박스 = max(잉크 + 2 × 여백, 터치 슬롯 44) · 위 = 아래 · 사이 = 위 + 아래
    // 여백은 모든 행에서 같은 값(`xs`)이고 **대칭**이다. 가로(`xl`)·아바타·폰트는
    // 이번 축이 아니므로 건드리지 않는다(1차 실패의 교훈: 요청 범위 봉인).
    //
    // 5차(PR #313)의 `hasTallSlot ? 0 : space.xs` 를 되돌린다. 그 처방은 슬롯 44 가
    // **제목 행 안**에 있다는 전제를 그대로 두고 여백만 0 으로 깎았고, 그래서 슬랙 24 가
    // 행 안쪽(제목 위아래)에 갇힌 채 위 12.0 / 아래 4.0 의 3배 비대칭이 됐다
    // `[측정]`(사용자 신고 ③: 자산 탭·카테고리 탭·자산 현황).
    // 지금은 슬롯을 **세로 흐름 밖**으로 뺀다 — 슬롯은 여전히 정사각 44(터치 하한,
    // 탭 라우팅 계측으로 확인)지만 박스의 **하한**만 정하고, 남는 슬랙은 Row 의 center
    // 정렬이 위아래로 균등하게 나눈다:
    //   1줄 + 슬롯 행: 박스 max(32 + 8, 44) = 44 → 사이 24.0(@960 48 → 24.0) 종전과 동일
    //   칩 행:        박스 = 잉크 + 8 → 사이 18.0 — 액션 유무로 갈리지 않는다
    //                 (종전 액션 16.0 / 무액션 18.0 — 같은 위젯이 두 리듬을 가졌다)
    final Widget? trailingSlot = editing
        ? _ActionLane(actions: actions!)
        : (overflowMenu != null
            ? SizedBox(
                width: box.actionSlot,
                height: box.actionSlot,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, size: box.actionIcon),
                  onSelected: overflowMenu!.onSelected,
                  itemBuilder: (_) => [
                    for (final item in overflowMenu!.items)
                      PopupMenuItem<String>(
                        value: item.value,
                        child: Row(children: [
                          if (item.icon != null) ...[
                            Icon(item.icon,
                                size: box.actionIcon,
                                color: item.destructive
                                    ? _toneForeground(
                                        bb, scheme, EntityTone.negative)
                                    : null),
                            SizedBox(width: space.md),
                          ],
                          Text(
                            item.label,
                            style: item.destructive
                                ? TextStyle(
                                    color: _toneForeground(
                                        bb, scheme, EntityTone.negative))
                                : null,
                          ),
                        ]),
                      ),
                  ],
                ),
              )
            : viewAction != null
            ? SizedBox(
                width: box.actionSlot,
                height: box.actionSlot,
                child: IconButton(
                  icon: Icon(viewAction!.icon, size: box.actionIcon),
                  padding: EdgeInsets.zero,
                  tooltip: viewAction!.tooltip,
                  onPressed: viewAction!.onPressed,
                ),
              )
            : null);

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: space.xs),
            child: content,
          ),
        ),
        if (trailingSlot != null) ...[
          SizedBox(width: space.md),
          trailingSlot,
        ],
      ],
    );

    // Tapping a row navigates away; in edit mode that would fight the
    // toggle/drag gestures, so it is disabled (검증 B5).
    return InkWell(
      onTap: editing ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.xl),
        child: dimmed ? Opacity(opacity: 0.55, child: body) : body,
      ),
    );
  }

  /// Foreground color for a tone painted directly on the surface.
  static Color toneForeground(
          BbColors bb, ColorScheme scheme, EntityTone tone) =>
      _toneForeground(bb, scheme, tone);

  /// Chip background / foreground pair for a tone.
  static ({Color background, Color foreground}) toneChip(
    BbColors bb,
    EntityTone tone,
  ) =>
      _toneChip(bb, tone);
}

Color _toneForeground(BbColors bb, ColorScheme scheme, EntityTone tone) =>
    switch (tone) {
      EntityTone.neutral => scheme.onSurface,
      EntityTone.income => bb.income.color,
      EntityTone.expense => bb.expense.color,
      EntityTone.transfer => bb.transfer.color,
      EntityTone.budget => bb.budget.color,
      EntityTone.savings => bb.savings.color,
      EntityTone.warn => bb.warnChip.color,
      EntityTone.positive => bb.positiveBalance,
      EntityTone.negative => bb.negativeBalance,
      EntityTone.muted => scheme.onSurface.withValues(alpha: 0.6),
    };

({Color background, Color foreground}) _toneChip(BbColors bb, EntityTone tone) {
  final BbSwatch swatch = switch (tone) {
    EntityTone.income => bb.income,
    EntityTone.expense => bb.expense,
    EntityTone.transfer => bb.transfer,
    EntityTone.budget => bb.budget,
    EntityTone.savings => bb.savings,
    EntityTone.warn => bb.warnChip,
    EntityTone.neutral || EntityTone.muted => bb.neutralChip,
    EntityTone.positive || EntityTone.negative => bb.neutralChip,
  };
  final foreground = switch (tone) {
    EntityTone.positive => bb.positiveBalance,
    EntityTone.negative => bb.negativeBalance,
    _ => swatch.onContainer,
  };
  return (background: swatch.container, foreground: foreground);
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = context.bbBox;
    return Container(
      width: box.avatar,
      height: box.avatar,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: box.avatarIcon, color: color),
    );
  }
}

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.badges, required this.metrics});

  final List<EntityBadge> badges;
  final List<EntityMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final bb = context.bb;
    final space = context.bbSpace;
    final children = <Widget>[];

    for (final badge in badges) {
      final pair = _toneChip(bb, badge.tone);
      children.add(_Chip(
        text: badge.label,
        background: (badge.color ?? pair.background)
            .withValues(alpha: badge.color != null ? 0.15 : 1.0),
        foreground: badge.color ?? pair.foreground,
      ));
    }
    for (final metric in metrics) {
      final pair = _toneChip(bb, metric.tone);
      children.add(_Chip(
        text: metric.display,
        background: pair.background,
        foreground: pair.foreground,
      ));
    }

    // A Row, never a Wrap: the strip must stay on one line and shrink
    // (검증 A2 — 줄바꿈 없이 읽힌다).
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: space.md / 2),
          Flexible(child: children[i]),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final space = context.bbSpace;
    return Container(
      padding: space.symmetric(h: BbSpaceToken.sm, v: BbSpaceToken.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: space.radius(BbSpaceToken.sm),
      ),
      child: OneLineLabel(
        text,
        baseFontSize: context.bbType.caption,
        minFontSize: 10,
        style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _ActionLane extends StatelessWidget {
  const _ActionLane({required this.actions});

  final EntityTileActions actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = context.bbBox;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.onActiveChanged != null)
          SizedBox(
            width: box.toggleSlot,
            height: box.actionSlot,
            child: Center(
              child: Switch(
                value: actions.isActive ?? true,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: actions.onActiveChanged,
              ),
            ),
          ),
        if (actions.menu.isNotEmpty)
          SizedBox(
            width: box.actionSlot,
            height: box.actionSlot,
            child: PopupMenuButton<String>(
              tooltip: '설정',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: box.actionIcon),
              onSelected: actions.onMenuSelected,
              itemBuilder: (_) => [
                for (final item in actions.menu)
                  PopupMenuItem<String>(
                    value: item.value,
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: context.bbType.iconMd,
                            color: item.destructive ? scheme.error : null,
                          ),
                          context.bbSpace.gapH(BbSpaceToken.md),
                        ],
                        Text(
                          item.label,
                          style: item.destructive
                              ? TextStyle(color: scheme.error)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (actions.reorderIndex != null)
          ReorderableDragStartListener(
            index: actions.reorderIndex!,
            child: SizedBox(
              width: box.actionSlot,
              height: box.actionSlot,
              child: Icon(
                Icons.drag_handle,
                size: box.actionIcon,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}
