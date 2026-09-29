import 'package:flutter/material.dart';

import 'core/ai.dart';
import 'core/game.dart';
import 'ui/board_view.dart';
import 'ui/theme.dart';
import 'ui/title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupWindow();
  runApp(const GomokuApp());
}

class GomokuApp extends StatelessWidget {
  const GomokuApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '五子棋',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (_, child) => AuroraBackground(
          child: Column(children: [
            if (hasCustomTitleBar) const AppTitleBar(),
            Expanded(child: child!),
          ]),
        ),
        home: const HomePage(),
      );
}

enum Mode { pvp, pve }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var g = Game();
  var mode = Mode.pve;
  var level = Level.normal;
  var humanSide = 1; // 人机模式下玩家执子: 1 黑(先手) / 2 白
  var thinking = false;
  var gen = 0; // 局面代数, 让过期的 AI 回调作废
  late Ai ai = Ai(level);

  bool get aiTurn => mode == Mode.pve && !g.over && g.turn != humanSide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aiTurn());
  }

  void _restart() {
    gen++;
    thinking = false;
    g = Game();
    ai = Ai(level);
    _aiTurn();
  }

  void _tap(int x, int y) {
    if (thinking || (mode == Mode.pve && g.turn != humanSide)) return;
    if (!g.play(x, y)) return;
    setState(() {});
    _aiTurn();
  }

  void _aiTurn() {
    if (!aiTurn) return;
    final my = ++gen;
    setState(() => thinking = true);
    // 先让界面刷出"思考中", 再进入同步搜索
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || my != gen) return;
      final m = ai.move(g);
      setState(() {
        thinking = false;
        if (m != null) g.play(m.$1, m.$2);
      });
    });
  }

  void _undo() {
    if (g.moves == 0) return;
    gen++; // 取消进行中的 AI 思考
    setState(() {
      thinking = false;
      g.undo();
      // 人机: 撤回到轮到玩家为止(通常连同 AI 的一步)
      if (mode == Mode.pve && g.turn != humanSide) g.undo();
    });
    _aiTurn();
  }

  String get status {
    if (g.winner != 0) {
      if (mode == Mode.pve) return g.winner == humanSide ? '你赢了!' : '电脑获胜';
      return '${g.winner == 1 ? "黑" : "白"}方获胜';
    }
    if (g.draw) return '平局';
    if (thinking) return '电脑思考中…';
    if (mode == Mode.pve) return '轮到你落子';
    return '${g.turn == 1 ? "黑" : "白"}方落子';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 820;
    final board = Padding(
      padding: const EdgeInsets.all(6),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: BoardView(game: g, enabled: !thinking && !g.over, onTap: _tap),
        ),
      ),
    );
    final panel = _Panel(
      status: status,
      turn: g.turn,
      over: g.over,
      thinking: thinking,
      moves: g.moves,
      mode: mode,
      level: level,
      humanSide: humanSide,
      onMode: (m) => setState(() {
        mode = m;
        _restart();
      }),
      onLevel: (l) => setState(() {
        level = l;
        _restart();
      }),
      onSide: (s) => setState(() {
        humanSide = s;
        _restart();
      }),
      onUndo: g.moves == 0 ? null : _undo,
      onRestart: () => setState(_restart),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: wide
            ? Row(children: [
                Expanded(child: board),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                  child: SizedBox(width: 260, child: SingleChildScrollView(child: panel)),
                ),
              ])
            : Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: panel),
                Expanded(child: board),
              ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.status,
    required this.turn,
    required this.over,
    required this.thinking,
    required this.moves,
    required this.mode,
    required this.level,
    required this.humanSide,
    required this.onMode,
    required this.onLevel,
    required this.onSide,
    required this.onUndo,
    required this.onRestart,
  });

  final String status;
  final int turn, moves, humanSide;
  final bool over, thinking;
  final Mode mode;
  final Level level;
  final ValueChanged<Mode> onMode;
  final ValueChanged<Level> onLevel;
  final ValueChanged<int> onSide;
  final VoidCallback? onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Palette.neon]).createShader(r),
          child: Text('五子棋',
              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 4)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            _Stone(black: turn == 1, dim: over, pulse: thinking),
            const SizedBox(width: 12),
            Expanded(child: Text(status, style: t.titleMedium)),
            Text('第 $moves 手', style: t.bodySmall?.copyWith(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        SegmentedButton<Mode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Mode.pve, label: Text('人机'), icon: Icon(Icons.smart_toy_outlined)),
            ButtonSegment(value: Mode.pvp, label: Text('双人'), icon: Icon(Icons.people_outline)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onMode(s.first),
        ),
        if (mode == Mode.pve) ...[
          const SizedBox(height: 10),
          SegmentedButton<Level>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Level.easy, label: Text('简单')),
              ButtonSegment(value: Level.normal, label: Text('普通')),
              ButtonSegment(value: Level.hard, label: Text('困难')),
            ],
            selected: {level},
            onSelectionChanged: (s) => onLevel(s.first),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('执黑先手')),
              ButtonSegment(value: 2, label: Text('执白后手')),
            ],
            selected: {humanSide},
            onSelectionChanged: (s) => onSide(s.first),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: const Text('悔棋'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onRestart,
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.9), foregroundColor: Colors.black),
              icon: const Icon(Icons.refresh),
              label: const Text('重开'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// 当前落子方的棋子指示; 电脑思考时呼吸闪烁。
class _Stone extends StatefulWidget {
  const _Stone({required this.black, required this.dim, required this.pulse});
  final bool black, dim, pulse;
  @override
  State<_Stone> createState() => _StoneState();
}

class _StoneState extends State<_Stone> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final glow = widget.pulse ? 4 + 10 * _c.value : 4.0;
          return Opacity(
            opacity: widget.dim ? 0.4 : 1,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.4),
                  colors: widget.black
                      ? const [Color(0xFF5A5F69), Color(0xFF000000)]
                      : const [Color(0xFFFFFFFF), Color(0xFFB9BEC7)],
                ),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: glow)],
              ),
            ),
          );
        },
      );
}
