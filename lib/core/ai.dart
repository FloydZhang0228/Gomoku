import 'dart:math';

import 'game.dart';

enum Level { easy, normal, hard }

/// Alpha-Beta 搜索 AI。
/// 候选点 = 周围 2 格内有子的空位, 按单点启发分排序后取前 [_width] 个, 排序越准剪枝越多。
/// 叶子评估 = 己方棋型总分 - 对方棋型总分。
/// ponytail: 无置换表/迭代加深/威胁空间搜索, 困难档深度 6, 自我对弈最慢约数百毫秒; 要更强再加置换表。
class Ai {
  Ai(this.level, [Random? rng]) : _rng = rng ?? Random();
  final Level level;
  final Random _rng;

  static const _win = 1000000;

  int get _depth => switch (level) { Level.easy => 1, Level.normal => 2, Level.hard => 6 };
  int get _width => switch (level) { Level.easy => 6, Level.normal => 10, Level.hard => 12 };

  /// 返回 (x, y); 棋盘已满返回 null。会在内部临时落子并还原, 但对外不改变 [g]。
  (int, int)? move(Game g) {
    if (g.over) return null;
    if (g.moves == 0) return (Game.n ~/ 2, Game.n ~/ 2);

    final me = g.turn;
    final cands = _candidates(g, me);
    if (cands.isEmpty) return null;

    // 简单档: 只看一步启发, 并带随机性
    if (level == Level.easy) {
      final k = min(4, cands.length);
      return _xy(cands[_rng.nextInt(k)].$2);
    }

    var best = cands.first.$2;
    var alpha = -_win * 2;
    for (final (_, p) in cands) {
      final x = p % Game.n, y = p ~/ Game.n;
      g.play(x, y);
      final v = g.winner == me ? _win + 100 : -_search(g, me, _depth - 1, -_win * 2, -alpha);
      g.undo();
      if (v > alpha) {
        alpha = v;
        best = p;
      }
    }
    return _xy(best);
  }

  (int, int) _xy(int p) => (p % Game.n, p ~/ Game.n);

  // 负极大值 alpha-beta: 返回 "轮到落子方(g.turn)" 视角的分数
  int _search(Game g, int root, int depth, int alpha, int beta) {
    if (g.winner != 0) return -_win - depth; // 上一手已获胜, 当前落子方输; 越早输越差
    if (g.draw) return 0;
    if (depth == 0) return _eval(g, g.turn);

    final cands = _candidates(g, g.turn);
    if (cands.isEmpty) return 0;
    var best = -_win * 2;
    for (final (_, p) in cands) {
      g.play(p % Game.n, p ~/ Game.n);
      final v = -_search(g, root, depth - 1, -beta, -alpha);
      g.undo();
      if (v > best) best = v;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// 候选点, 按启发分从高到低, 最多 [_width] 个。
  /// 若有一步必胜 / 必须堵, 只返回该步, 大幅缩小搜索。
  List<(double, int)> _candidates(Game g, int me) {
    final list = <(double, int)>[];
    for (var y = 0; y < Game.n; y++) {
      for (var x = 0; x < Game.n; x++) {
        if (g.at(x, y) != 0 || !_near(g, x, y)) continue;
        final atk = _point(g, x, y, me);
        final def = _point(g, x, y, 3 - me);
        if (atk >= 100000) return [(atk, y * Game.n + x)]; // 己方成五
        list.add((atk + def * 0.9 + _center(x, y), y * Game.n + x));
      }
    }
    list.sort((a, b) => b.$1.compareTo(a.$1));
    // 对方有成五点必须堵
    for (final c in list) {
      final x = c.$2 % Game.n, y = c.$2 ~/ Game.n;
      if (_point(g, x, y, 3 - me) >= 100000) return [c];
    }
    return list.length > _width ? list.sublist(0, _width) : list;
  }

  double _center(int x, int y) {
    const c = Game.n ~/ 2;
    return (14 - (x - c).abs() - (y - c).abs()) * 0.1;
  }

  bool _near(Game g, int x, int y) {
    for (var j = max(0, y - 2); j <= min(Game.n - 1, y + 2); j++) {
      for (var i = max(0, x - 2); i <= min(Game.n - 1, x + 2); i++) {
        if (g.at(i, j) != 0) return true;
      }
    }
    return false;
  }

  // 假设 who 落在 (x,y) 的四方向棋型分之和
  double _point(Game g, int x, int y, int who) {
    var total = 0.0;
    for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      var count = 1, open = 0;
      for (final s in const [1, -1]) {
        var i = x + dx * s, j = y + dy * s;
        while (i >= 0 && j >= 0 && i < Game.n && j < Game.n && g.at(i, j) == who) {
          count++;
          i += dx * s;
          j += dy * s;
        }
        if (i >= 0 && j >= 0 && i < Game.n && j < Game.n && g.at(i, j) == 0) open++;
      }
      total += _pattern(count, open);
    }
    return total;
  }

  static double _pattern(int count, int open) {
    if (count >= 5) return 100000;
    if (open == 0) return 0;
    return switch (count) {
      4 => open == 2 ? 10000 : 1000,
      3 => open == 2 ? 1000 : 100,
      2 => open == 2 ? 100 : 10,
      _ => open == 2 ? 10 : 1,
    };
  }

  // 全盘评估: 沿四个方向扫描连续同色段, 累计棋型分(己方 - 对方), 每段只计一次
  int _eval(Game g, int me) {
    var score = 0.0;
    const n = Game.n;
    for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          final c = g.at(x, y);
          if (c == 0) continue;
          // 只从段的起点开始数
          final px = x - dx, py = y - dy;
          if (px >= 0 && py >= 0 && px < n && py < n && g.at(px, py) == c) continue;
          var count = 0, i = x, j = y;
          while (i >= 0 && j >= 0 && i < n && j < n && g.at(i, j) == c) {
            count++;
            i += dx;
            j += dy;
          }
          var open = 0;
          if (px >= 0 && py >= 0 && px < n && py < n && g.at(px, py) == 0) open++;
          if (i >= 0 && j >= 0 && i < n && j < n && g.at(i, j) == 0) open++;
          final v = _pattern(count, open);
          score += c == me ? v : -v * 1.1; // 略偏防守
        }
      }
    }
    return score.round();
  }
}
