import 'package:flutter/material.dart';

import '../../domain/tutorial.dart';
import '../theme.dart';

/// Tutorial berlapis: menggelapkan layar, menyorot bagian [targets] satu per
/// satu dengan cincin berdenyut, dan menampilkan kartu penjelasan melayang.
///
/// Ketuk di mana saja atau tombol "Lanjut" untuk langkah berikutnya.
/// [onDone] dipanggil saat tutorial selesai atau dilewati.
class CoachMarks extends StatefulWidget {
  const CoachMarks({
    super.key,
    required this.targets,
    required this.onDone,
    this.steps = kTutorialSteps,
  });

  final Map<TutorialTarget, GlobalKey> targets;
  final VoidCallback onDone;
  final List<TutorialStep> steps;

  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks>
    with SingleTickerProviderStateMixin {
  late TutorialProgress _progress = TutorialProgress(steps: widget.steps);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  Rect? _hole;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Ukur ulang tiap frame animasi agar sorotan mengikuti perubahan tata
    // letak (mis. kotak jawaban berpindah baris).
    _pulse.addListener(() => _measure(null));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _advance(TutorialProgress next) {
    if (_done) return;
    if (next.isFinished) {
      _done = true;
      widget.onDone();
      return;
    }
    setState(() => _progress = next);
  }

  /// Ukur posisi bagian yang disorot relatif terhadap lapisan ini.
  void _measure(Object? _) {
    if (!mounted) return;
    final step = _progress.current;
    final self = context.findRenderObject();
    final target = step == null
        ? null
        : widget.targets[step.target]?.currentContext?.findRenderObject();
    Rect? hole;
    if (self is RenderBox &&
        target is RenderBox &&
        self.hasSize &&
        target.hasSize &&
        target.attached) {
      final topLeft = self.globalToLocal(target.localToGlobal(Offset.zero));
      hole = (topLeft & target.size).inflate(6);
    }
    if (hole != _hole) setState(() => _hole = hole);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final step = _progress.current;
    if (step == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final hole = _hole;
        // Kartu di bawah sorotan bila sorotan di separuh atas, sebaliknya
        // di atasnya.
        final below = hole == null || hole.center.dy < size.height / 2;
        const gap = 16.0;
        final card = AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _CoachCard(
            key: ValueKey(_progress.index),
            step: step,
            index: _progress.index,
            total: _progress.steps.length,
            isLast: _progress.isLast,
            onNext: () => _advance(_progress.next()),
            onSkip: () => _advance(_progress.skip()),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: const ValueKey('coach-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _advance(_progress.next()),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotlightPainter(hole: hole, pulse: _pulse.value),
                ),
              ),
            ),
            if (hole == null)
              Center(
                child: Padding(padding: const EdgeInsets.all(gap), child: card),
              )
            else
              Positioned(
                left: gap,
                right: gap,
                top: below ? (hole.bottom + gap).clamp(gap, size.height) : null,
                bottom: below
                    ? null
                    : (size.height - hole.top + gap).clamp(gap, size.height),
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final TutorialStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: KirainColors.surface,
      elevation: 6,
      shadowColor: KirainColors.shadow,
      borderRadius: kBorderRadius,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: KirainColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${index + 1}/$total', style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(step.body, style: text.bodyMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                if (!isLast)
                  TextButton(onPressed: onSkip, child: const Text('Lewati')),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  child: Text(isLast ? 'Mengerti' : 'Lanjut'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lapisan gelap berlubang di [hole] dengan cincin yang membesar dan memudar
/// (efek "zoom") selama [pulse] berjalan 0..1.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.pulse});

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final hole = this.hole;
    final scrim = Paint()..color = KirainColors.tutorialScrim;
    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    const radius = Radius.circular(kRadius);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(RRect.fromRectAndRadius(hole, radius));
    canvas.drawPath(path, scrim);

    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = KirainColors.tutorialRing,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.inflate(2 + 12 * pulse), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = KirainColors.tutorialRing.withValues(alpha: 1 - pulse),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse;
}
