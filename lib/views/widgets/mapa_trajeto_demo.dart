import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Esquema ilustrado da rota. A etapa zero exibe a prévia da viagem.
class MapaTrajetoDemo extends StatefulWidget {
  const MapaTrajetoDemo({super.key, this.etapa = 0});

  final int etapa;

  @override
  State<MapaTrajetoDemo> createState() => _MapaTrajetoDemoState();
}

class _MapaTrajetoDemoState extends State<MapaTrajetoDemo> {
  bool _ampliado = false;

  @override
  Widget build(BuildContext context) {
    final etapa = widget.etapa.clamp(-1, 5).toInt();
    final posicao = _MapaPainter.posicoes[etapa + 1];
    const descricoes = [
      'no Centro',
      'no centro do trajeto ilustrativo',
      'a caminho do primeiro ponto',
      'no primeiro ponto de embarque',
      'a caminho do segundo ponto',
      'no segundo ponto de embarque',
      'na Faculdade',
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 360 / 255,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              image: true,
              label:
                  'Mapa demonstrativo de Centro a Faculdade, com dois '
                  'pontos de embarque. Ônibus simulado ${descricoes[etapa + 1]}.',
              child: AnimatedScale(
                scale: _ampliado ? 1.7 : 1,
                alignment: Alignment(
                  posicao.dx * 2 / 360 - 1,
                  posicao.dy * 2 / 255 - 1,
                ),
                duration: const Duration(milliseconds: 200),
                child: RepaintBoundary(
                  child: CustomPaint(painter: _MapaPainter(posicao)),
                ),
              ),
            ),
            Positioned(
              left: 9,
              top: 8,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xF5FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    child: Text(
                      'Mapa demonstrativo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF425673),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: const Color(0x66334E78),
                child: IconButton(
                  tooltip: _ampliado
                      ? 'Mostrar trajeto completo'
                      : 'Ampliar posição simulada do ônibus',
                  onPressed: () => setState(() => _ampliado = !_ampliado),
                  iconSize: 23,
                  icon: Icon(
                    _ampliado
                        ? Icons.zoom_out_map_rounded
                        : Icons.near_me_rounded,
                    color: const Color(0xFF0562DE),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaPainter extends CustomPainter {
  const _MapaPainter(this.onibus);

  final Offset onibus;
  static const _azul = Color(0xFF0069E4);
  static const _branco = Colors.white;
  static const _centro = Offset(44, 211);
  static const _paradaUm = Offset(100, 164);
  static const _paradaDois = Offset(230, 97);
  static const _faculdade = Offset(313, 46);
  static const posicoes = [
    _centro,
    Offset(176, 133),
    Offset(77, 196),
    _paradaUm,
    Offset(176, 133),
    _paradaDois,
    _faculdade,
  ];

  Paint _traco(Color cor, double largura) => Paint()
    ..color = cor
    ..style = PaintingStyle.stroke
    ..strokeWidth = largura
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Offset _esquina(double x, double y) => Offset(
    x +
        19 * math.sin((y + x / 3) / 65) +
        2.5 * math.sin(x + y) -
        (y - 125) * .12,
    y + 21 * math.sin(x / 65 + y / 175) + 2 * math.cos(x - y) - x * .10,
  );

  void _quadras(Canvas canvas) {
    const larguras = [36.0, 17.0, 29.0, 20.0, 42.0];
    const alturas = [28.0, 13.0, 22.0, 18.0];
    const cores = [Color(0xFFE8EBF3), Color(0xFFEAEDF4), Color(0xFFE5E9F2)];
    const parques = {15, 29, 52, 65, 83, 107, 160, 168, 172, 210};
    final lote = Paint();
    final rua = _traco(const Color(0xFFF8F9FD), 2);
    var x = -62.0;
    for (var coluna = 0; x < 405; coluna++) {
      final proximoX = x + larguras[coluna % larguras.length];
      var y = -65.0;
      for (var linha = 0; y < 333; linha++) {
        final proximoY = y + alturas[linha % alturas.length];
        final quadra = Path()
          ..addPolygon([
            _esquina(x, y),
            _esquina(proximoX, y),
            _esquina(proximoX, proximoY),
            _esquina(x, proximoY),
          ], true);
        final id = coluna * 19 + linha;
        lote.color = parques.contains(id)
            ? const Color(0xFFCCEBCC)
            : cores[id % cores.length];
        canvas.drawPath(quadra, lote);
        canvas.drawPath(quadra, rua);
        y = proximoY;
      }
      x = proximoX;
    }
    final parque = Path()
      ..moveTo(-4, -4)
      ..lineTo(62, -4)
      ..lineTo(77, 30)
      ..lineTo(59, 46)
      ..lineTo(35, 30)
      ..quadraticBezierTo(17, 32, -4, 42)
      ..close();
    canvas.drawPath(parque, Paint()..color = const Color(0xFFBBE9BD));
    canvas.drawPath(parque, _traco(_branco, 3));
    final jardins = Path()
      ..addPolygon(const [
        Offset(306, -4),
        Offset(334, -4),
        Offset(318, 20),
        Offset(295, 13),
      ], true)
      ..addPolygon(const [
        Offset(268, 151),
        Offset(307, 123),
        Offset(300, 162),
        Offset(276, 184),
        Offset(259, 170),
      ], true)
      ..moveTo(267, 206)
      ..quadraticBezierTo(300, 202, 310, 168)
      ..lineTo(340, 162)
      ..quadraticBezierTo(349, 170, 333, 180)
      ..quadraticBezierTo(311, 190, 305, 215)
      ..lineTo(272, 230)
      ..close();
    canvas.drawPath(jardins, Paint()..color = const Color(0xFFC5EAC5));
    final coletoras = Path()
      ..moveTo(78, -4)
      ..lineTo(114, 57)
      ..lineTo(113, 86)
      ..lineTo(-4, 114)
      ..moveTo(208, -4)
      ..lineTo(199, 30)
      ..lineTo(162, 119)
      ..quadraticBezierTo(180, 136, 174, 164)
      ..lineTo(158, 260)
      ..moveTo(-4, 228)
      ..lineTo(96, 194)
      ..lineTo(185, 193)
      ..quadraticBezierTo(201, 192, 218, 181)
      ..lineTo(365, 84);
    canvas.drawPath(coletoras, _traco(_branco, 3.5));
  }

  void _rio(Canvas canvas) {
    final rio = Path()
      ..moveTo(188, 264)
      ..cubicTo(198, 212, 234, 205, 259, 203)
      ..cubicTo(300, 202, 301, 176, 311, 145)
      ..cubicTo(316, 127, 330, 112, 368, 92);
    canvas.drawPath(rio, _traco(_branco, 17));
    canvas.drawPath(rio, _traco(const Color(0xFF9DD9F5), 12));
    final ponte = Path()
      ..moveTo(177, 129)
      ..quadraticBezierTo(209, 118, 227, 142)
      ..lineTo(254, 169)
      ..quadraticBezierTo(270, 188, 280, 213)
      ..lineTo(301, 258);
    canvas.drawPath(ponte, _traco(_branco, 3.5));
  }

  void _rota(Canvas canvas) {
    final trajeto = Path()
      ..moveTo(_centro.dx, _centro.dy)
      ..lineTo(70, 199)
      ..quadraticBezierTo(77, 197, 80, 188)
      ..lineTo(85, 173)
      ..quadraticBezierTo(87, 165, 100, 164)
      ..lineTo(142, 158)
      ..quadraticBezierTo(149, 157, 152, 147)
      ..quadraticBezierTo(155, 139, 166, 137)
      ..lineTo(176, 133)
      ..lineTo(207, 128)
      ..quadraticBezierTo(214, 126, 216, 118)
      ..lineTo(220, 103)
      ..quadraticBezierTo(223, 97, 230, 97)
      ..lineTo(262, 92)
      ..quadraticBezierTo(269, 91, 270, 82)
      ..lineTo(274, 57)
      ..quadraticBezierTo(275, 51, 284, 49)
      ..lineTo(296, 45)
      ..lineTo(_faculdade.dx, _faculdade.dy);
    canvas.drawPath(trajeto, _traco(_branco, 8));
    canvas.drawPath(trajeto, _traco(_azul, 5.6));
  }

  void _icone(Canvas canvas, IconData icone, Offset centro, double tamanho) {
    final texto = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icone.codePoint),
        style: TextStyle(
          fontFamily: icone.fontFamily,
          package: icone.fontPackage,
          fontSize: tamanho,
          height: 1,
          color: _branco,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, centro - Offset(texto.width / 2, texto.height / 2));
    texto.dispose();
  }

  void _marcador(Canvas canvas, Offset ponto, {IconData? icone}) {
    canvas.save();
    canvas.translate(ponto.dx, ponto.dy);
    final pin = Path()
      ..moveTo(0, -4)
      ..cubicTo(-3, -8, -13, -16, -13, -23)
      ..cubicTo(-13, -41, 13, -41, 13, -23)
      ..cubicTo(13, -16, 3, -8, 0, -4)
      ..close();
    final azul = Paint()..color = _azul;
    canvas.drawCircle(Offset.zero, 5, azul);
    canvas.drawCircle(Offset.zero, 3, Paint()..color = _branco);
    canvas.drawShadow(pin, const Color(0xFF2D4373), 3, false);
    canvas.drawPath(pin, _traco(_branco, 4.5));
    azul.shader = const LinearGradient(
      colors: [Color(0xFF1276DB), Color(0xFF003D95)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(-13, -37, 26, 33));
    canvas.drawPath(pin, azul);
    if (icone == null) {
      canvas.drawCircle(const Offset(0, -23), 4.7, Paint()..color = _branco);
    } else {
      _icone(canvas, icone, const Offset(0, -23), 18);
    }
    canvas.restore();
  }

  void _rotulo(Canvas canvas, String valor, Offset origem) {
    final texto = TextPainter(
      text: TextSpan(
        text: valor,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF091D46),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final inicio = Offset(
      math.min(origem.dx, 356 - texto.width - 15),
      origem.dy,
    );
    final caixa = RRect.fromRectAndRadius(
      Rect.fromLTWH(inicio.dx, inicio.dy, texto.width + 15, texto.height + 5),
      const Radius.circular(6),
    );
    canvas.drawShadow(
      Path()..addRRect(caixa),
      const Color(0xFF667891),
      3,
      false,
    );
    canvas.drawRRect(caixa, Paint()..color = _branco);
    texto.paint(canvas, inicio + const Offset(7.5, 2.5));
    texto.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 255);
    canvas.drawColor(const Color(0xFFFAFBFE), BlendMode.srcOver);
    _quadras(canvas);
    _rio(canvas);
    _rota(canvas);
    _marcador(canvas, _centro);
    _marcador(canvas, _paradaUm, icone: Icons.groups_rounded);
    _marcador(canvas, _paradaDois, icone: Icons.groups_rounded);
    _marcador(canvas, _faculdade, icone: Icons.sports_score_rounded);
    _rotulo(canvas, 'Centro', const Offset(18, 216));
    _rotulo(canvas, 'Faculdade', const Offset(286, 52));
    canvas.drawCircle(onibus, 28, Paint()..color = const Color(0x332177EB));
    canvas.drawCircle(onibus, 16, Paint()..color = _branco);
    canvas.drawCircle(onibus, 13.4, Paint()..color = _azul);
    _icone(canvas, Icons.directions_bus_rounded, onibus, 20);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapaPainter oldDelegate) => oldDelegate.onibus != onibus;
}
