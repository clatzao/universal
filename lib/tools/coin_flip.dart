import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const coinFlipDuration = Duration(milliseconds: 1800);

/// Parte da animação em que a moeda está no ar; o resto é o quique ao cair.
const _landAt = 0.82;

/// Altura da moeda (0 a 1) em cada ponto da animação.
double coinHeight(double t) {
  if (t < _landAt) {
    final x = t / _landAt;
    return 4 * x * (1 - x);
  }
  final x = (t - _landAt) / (1 - _landAt);
  return 0.4 * x * (1 - x);
}

/// Giro da moeda. Termina antes do quique, sempre deitada no lado sorteado.
double coinAngle(double t, {required bool fromCara, required bool toCara}) {
  final begin = fromCara ? 0.0 : pi;
  final end = 12 * pi + (toCara ? 0.0 : pi);
  return begin + (end - begin) * Curves.easeOutQuad.transform((t / _landAt).clamp(0.0, 1.0));
}

class CoinFlip extends StatefulWidget {
  final Random random;
  final String? result;

  /// Recebe null ao jogar e o lado sorteado quando a moeda cai.
  final ValueChanged<String?> onResult;

  const CoinFlip({super.key, required this.random, required this.result, required this.onResult});

  @override
  State<CoinFlip> createState() => _CoinFlipState();
}

class _CoinFlipState extends State<CoinFlip> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: coinFlipDuration, value: 1);
  late bool fromCara = widget.result != 'Coroa';
  late bool toCara = fromCara;
  bool flipping = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    HapticFeedback.mediumImpact();
    setState(() {
      flipping = true;
      fromCara = toCara;
      toCara = widget.random.nextBool();
    });
    widget.onResult(null);
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await controller.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => flipping = false);
    widget.onResult(toCara ? 'Cara' : 'Coroa');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 250,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _Coin(
              height: coinHeight(controller.value),
              angle: coinAngle(controller.value, fromCara: fromCara, toCara: toCara),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: flipping ? null : _flip,
          icon: const Icon(Icons.monetization_on_outlined),
          label: Text(flipping ? 'Girando…' : 'Jogar a moeda'),
        ),
      ],
    );
  }
}

class _Coin extends StatelessWidget {
  final double height;
  final double angle;

  const _Coin({required this.height, required this.angle});

  static const _size = 120.0;

  @override
  Widget build(BuildContext context) {
    final turn = cos(angle);
    // De perfil a moeda vira uma linha, sem sumir; o disco de trás dá a espessura.
    final squash = max(turn.abs(), 0.05);
    final edge = sin(angle) * 7;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: _size * (1 - height * 0.5),
          height: 10,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4 - height * 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Positioned(
          bottom: 12,
          child: Transform.translate(
            offset: Offset(0, -height * 115),
            child: SizedBox.square(
              dimension: _size,
              child: Stack(
                children: [
                  Transform.translate(
                    offset: Offset(0, edge),
                    child: Transform.scale(
                      scaleY: squash,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFF8A6A14), shape: BoxShape.circle),
                        child: SizedBox.square(dimension: _size),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scaleY: squash,
                    child: _CoinFace(cara: turn >= 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinFace extends StatelessWidget {
  final bool cara;

  const _CoinFace({required this.cara});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF5C4508);
    return Container(
      width: _Coin._size,
      height: _Coin._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB38B1D), width: 5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7DC7C), Color(0xFFD9A92E)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cara ? Icons.face_outlined : Icons.workspace_premium_outlined, size: 44, color: ink),
          Text(
            cara ? 'CARA' : 'COROA',
            style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
