import 'package:flutter/material.dart';

/// Desenho em pixel descrito por linhas de texto. Cada caractere é um pixel:
/// "." é transparente e os outros caracteres são cores da [palette].
class PixelSprite {
  final List<String> rows;
  final Map<String, Color> palette;

  const PixelSprite(this.rows, this.palette);

  int get width => rows.first.length;
  int get height => rows.length;
}

/// Pinta o desenho sem suavização, com cada pixel em pixels inteiros da tela para ficar nítido.
class PixelArt extends StatelessWidget {
  final PixelSprite sprite;
  final double size;

  /// Substitui todas as cores da paleta, para ícones que seguem a cor do tema.
  final Color? color;

  const PixelArt(this.sprite, {super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * sprite.height / sprite.width,
    child: CustomPaint(painter: _PixelPainter(sprite, color, MediaQuery.devicePixelRatioOf(context))),
  );
}

class _PixelPainter extends CustomPainter {
  final PixelSprite sprite;
  final Color? color;
  final double ratio;

  _PixelPainter(this.sprite, this.color, this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    // Cada pixel do desenho ocupa um número inteiro de pixels físicos.
    final cell = ((size.width * ratio / sprite.width).floor().clamp(1, 1 << 20)) / ratio;
    final offset = Offset(
      ((size.width - cell * sprite.width) / 2 * ratio).roundToDouble() / ratio,
      ((size.height - cell * sprite.height) / 2 * ratio).roundToDouble() / ratio,
    );
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < sprite.height; y++) {
      final row = sprite.rows[y];
      for (var x = 0; x < row.length; x++) {
        final c = color ?? sprite.palette[row[x]];
        if (row[x] == '.' || c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(offset.dx + x * cell, offset.dy + y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.sprite != sprite || old.color != color || old.ratio != ratio;
}

const _ink = {'#': Colors.white};

/// Ícones das abas, 12 × 12. Desenhados em uma cor e pintados com a cor do tema.
abstract final class PixelIcons {
  static const hoje = PixelSprite([
    '.....##.....',
    '.#...##...#.',
    '..#......#..',
    '....####....',
    '...######...',
    '##.######.##',
    '##.######.##',
    '...######...',
    '....####....',
    '..#......#..',
    '.#...##...#.',
    '.....##.....',
  ], _ink);

  static const lembretes = PixelSprite([
    '.....##.....',
    '....####....',
    '...######...',
    '..########..',
    '..########..',
    '..########..',
    '..########..',
    '.##########.',
    '############',
    '............',
    '.....##.....',
    '............',
  ], _ink);

  static const habitos = PixelSprite([
    '............',
    '..........##',
    '.........###',
    '........###.',
    '.......###..',
    '##....###...',
    '###..###....',
    '.######.....',
    '..####......',
    '...##.......',
    '............',
    '............',
  ], _ink);

  static const treinos = PixelSprite([
    '............',
    '............',
    '##........##',
    '##........##',
    '###......###',
    '############',
    '############',
    '###......###',
    '##........##',
    '##........##',
    '............',
    '............',
  ], _ink);

  static const notas = PixelSprite([
    '#########...',
    '#.......##..',
    '#.......#.#.',
    '#.......####',
    '#..........#',
    '#.######...#',
    '#..........#',
    '#.#####....#',
    '#..........#',
    '#.######...#',
    '#..........#',
    '############',
  ], _ink);

  static const noticias = PixelSprite([
    '############',
    '#..........#',
    '#.####.###.#',
    '#.####.....#',
    '#.####.###.#',
    '#.####.....#',
    '#......###.#',
    '#.########.#',
    '#..........#',
    '#.########.#',
    '#..........#',
    '############',
  ], _ink);

  static const financas = PixelSprite([
    '.....##.....',
    '...######...',
    '..##.##.##..',
    '..##.##.....',
    '...#####....',
    '.....####...',
    '.....##.##..',
    '..##.##.##..',
    '...######...',
    '.....##.....',
    '............',
    '............',
  ], _ink);

  static const curiosidades = PixelSprite([
    '....####....',
    '...#....#...',
    '..#......#..',
    '..#..##..#..',
    '..#..##..#..',
    '..#......#..',
    '...#....#...',
    '....#..#....',
    '....####....',
    '....####....',
    '.....##.....',
    '............',
  ], _ink);

  static const jogos = PixelSprite([
    '............',
    '............',
    '.##########.',
    '############',
    '##.#####.###',
    '#...###.#.##',
    '##.#####.###',
    '############',
    '###......###',
    '##........##',
    '............',
    '............',
  ], _ink);

  static const mais = PixelSprite([
    '#####..#####',
    '#...#..#...#',
    '#...#..#...#',
    '#...#..#...#',
    '#####..#####',
    '............',
    '............',
    '#####..#####',
    '#...#..#...#',
    '#...#..#...#',
    '#...#..#...#',
    '#####..#####',
  ], _ink);
}

/// Logo do app: a letra U com sombra e o ponto dourado, nas cores do tema.
const pixelLogo = PixelSprite(
  [
    '............',
    '.###....###.',
    '.###+oo.###+',
    '.###+oo.###+',
    '.###+...###+',
    '.###+...###+',
    '.###+...###+',
    '.###+...###+',
    '.####..####+',
    '..########++',
    '...######++.',
    '....++++++..',
  ],
  {'#': Color(0xFFE6E6E9), '+': Color(0xFF6E6E78), 'o': Color(0xFFD9C9A3)},
);

/// Despertador da tela de alarme, 16 × 16.
const pixelAlarmClock = PixelSprite(
  [
    '.##..........##.',
    '###..........###',
    '##...######...##',
    '...##......##...',
    '..#..........#..',
    '.#.....#......#.',
    '.#.....#......#.',
    '#......#.......#',
    '#......####....#',
    '#..............#',
    '.#............#.',
    '.#............#.',
    '..#..........#..',
    '...##......##...',
    '..#..######..#..',
    '.#............#.',
  ],
  {'#': Color(0xFFE6E6E9)},
);
