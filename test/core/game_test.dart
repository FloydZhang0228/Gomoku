
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/core/game.dart';

void main() {
  test('横向五连黑胜, 并记录连线', () {
    final g = Game();
    for (var i = 0; i < 4; i++) {
      g.play(i, 0);
      g.play(i, 1);
    }
    expect(g.winner, 0);
    g.play(4, 0);
    expect(g.winner, 1);
    expect(g.winLine.length, 5);
    expect(g.play(5, 5), false);
  });

  test('斜向五连与重复落子', () {
    final g = Game();
    for (var i = 0; i < 4; i++) {
      g.play(i, i);
      g.play(i + 1, i);
    }
    expect(g.play(0, 0), false);
    g.play(4, 4);
    expect(g.winner, 1);
  });

  test('悔棋恢复状态', () {
    final g = Game();
    g.play(7, 7);
    g.undo();
    expect(g.at(7, 7), 0);
    expect(g.turn, 1);
    expect(g.moves, 0);
  });

}
