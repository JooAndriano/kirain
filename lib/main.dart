import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/game_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: KirainApp()));
}

class KirainApp extends StatelessWidget {
  const KirainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirain',
      debugShowCheckedModeBanner: false,
      theme: buildKirainTheme(),
      home: const GamePage(),
    );
  }
}
