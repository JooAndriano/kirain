import 'package:flutter/material.dart';

import '../../domain/tutorial.dart';
import '../theme.dart';

/// Ringkasan cara bermain dari langkah tutorial. Jika [onPlayTutorial]
/// diisi, ada tombol untuk bermain dengan tutorial interaktif.
Future<void> showHowToPlayDialog(
  BuildContext context, {
  VoidCallback? onPlayTutorial,
}) => showDialog<void>(
  context: context,
  builder: (_) => HowToPlayDialog(onPlayTutorial: onPlayTutorial),
);

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key, this.onPlayTutorial});

  final VoidCallback? onPlayTutorial;

  static IconData iconFor(TutorialTarget t) => switch (t) {
    TutorialTarget.image => Icons.image_search_rounded,
    TutorialTarget.zoomOut => Icons.zoom_out_map,
    TutorialTarget.letterBoard => Icons.keyboard_rounded,
    TutorialTarget.answerBoxes => Icons.touch_app_rounded,
    TutorialTarget.revealLetter => Icons.lightbulb_outline,
    TutorialTarget.removeWrong => Icons.auto_fix_high_outlined,
    TutorialTarget.coins => Icons.monetization_on_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final play = onPlayTutorial;
    return AlertDialog(
      title: const Text('Cara Bermain', textAlign: TextAlign.center),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final step in kTutorialSteps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  iconFor(step.target),
                  color: KirainColors.primary,
                ),
                title: Text(
                  step.title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(step.body),
              ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        if (play != null)
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Main dengan tutorial'),
            onPressed: () {
              Navigator.of(context).pop();
              play();
            },
          ),
      ],
    );
  }
}
