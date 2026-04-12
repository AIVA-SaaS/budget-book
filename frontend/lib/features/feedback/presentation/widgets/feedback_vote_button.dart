import 'package:flutter/material.dart';

/// Heart-style vote button with count and animated toggle.
class FeedbackVoteButton extends StatefulWidget {
  final int voteCount;
  final bool hasVoted;
  final VoidCallback onToggle;

  const FeedbackVoteButton({
    super.key,
    required this.voteCount,
    required this.hasVoted,
    required this.onToggle,
  });

  @override
  State<FeedbackVoteButton> createState() => _FeedbackVoteButtonState();
}

class _FeedbackVoteButtonState extends State<FeedbackVoteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant FeedbackVoteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasVoted != widget.hasVoted) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.hasVoted
        ? Colors.red
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return InkWell(
      onTap: widget.onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.hasVoted ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.voteCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: widget.hasVoted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
