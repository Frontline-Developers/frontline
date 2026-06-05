import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating up/down scroll buttons.
/// Place inside a [Stack] at bottom-right, or use [ScrollNavButtons.wrap].
class ScrollNavButtons extends StatefulWidget {
  final ScrollController controller;
  const ScrollNavButtons({super.key, required this.controller});

  /// Convenience wrapper — wraps [child] in a Stack and overlays the buttons.
  static Widget wrap({
    required ScrollController controller,
    required Widget child,
  }) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 24,
          right: 16,
          child: ScrollNavButtons(controller: controller),
        ),
      ],
    );
  }

  @override
  State<ScrollNavButtons> createState() => _ScrollNavButtonsState();
}

class _ScrollNavButtonsState extends State<ScrollNavButtons> {
  bool _canUp = false;
  bool _canDown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // Evaluate after the first frame when position is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final up = pos.pixels > 80;
    final down = pos.pixels < pos.maxScrollExtent - 80;
    if (up != _canUp || down != _canDown) {
      setState(() {
        _canUp = up;
        _canDown = down;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _scrollUp() => widget.controller.animateTo(
    0,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );

  void _scrollDown() => widget.controller.animateTo(
    widget.controller.position.maxScrollExtent,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );

  @override
  Widget build(BuildContext context) {
    if (!_canUp && !_canDown) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canUp) ...[
          _NavBtn(icon: Icons.keyboard_arrow_up_rounded, onTap: _scrollUp),
          const SizedBox(height: 6),
        ],
        if (_canDown)
          _NavBtn(icon: Icons.keyboard_arrow_down_rounded, onTap: _scrollDown),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Icon(icon, size: 20, color: AppColors.reportNavy),
      ),
    );
  }
}
