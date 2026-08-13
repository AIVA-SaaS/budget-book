import 'package:flutter/material.dart';

/// Owns the asset tab's edit mode. Held by the page (AppBar edit button),
/// read by every tile below it.
class AssetEditModeController extends ValueNotifier<bool> {
  AssetEditModeController({bool editing = false}) : super(editing);

  void toggle() => value = !value;
  void exit() => value = false;
}

/// Broadcasts the asset tab's edit mode to the tiles.
///
/// Uses [InheritedNotifier] so that flipping edit mode rebuilds only the
/// tiles that depend on it — never the whole page (plan §7).
class AssetEditModeScope extends InheritedNotifier<AssetEditModeController> {
  const AssetEditModeScope({
    super.key,
    required AssetEditModeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Whether edit mode is on. `false` when no scope is present, so tiles used
  /// outside the asset tab simply stay in view mode.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AssetEditModeScope>()
          ?.notifier
          ?.value ??
      false;

  /// The controller, without subscribing to its changes.
  static AssetEditModeController? controllerOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<AssetEditModeScope>()
      ?.notifier;
}
