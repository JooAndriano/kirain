import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_providers.dart';

/// Memutar backsound selama app terlihat dan pengaturan musik aktif.
class BackgroundMusic extends ConsumerStatefulWidget {
  const BackgroundMusic({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundMusic> createState() => _BackgroundMusicState();
}

class _BackgroundMusicState extends ConsumerState<BackgroundMusic>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      settingsProvider,
      (_, _) => _sync(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final audio = ref.read(gameAudioProvider);
    final musicOn = ref.read(settingsProvider).value?.music ?? false;
    if (_foreground && musicOn) {
      audio.startMusic();
    } else {
      audio.stopMusic();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
