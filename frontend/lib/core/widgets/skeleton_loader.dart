import 'package:flutter/material.dart';
import '../../core/theme/bb_scale.dart';

/// A shimmer-effect loading placeholder that mimics list items.
class SkeletonLoader extends StatefulWidget {
  final int itemCount;
  final double height;

  const SkeletonLoader({
    super.key,
    this.itemCount = 5,
    this.height = 72,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            return _SkeletonItem(
              height: widget.height,
              shimmerValue: _animation.value,
            );
          },
        );
      },
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  final double height;
  final double shimmerValue;

  const _SkeletonItem({
    required this.height,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surface;

    final gradient = LinearGradient(
      begin: Alignment(shimmerValue - 1, 0),
      end: Alignment(shimmerValue, 0),
      colors: [
        baseColor,
        highlightColor,
        baseColor,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Circle avatar placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
          ),
          const SizedBox(width: 12),
          // Text lines placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
                context.bbSpace.gapV(BbSpaceToken.lg),
                Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing placeholder
          Container(
            height: 14,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: gradient,
            ),
          ),
        ],
      ),
    );
  }
}
