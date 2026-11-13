import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/game_engine.dart';
import '../theme.dart';

/// Baris kotak jawaban. Bergoyang setiap [shakeTrigger] berubah.
class AnswerBoxes extends StatefulWidget {
  const AnswerBoxes({
    super.key,
    required this.slots,
    required this.onTap,
    this.shakeTrigger = 0,
  });

  final List<SlotView> slots;
  final ValueChanged<int> onTap;
  final int shakeTrigger;

  @override
  State<AnswerBoxes> createState() => _AnswerBoxesState();
}

class _AnswerBoxesState extends State<AnswerBoxes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant AnswerBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = sin(t * pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final n = widget.slots.length;
          final size = min(kMinTap, (constraints.maxWidth - gap * (n - 1)) / n);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _Box(
                  slot: widget.slots[i],
                  size: size,
                  onTap: () => widget.onTap(i),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.slot, required this.size, required this.onTap});

  final SlotView slot;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = slot.locked
        ? KirainColors.locked
        : slot.isEmpty
        ? KirainColors.boxEmpty
        : KirainColors.surface;
    return GestureDetector(
      onTap: slot.isEmpty || slot.locked ? null : onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(kRadius / 2),
          border: Border.all(color: KirainColors.boxBorder, width: 2),
          boxShadow: slot.isEmpty ? null : kSoftShadow,
        ),
        child: Text(
          slot.letter ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: KirainColors.text,
          ),
        ),
      ),
    );
  }
}
