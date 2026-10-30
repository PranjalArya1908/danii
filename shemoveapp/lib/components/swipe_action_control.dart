import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SwipeActionControl extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  final IconData icon;
  final Color sliderColor;
  final Color? backgroundColor;

  const SwipeActionControl({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.chevron_right,
    this.sliderColor = SafeLoopColors.primaryViolet,
    this.backgroundColor,
  });

  @override
  State<SwipeActionControl> createState() => _SwipeActionControlState();
}

class _SwipeActionControlState extends State<SwipeActionControl> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isConfirmed = false;
  late AnimationController _animController;
  Animation<double>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_slideAnimation != null) {
          setState(() {
            _dragOffset = _slideAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isConfirmed) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_isConfirmed) return;
    if (maxDrag > 0 && _dragOffset >= maxDrag * 0.72) {
      // Confirmed!
      _slideAnimation = Tween<double>(begin: _dragOffset, end: maxDrag).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0).then((_) {
        setState(() {
          _isConfirmed = true;
        });
        widget.onConfirmed();
      });
    } else {
      // Snap back
      _slideAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    const thumbSize = 52.0;
    const containerHeight = 60.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxDrag = (constraints.maxWidth - thumbSize - 8.0).clamp(0.0, double.infinity);

            return Container(
              width: double.infinity,
              height: containerHeight,
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(containerHeight / 2),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Centered label
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56.0),
                      child: Text(
                        widget.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Draggable thumb
                  Positioned(
                    left: _dragOffset,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxDrag),
                      onHorizontalDragEnd: (details) => _onDragEnd(details, maxDrag),
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.sliderColor,
                          boxShadow: [
                            BoxShadow(
                              color: widget.sliderColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isConfirmed ? Icons.check : widget.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Accessible fallback tap button
        TextButton(
          onPressed: () {
            widget.onConfirmed();
          },
          child: Text(
            'Tap here if unable to swipe',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

