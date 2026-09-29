import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/core/ai.dart';
import 'package:gomoku/core/game.dart';

void put(Game g, int x, int y, int c) {
  g.cells[y * Game.n + x] = c;
  g.history.add(y * Game.n + x);
}

void main() {
  test('首步下天元', () => expect(Ai(Level.hard).move(Game()), (7, 7)));

  test('搜索不改变棋盘', () {
    final g = Game()..play(7, 7)..play(8, 8)..play(7, 8);
    final before = List.of(g.cells);
    final n = g.moves, t = g.turn;
    Ai(Level.hard).move(g);
    expect(g.cells, before);
    expect(g.moves, n);
    expect(g.turn, t);
    expect(g.winner, 0);
  });

  test('能自己成五', () {
    final g = Game();
    for (var i = 0; i < 4; i++) {
      put(g, i, 7, 2);
    }
    g.turn = 2;
    final (x, y) = Ai(Level.hard).move(g)!;
    g.play(x, y);
    expect(g.winner, 2);
  });

  test('会堵对手四连', () {
    final g = Game();
    for (var i = 1; i <= 4; i++) {
      put(g, i, 7, 1);
    }
    put(g, 0, 7, 2);
    g.turn = 2;
    expect(Ai(Level.hard).move(g), (5, 7));
  });

  test('困难档: 己方活三时抢先做活四(单步启发也能做到的基线)', () {
    final g = Game();
    for (var i = 5; i <= 7; i++) {
      put(g, i, 7, 1);
    }
    put(g, 5, 8, 2);
    put(g, 6, 9, 2);
    g.turn = 1;
    final m = Ai(Level.hard).move(g)!;
    expect([(4, 7), (8, 7)], contains(m));
  });

  test('困难档: 识别四三杀(单步启发看不出)', () {
    // 黑: 横向冲三 (4..6,7) 两端空, 竖向 (7,4..6) 三连 -> 下 (7,7) 同时形成横四 + 竖四, 白只能堵一头
    // 构造: 黑在 (4,7)(5,7)(6,7) 与 (7,4)(7,5)(7,6), 白随意远处两子
    final g = Game();
    for (final x in [4, 5, 6]) {
      put(g, x, 7, 1);
    }
    for (final y in [4, 5, 6]) {
      put(g, 7, y, 1);
    }
    put(g, 0, 0, 2);
    put(g, 14, 14, 2);
    g.turn = 1;
    expect(Ai(Level.hard).move(g), (7, 7));
  });

  test('困难 AI 稳赢随机对手, 且单步耗时可接受', () {
    final rng = Random(1);
    final sw = Stopwatch();
    var worst = 0;
    for (var round = 0; round < 4; round++) {
      final g = Game();
      final ai = Ai(Level.hard, rng);
      final side = round.isEven ? 1 : 2;
      while (!g.over) {
        if (g.turn == side) {
          sw
            ..reset()
            ..start();
          final (x, y) = ai.move(g)!;
          worst = max(worst, sw.elapsedMilliseconds);
          g.play(x, y);
        } else {
          while (!g.play(rng.nextInt(Game.n), rng.nextInt(Game.n))) {}
        }
      }
      expect(g.winner, side, reason: 'round $round');
    }
    // ignore: avoid_print
    print('困难档单步最慢 ${worst}ms');
    expect(worst, lessThan(5000));
  });

  test('困难 AI 对 简单 AI 获胜', () {
    for (final hardFirst in [true, false]) {
      final g = Game();
      final hard = Ai(Level.hard, Random(3)), easy = Ai(Level.easy, Random(4));
      while (!g.over) {
        final hardTurn = (g.turn == 1) == hardFirst;
        final (x, y) = (hardTurn ? hard : easy).move(g)!;
        g.play(x, y);
      }
      expect(g.winner, hardFirst ? 1 : 2, reason: 'hardFirst=$hardFirst');
    }
  });
}
