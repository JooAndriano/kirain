import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progress_providers.dart';
import 'home_page.dart';
import 'theme.dart';

const kLogoAsset = 'assets/images/logo.jpg';
const kWordmarkAsset = 'assets/images/logo_text.jpg';
const kWordmarkHeroTag = 'kirain-wordmark';

/// Splash beranimasi: logo "zoom out" seperti gambar di game, lalu tulisan
/// Kirain muncul. Pindah ke Home setelah animasi selesai dan progress dimuat.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  late final Animation<double> _zoom = Tween(begin: 3.2, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    ),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
  );
  late final Animation<double> _wordFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
  );
  late final Animation<Offset> _wordSlide =
      Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _c,
          curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _tagFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
  );

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(kLogoAsset), context);
    precacheImage(const AssetImage(kWordmarkAsset), context);
  }

  Future<void> _start() async {
    // Error progress ditampilkan oleh HomePage; di sini cukup ditunggu.
    await Future.wait<void>([
      _c.forward().orCancel.then((_) {}, onError: (Object _) {}),
      ref.read(progressProvider.future).then((_) {}, onError: (Object _) {}),
    ]);
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const HomePage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: KirainColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: SizedBox.square(
                  dimension: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: ScaleTransition(
                      scale: _zoom,
                      child: Image.asset(kLogoAsset, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SlideTransition(
                position: _wordSlide,
                child: FadeTransition(
                  opacity: _wordFade,
                  child: Hero(
                    tag: kWordmarkHeroTag,
                    child: Image.asset(kWordmarkAsset, height: 96),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _tagFade,
                child: Text(
                  'Tebak gambarnya!',
                  style: text.titleMedium?.copyWith(color: KirainColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
