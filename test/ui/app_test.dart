import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/core/game.dart';
import 'package:gomoku/main.dart';
import 'package:gomoku/ui/board_view.dart';

Future<void> _pumpApp(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(1100, 760));
  await t.pumpWidget(const GomokuApp());
}

void main() {
  testWidgets('人机: 玩家落子后电脑应手, 悔棋撤回两步', (t) async {
    await _pumpApp(t);
    expect(find.text('轮到你落子'), findsOneWidget);

    await t.tapAt(t.getCenter(find.byType(CustomPaint).last));
    await t.pump();
    expect(find.text('电脑思考中…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('第 2 手'), findsOneWidget);
    expect(find.text('轮到你落子'), findsOneWidget);

    await t.tap(find.text('悔棋'));
    await t.pump();
    expect(find.text('第 0 手'), findsOneWidget);
  });

  testWidgets('执白时电脑先手', (t) async {
    await _pumpApp(t);
    await t.tap(find.text('执白后手'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('第 1 手'), findsOneWidget);
  });

  testWidgets('切换到双人模式后隐藏难度选项', (t) async {
    await _pumpApp(t);
    expect(find.text('困难'), findsOneWidget);
    await t.tap(find.text('双人'));
    await t.pump();
    expect(find.text('困难'), findsNothing);
  });

  _boardHitTest();
}

void _boardHitTest() {
  testWidgets('点击网格交点落在对应位置, 双人模式黑先', (t) async {
    await t.binding.setSurfaceSize(const Size(1100, 760));
    await t.pumpWidget(const GomokuApp());
    await t.tap(find.text('双人'));
    await t.pump();

    final box = t.getRect(find.byType(BoardView));
    final step = box.width / (Game.n - 1 + 2 * 0.42);
    Offset at(int x, int y) => Offset(box.left + (0.42 + x) * step, box.top + (0.42 + y) * step);

    await t.tapAt(at(3, 4));
    await t.pump();
    await t.tapAt(at(14, 14)); // 右下角最后一个交点
    await t.pump();
    expect(find.text('第 2 手'), findsOneWidget);

    await t.tapAt(at(3, 4)); // 重复点击已有棋子不应生效
    await t.pump();
    expect(find.text('第 2 手'), findsOneWidget);
  });
}
