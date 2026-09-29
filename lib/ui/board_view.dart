import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/game.dart';
import 'theme.dart';

/// 棋盘: 黑色半透明玻璃底板、细银线网格、黑白棋子、落子弹入、最后一手光环、获胜连线脉冲。
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.game, required this.enabled, required this.onTap});
  final Game game;
  final bool enabled;
  final void Function(int x, int y) onTap;

  @override
  State<BoardView> createState() => _BoardViewState();
}

/// 棋盘几何: 边缘只留 [margin] 格的空白(原先固定半格), 网格占满更多面积。
class _Geo {
  _Geo(this.size) : step = size / (Game.n - 1 + 2 * margin);
  static const margin = 0.42;
  final double size, step;

  Offset pos(int x, int y) => Offset((margin + x) * step, (margin + y) * step);

  int? hit(Offset p) {
    final x = (p.dx / step - margin).round(), y = (p.dy / step - margin).round();
    if (x < 0 || y < 0 || x >= Game.n || y >= Game.n) return null;
    return y * Game.n + x;
  }
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  int? hover;
  // 持续循环的时钟, 驱动涟漪和脉冲
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  final _born = <int, DateTime>{}; // 每颗子的落子时间

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final now = DateTime.now();
    for (final p in g.history) {
      _born.putIfAbsent(p, () => now);
    }
    _born.removeWhere((p, _) => g.cells[p] == 0);

    return LayoutBuilder(builder: (_, box) {
      final geo = _Geo(box.biggest.shortestSide);
      return MouseRegion(
        onHover: (e) => setState(() => hover = geo.hit(e.localPosition)),
        onExit: (_) => setState(() => hover = null),
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapUp: (d) {
            final c = geo.hit(d.localPosition);
            if (c != null && widget.enabled) widget.onTap(c % Game.n, c ~/ Game.n);
          },
          // 磨砂玻璃: 先模糊板子后面的背景, 再叠半透明黑, 才是"黑色透明"而不是纯黑
          child: ClipRRect(
            borderRadius: BorderRadius.circular(geo.step * 0.6),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedBuilder(
                animation: _clock,
                builder: (_, __) => CustomPaint(
                  size: Size.square(geo.size),
                  painter: _BoardPainter(g, geo, widget.enabled ? hover : null, _clock.value, _born),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.g, this.geo, this.hover, this.t, this.born);
  final Game g;
  final _Geo geo;
  final int? hover;
  final double t; // 0..1 循环
  final Map<int, DateTime> born;

  @override
  void paint(Canvas canvas, Size size) {
    final step = geo.step;
    final pos = geo.pos;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(step * 0.6));

    // 底板: 低不透明度的黑, 下面的背景光斑透得出来
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.42),
            Colors.black.withValues(alpha: 0.26),
          ],
        ).createShader(rect),
    );
    // 顶部一抹高光, 增强玻璃感
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0.08)],
        ).createShader(rect),
    );

    // 网格
    final a = _Geo.margin * step, b = size.width - a;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1;
    for (var i = 0; i < Game.n; i++) {
      final p = (_Geo.margin + i) * step;
      canvas.drawLine(Offset(a, p), Offset(b, p), line);
      canvas.drawLine(Offset(p, a), Offset(p, b), line);
    }
    for (final (x, y) in const [(3, 3), (11, 3), (3, 11), (11, 11), (7, 7)]) {
      canvas.drawCircle(pos(x, y), step * 0.075, Paint()..color = Colors.white.withValues(alpha: 0.55));
    }

    // 棋子半径: 直径约 0.56 格距, 相邻棋子之间留出明显空隙
    final r = step * 0.28;

    // 悬停预览
    if (hover != null && g.cells[hover!] == 0 && !g.over) {
      final o = pos(hover! % Game.n, hover! ~/ Game.n);
      final c = g.turn == 1 ? Palette.blackGlow : Palette.whiteGlow;
      canvas.drawCircle(o, r, Paint()..color = c.withValues(alpha: 0.22));
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.withValues(alpha: 0.8),
      );
    }

    // 棋子
    final now = DateTime.now();
    for (var y = 0; y < Game.n; y++) {
      for (var x = 0; x < Game.n; x++) {
        final c = g.at(x, y);
        if (c == 0) continue;
        final o = pos(x, y);
        // 落子弹入: 0.25s 内 从 1.4 倍缩到 1
        final age = now.difference(born[y * Game.n + x] ?? now).inMilliseconds / 250;
        final k = age >= 1 ? 1.0 : 1 + 0.4 * pow(1 - age, 2);
        final rr = r * k;
        canvas.drawCircle(
          o + Offset(rr * 0.1, rr * 0.25),
          rr,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.25),
        );
        canvas.drawCircle(
          o,
          rr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              radius: 1,
              colors: c == 1
                  ? const [Color(0xFF6B707A), Color(0xFF14161B), Color(0xFF000000)]
                  : const [Color(0xFFFFFFFF), Color(0xFFE6E8EC), Color(0xFF9CA2AD)],
              stops: const [0, 0.55, 1],
            ).createShader(Rect.fromCircle(center: o, radius: rr)),
        );
        if (c == 1) {
          canvas.drawCircle(o, rr, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.35));
        }
        canvas.drawCircle(
          o + Offset(-rr * 0.35, -rr * 0.38),
          rr * 0.16,
          Paint()..color = Colors.white.withValues(alpha: c == 1 ? 0.30 : 0.85),
        );
      }
    }

    // 最后一手: 扩散光环
    final last = g.last;
    if (last != null && !g.over) {
      final o = pos(last % Game.n, last ~/ Game.n);
      canvas.drawCircle(o, r * (1.1 + 0.4 * t), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.accent.withValues(alpha: 0.9 * (1 - t)));
      canvas.drawCircle(o, step * 0.075, Paint()..color = Palette.accent);
    }

    // 获胜连线: 脉冲发光环 + 贯穿线
    if (g.winLine.isNotEmpty) {
      final pulse = 0.6 + 0.4 * sin(t * 2 * pi);
      final pts = g.winLine.map((i) => pos(i % Game.n, i ~/ Game.n)).toList()
        ..sort((p, q) => (p.dx + p.dy).compareTo(q.dx + q.dy));
      canvas.drawLine(
        pts.first,
        pts.last,
        Paint()
          ..strokeWidth = step * 0.14
          ..strokeCap = StrokeCap.round
          ..color = Palette.accent.withValues(alpha: 0.5 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      for (final o in pts) {
        canvas.drawCircle(o, r * 1.18, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * 0.07
          ..color = Palette.accent.withValues(alpha: pulse));
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
