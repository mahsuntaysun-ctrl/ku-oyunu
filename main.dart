import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GamePage(),
  ));
}

enum GameState { ready, playing, dead }

class Pipe {
  double x;
  double gapY;
  bool passed = false;
  Pipe(this.x, this.gapY);
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  // Ayarlar (istediğin gibi değiştir)
  static const double gravity = 1500;
  static const double jumpSpeed = -480;
  static const double pipeSpeed = 170;
  static const double gap = 190;
  static const double pipeWidth = 70;
  static const double pipeSpacing = 240;
  static const double groundHeight = 80;
  static const double birdRadius = 16;

  final Random _rnd = Random();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  GameState state = GameState.ready;
  double birdY = 0;
  double birdV = 0;
  List<Pipe> pipes = [];
  int score = 0;
  int best = 0;

  double get birdX => _size.width * 0.28;
  double get groundTop => _size.height - groundHeight;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _randomGapY() {
    final minY = 110 + gap / 2;
    final maxY = groundTop - 110 - gap / 2;
    return minY + _rnd.nextDouble() * (maxY - minY);
  }

  void _reset() {
    birdY = _size.height / 2;
    birdV = 0;
    score = 0;
    pipes = [
      for (int i = 0; i < 4; i++)
        Pipe(_size.width + 100 + i * pipeSpacing, _randomGapY()),
    ];
    state = GameState.ready;
  }

  void _tick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.03) dt = 0.03;
    if (_size == Size.zero) return;

    if (state == GameState.playing) {
      birdV += gravity * dt;
      birdY += birdV * dt;

      for (final p in pipes) {
        p.x -= pipeSpeed * dt;
        if (!p.passed && p.x + pipeWidth < birdX) {
          p.passed = true;
          score++;
          if (score > best) best = score;
        }
      }
      if (pipes.first.x + pipeWidth < 0) {
        final lastX = pipes.last.x;
        pipes.removeAt(0);
        pipes.add(Pipe(lastX + pipeSpacing, _randomGapY()));
      }

      // Çarpışma
      bool hit = birdY - birdRadius < 0 || birdY + birdRadius > groundTop;
      for (final p in pipes) {
        final overlapX =
            birdX + birdRadius > p.x && birdX - birdRadius < p.x + pipeWidth;
        if (overlapX &&
            (birdY - birdRadius < p.gapY - gap / 2 ||
                birdY + birdRadius > p.gapY + gap / 2)) {
          hit = true;
        }
      }
      if (hit) {
        state = GameState.dead;
        HapticFeedback.heavyImpact();
      }
    }
    setState(() {});
  }

  void _onTap() {
    switch (state) {
      case GameState.ready:
        state = GameState.playing;
        birdV = jumpSpeed;
        break;
      case GameState.playing:
        birdV = jumpSpeed;
        break;
      case GameState.dead:
        _reset();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final newSize = Size(c.maxWidth, c.maxHeight);
        if (newSize != _size) {
          _size = newSize;
          _reset();
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _onTap(),
          child: Stack(
            children: [
              CustomPaint(
                size: _size,
                painter: GamePainter(
                  birdX: birdX,
                  birdY: birdY,
                  birdV: birdV,
                  pipes: pipes,
                  groundTop: groundTop,
                  score: score,
                ),
              ),
              if (state == GameState.ready)
                const Center(
                  child: Text(
                    'Başlamak için dokun',
                    style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              if (state == GameState.dead)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Oyun Bitti',
                            style: TextStyle(
                                fontSize: 30,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Skor: $score   En iyi: $best',
                            style: const TextStyle(
                                fontSize: 20, color: Colors.white)),
                        const SizedBox(height: 8),
                        const Text('Tekrar için dokun',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class GamePainter extends CustomPainter {
  final double birdX, birdY, birdV, groundTop;
  final List<Pipe> pipes;
  final int score;

  GamePainter({
    required this.birdX,
    required this.birdY,
    required this.birdV,
    required this.pipes,
    required this.groundTop,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gökyüzü
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF70C5CE),
    );

    // Borular
    final pipePaint = Paint()..color = const Color(0xFF4CAF50);
    final capPaint = Paint()..color = const Color(0xFF2E7D32);
    const gap = _GamePageState.gap;
    const w = _GamePageState.pipeWidth;
    for (final p in pipes) {
      final topH = p.gapY - gap / 2;
      final bottomY = p.gapY + gap / 2;
      canvas.drawRect(Rect.fromLTWH(p.x, 0, w, topH), pipePaint);
      canvas.drawRect(Rect.fromLTWH(p.x, bottomY, w, groundTop - bottomY), pipePaint);
      canvas.drawRect(Rect.fromLTWH(p.x - 4, topH - 24, w + 8, 24), capPaint);
      canvas.drawRect(Rect.fromLTWH(p.x - 4, bottomY, w + 8, 24), capPaint);
    }

    // Zemin
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop),
      Paint()..color = const Color(0xFFDED895),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, size.width, 10),
      Paint()..color = const Color(0xFF73BF2E),
    );

    // Kuş (hıza göre hafif eğilir)
    canvas.save();
    canvas.translate(birdX, birdY);
    canvas.rotate((birdV / 900).clamp(-0.5, 0.9));
    canvas.drawCircle(
        Offset.zero, _GamePageState.birdRadius, Paint()..color = Colors.amber);
    canvas.drawCircle(const Offset(6, -5), 5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(8, -5), 2.5, Paint()..color = Colors.black);
    canvas.drawPath(
      Path()
        ..moveTo(12, 0)
        ..lineTo(24, 4)
        ..lineTo(12, 8)
        ..close(),
      Paint()..color = Colors.deepOrange,
    );
    canvas.restore();

    // Skor
    final tp = TextPainter(
      text: TextSpan(
        text: '$score',
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, 60));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
