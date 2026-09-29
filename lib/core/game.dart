/// 五子棋核心规则。0 空, 1 黑, 2 白。
class Game {
  static const n = 15;
  final cells = List<int>.filled(n * n, 0);
  final history = <int>[]; // 落子序列, 值为 y*n+x
  int turn = 1;
  int winner = 0;
  List<int> winLine = const []; // 获胜的五连(及以上)格子

  int at(int x, int y) => cells[y * n + x];

  int get moves => history.length;
  bool get draw => winner == 0 && moves == n * n;
  bool get over => winner != 0 || draw;
  int? get last => history.isEmpty ? null : history.last;

  bool play(int x, int y) {
    if (over || x < 0 || y < 0 || x >= n || y >= n || at(x, y) != 0) {
      return false;
    }
    cells[y * n + x] = turn;
    history.add(y * n + x);
    final line = _line(x, y);
    if (line.isNotEmpty) {
      winner = turn;
      winLine = line;
    }
    turn = 3 - turn;
    return true;
  }

  void undo() {
    if (history.isEmpty) return;
    cells[history.removeLast()] = 0;
    turn = 3 - turn;
    winner = 0;
    winLine = const [];
  }

  List<int> _line(int x, int y) {
    final c = at(x, y);
    for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      final line = [y * n + x];
      for (final s in const [1, -1]) {
        var i = x + dx * s, j = y + dy * s;
        while (i >= 0 && j >= 0 && i < n && j < n && at(i, j) == c) {
          line.add(j * n + i);
          i += dx * s;
          j += dy * s;
        }
      }
      if (line.length >= 5) return line;
    }
    return const [];
  }
}
