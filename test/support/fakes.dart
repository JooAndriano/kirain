import 'dart:async';

import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/data/puzzle.dart';
import 'package:kirain/data/puzzle_cache.dart';
import 'package:kirain/data/puzzle_repository.dart';

class MemProgressRepo implements ProgressRepository {
  MemProgressRepo([Progress? initial]) : saved = initial ?? Progress.initial();
  Progress saved;
  Object? error;

  @override
  Future<Progress> load() async {
    if (error != null) throw error!;
    return saved;
  }

  @override
  Future<void> save(Progress p) async => saved = p;
}

/// Repo puzzle palsu yang bisa ditahan (loading), gagal, atau sukses.
class FakePuzzleRepo implements PuzzleRepository {
  FakePuzzleRepo(this.puzzles);
  List<Puzzle> puzzles;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<Puzzle>> fetchPuzzles() async {
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return puzzles;
  }
}

class MemPuzzleCache implements PuzzleCache {
  List<Puzzle>? stored;

  @override
  Future<List<Puzzle>?> load() async => stored;

  @override
  Future<void> save(List<Puzzle> puzzles) async => stored = [...puzzles];
}

Puzzle puzzle(int stage, int slot, {String? answer, String? id}) => Puzzle(
  id: id ?? 'stage_${stage.toString().padLeft(3, '0')}_$slot',
  stage: stage,
  slot: slot,
  imageFile: 's${stage}_$slot.webp',
  answer: answer ?? 'KUCING',
  focusX: 0.5,
  focusY: 0.5,
);

/// [count] stage lengkap mulai stage 1.
List<Puzzle> fullStages(int count) => [
  for (var s = 1; s <= count; s++)
    for (var slot = 1; slot <= 3; slot++) puzzle(s, slot),
];
