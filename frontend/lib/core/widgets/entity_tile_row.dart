import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/theme/bb_density.dart';
import 'package:budget_book/core/widgets/asset_edit_mode_scope.dart';
import 'package:budget_book/core/widgets/one_line_label.dart';

/// Semantic tone for a badge or a metric. Resolved against [BbColors] — a
/// caller can never pass a raw palette color for these.
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

  @override
  Widget build(BuildContext context) {
    final editing = AssetEditModeScope.of(context) && actions != null;
    final density = context.density;
    final bb = context.bb;
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;

    final effectiveBadges = <EntityBadge>[
      ...badges,
      if (dimmed)
        EntityBadge(label: inactiveLabel, tone: EntityTone.warn),
    ];

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Chrome the title row cannot use: padding, avatar, gaps, actions.
        var chrome = density.tilePaddingH * 2;
        if (leadingIcon != null) chrome += density.avatarSize + density.gap;
        if (editing) chrome += _actionsWidth(density, actions!) + density.gap;
        final available = constraints.maxWidth - chrome;

        // In edit mode the action lane owns the right side, so the amount
        // moves out of the title row entirely.
        var inlineMetric = !editing && trailingMetric != null;
        var metricWidth = 0.0;
        if (inlineMetric) {
          metricWidth = OneLineLabel.measureWidth(
            text: trailingMetric!.display,
            fontSize: density.metricFontSize,
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
          if (titleFloor + density.gap + metricWidth > available) {
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
                    density: density,
                  ),
                  SizedBox(width: density.gap),
                ],
                Expanded(
                  child: OneLineLabel(
                    title,
                    baseFontSize: density.titleFontSize,
                    style: baseStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (inlineMetric) ...[
                  SizedBox(width: density.gap),
                  SizedBox(
                    width: metricWidth,
                    child: OneLineLabel(
                      trailingMetric!.display,
                      baseFontSize: density.metricFontSize,
                      textAlign: TextAlign.right,
                      style: baseStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _toneForeground(bb, scheme, trailingMetric!.tone),
                      ),
                    ),
                  ),
                ],
                if (editing) ...[
                  SizedBox(width: density.gap),
                  _ActionLane(actions: actions!, density: density),
                ],
              ],
            ),
            if (!editing && subtitle != null) ...[
              SizedBox(height: density.gap / 2),
              OneLineLabel(
                subtitle!,
                baseFontSize: density.chipFontSize + 1,
                style: baseStyle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (!editing && (effectiveBadges.isNotEmpty || stackedMetrics.isNotEmpty)) ...[
              SizedBox(height: density.gap / 2),
              _ChipStrip(
                badges: effectiveBadges,
                metrics: stackedMetrics,
                density: density,
              ),
            ],
          ],
        );
      },
    );

    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: density.tilePaddingH,
        vertical: density.tilePaddingV,
      ),
      child: dimmed ? Opacity(opacity: 0.55, child: content) : content,
    );

    // Tapping a row navigates away; in edit mode that would fight the
    // toggle/drag gestures, so it is disabled (검증 B5).
    return InkWell(
      onTap: editing ? null : onTap,
      child: padded,
    );
  }

  static double _actionsWidth(BbDensity density, EntityTileActions actions) {
    var width = 0.0;
    if (actions.onActiveChanged != null) width += density.toggleSlotWidth;
    if (actions.menu.isNotEmpty) width += density.actionSlotSize;
    if (actions.reorderIndex != null) width += density.actionSlotSize;
    return width;
  }

  /// Foreground color for a tone painted directly on the surface.
  static Color toneForeground(BbColors bb, ColorScheme scheme, EntityTone tone) =>
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
  const _Avatar({
    required this.icon,
    required this.color,
    required this.density,
  });

  final IconData icon;
  final Color color;
  final BbDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: density.avatarSize,
      height: density.avatarSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: density.avatarIconSize, color: color),
    );
  }
}

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({
    required this.badges,
    required this.metrics,
    required this.density,
  });

  final List<EntityBadge> badges;
  final List<EntityMetric> metrics;
  final BbDensity density;

  @override
  Widget build(BuildContext context) {
    final bb = context.bb;
    final children = <Widget>[];

    for (final badge in badges) {
      final pair = _toneChip(bb, badge.tone);
      children.add(_Chip(
        text: badge.label,
        background: (badge.color ?? pair.background)
            .withValues(alpha: badge.color != null ? 0.15 : 1.0),
        foreground: badge.color ?? pair.foreground,
        density: density,
      ));
    }
    for (final metric in metrics) {
      final pair = _toneChip(bb, metric.tone);
      children.add(_Chip(
        text: metric.display,
        background: pair.background,
        foreground: pair.foreground,
        density: density,
      ));
    }

    // A Row, never a Wrap: the strip must stay on one line and shrink
    // (검증 A2 — 줄바꿈 없이 읽힌다).
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: density.gap / 2),
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
    required this.density,
  });

  final String text;
  final Color background;
  final Color foreground;
  final BbDensity density;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.chipPaddingH,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: OneLineLabel(
        text,
        baseFontSize: density.chipFontSize,
        minFontSize: 10,
        style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _ActionLane extends StatelessWidget {
  const _ActionLane({required this.actions, required this.density});

  final EntityTileActions actions;
  final BbDensity density;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.onActiveChanged != null)
          SizedBox(
            width: density.toggleSlotWidth,
            height: density.actionSlotSize,
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
            width: density.actionSlotSize,
            height: density.actionSlotSize,
            child: PopupMenuButton<String>(
              tooltip: '설정',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: density.actionIconSize),
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
                            size: 20,
                            color: item.destructive ? scheme.error : null,
                          ),
                          const SizedBox(width: 8),
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
              width: density.actionSlotSize,
              height: density.actionSlotSize,
              child: Icon(
                Icons.drag_handle,
                size: density.actionIconSize,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}
