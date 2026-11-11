import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Esquema ilustrado da rota. A etapa zero exibe a prévia da viagem.
class MapaTrajetoDemo extends StatefulWidget {
  const MapaTrajetoDemo({super.key, this.etapa = 0, this.altura});

  static const proporcaoOriginal = 360 / 255;
  final int etapa;
  final double? altura;

  @override
  State<MapaTrajetoDemo> createState() => _MapaTrajetoDemoState();
}

class _MapaTrajetoDemoState extends State<MapaTrajetoDemo> {
  bool _ampliado = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
    final mapa = Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          image: true,
          label:
              'Mapa demonstrativo de Centro a Faculdade, com dois '
              'pontos de embarque. Ônibus simulado ${descricoes[etapa + 1]}.',
          child: LayoutBuilder(
            builder: (context, limites) {
              final janela = _janelaMapa(limites.biggest);
              return AnimatedScale(
                scale: _ampliado ? 1.7 : 1,
                alignment: Alignment(
                  (posicao.dx - janela.left) * 2 / janela.width - 1,
                  (posicao.dy - janela.top) * 2 / janela.height - 1,
                ),
                duration: const Duration(milliseconds: 200),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _MapaPainter(
                      posicao,
                      panoramico: widget.altura != null,
                    ),
                  ),
                ),
              );
            },
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Mapa demonstrativo',
                  style: tema.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tema.colorScheme.onSurfaceVariant,
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
                _ampliado ? Icons.zoom_out_map_rounded : Icons.near_me_rounded,
                color: tema.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: widget.altura == null
          ? AspectRatio(
              aspectRatio: MapaTrajetoDemo.proporcaoOriginal,
              child: mapa,
            )
          : SizedBox(
              width: double.infinity,
              height: widget.altura,
              child: mapa,
            ),
    );
  }
}

// A janela pode incluir ruas além do desenho original, sem deformar o trajeto.
Rect _janelaMapa(Size tamanho) {
  const base = Size(360, 255);
  if (tamanho.isEmpty) return Offset.zero & base;
  final escala = math.min(
    tamanho.width / base.width,
    tamanho.height / base.height,
  );
  final area = tamanho / escala;
  return Rect.fromCenter(
    center: const Offset(180, 127.5),
    width: area.width,
    height: area.height,
  );
}

class _MapaPainter extends CustomPainter {
  const _MapaPainter(this.onibus, {required this.panoramico});

  final Offset onibus;
  final bool panoramico;
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

  void _quadras(Canvas canvas, Rect area) {
    const larguras = [36.0, 17.0, 29.0, 20.0, 42.0];
    const alturas = [28.0, 13.0, 22.0, 18.0];
    const cores = [Color(0xFFE8EBF3), Color(0xFFEAEDF4), Color(0xFFE5E9F2)];
    const parques = {15, 29, 52, 65, 83, 107, 160, 168, 172, 210};
    final lote = Paint();
    final rua = _traco(const Color(0xFFF8F9FD), 2);
    // Iniciar em ciclos inteiros mantém as mesmas quadras ao redimensionar.
    final ciclosX = (math.max(0.0, -area.left - 1) / 144).ceil();
    final ciclosY = (math.max(0.0, -area.top - 1) / 81).ceil();
    var x = -62.0 - ciclosX * 144;
    for (
      var coluna = -ciclosX * larguras.length;
      x < area.right + 26 + area.bottom * .12;
      coluna++
    ) {
      final proximoX = x + larguras[coluna % larguras.length];
      var y = -65.0 - ciclosY * 81;
      for (
        var linha = -ciclosY * alturas.length;
        y < area.bottom + 40 + area.right * .10;
        linha++
      ) {
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
  }

  void _parquesEVias(Canvas canvas, Rect janela) {
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
    final margemX = math.max(0.0, -janela.left);
    final margemY = math.max(0.0, -janela.top);
    final coletoras = Path()
      ..moveTo(78 - margemY * 36 / 61, -4 - margemY)
      ..lineTo(114, 57)
      ..lineTo(113, 86)
      ..lineTo(-4 - margemX, 114 + margemX * 28 / 117)
      ..moveTo(208 + margemY * 9 / 34, -4 - margemY)
      ..lineTo(199, 30)
      ..lineTo(162, 119)
      ..quadraticBezierTo(180, 136, 174, 164)
      ..lineTo(158 - margemY / 6, 260 + margemY)
      ..moveTo(-4 - margemX, 228 + margemX * .34)
      ..lineTo(96, 194)
      ..lineTo(185, 193)
      ..quadraticBezierTo(201, 192, 218, 181)
      ..lineTo(365 + margemX, 84 - margemX * 97 / 147);
    canvas.drawPath(coletoras, _traco(_branco, 3.5));
  }

  void _rio(Canvas canvas, Rect janela) {
    final margemX = math.max(0.0, -janela.left);
    final margemY = math.max(0.0, -janela.top);
    final rio = Path()..moveTo(188, 264);
    if (margemY > 0) {
      rio.moveTo(188 - margemY * 10 / 52, 264 + margemY);
      rio.lineTo(188, 264);
    }
    rio
      ..cubicTo(198, 212, 234, 205, 259, 203)
      ..cubicTo(300, 202, 301, 176, 311, 145)
      ..cubicTo(316, 127, 330, 112, 368, 92);
    if (margemX > 0) rio.lineTo(368 + margemX, 92 - margemX * 20 / 38);
    canvas.drawPath(rio, _traco(_branco, 17));
    canvas.drawPath(rio, _traco(const Color(0xFF9DD9F5), 12));
    final ponte = Path()
      ..moveTo(177, 129)
      ..quadraticBezierTo(209, 118, 227, 142)
      ..lineTo(254, 169)
      ..quadraticBezierTo(270, 188, 280, 213)
      ..lineTo(301 + margemY * 21 / 45, 258 + margemY);
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

  void _rotulo(Canvas canvas, String valor, Offset origem, double larguraMapa) {
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
      math.min(origem.dx, larguraMapa - 4 - texto.width - 15),
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
    if (size.isEmpty) return;
    final escala = math.min(size.width / 360, size.height / 255);
    final unidade = panoramico ? math.min(escala, 1.35) : escala;
    final janela = _janelaMapa(size);
    final area = size / unidade;
    Offset projetar(Offset ponto) =>
        (ponto - janela.topLeft) * (escala / unidade);

    canvas.save();
    canvas.scale(unidade);
    canvas.drawColor(const Color(0xFFFAFBFE), BlendMode.srcOver);
    canvas.save();
    canvas.scale(escala / unidade);
    canvas.translate(-janela.left, -janela.top);
    _quadras(canvas, janela);
    _parquesEVias(canvas, janela);
    _rio(canvas, janela);
    _rota(canvas);
    canvas.restore();

    final centro = projetar(_centro);
    final faculdade = projetar(_faculdade);
    final veiculo = projetar(onibus);
    _marcador(canvas, centro);
    _marcador(canvas, projetar(_paradaUm), icone: Icons.groups_rounded);
    _marcador(canvas, projetar(_paradaDois), icone: Icons.groups_rounded);
    _marcador(canvas, faculdade, icone: Icons.sports_score_rounded);
    _rotulo(canvas, 'Centro', centro + const Offset(-26, 5), area.width);
    _rotulo(canvas, 'Faculdade', faculdade + const Offset(-27, 6), area.width);
    canvas.drawCircle(veiculo, 28, Paint()..color = const Color(0x332177EB));
    canvas.drawCircle(veiculo, 16, Paint()..color = _branco);
    canvas.drawCircle(veiculo, 13.4, Paint()..color = _azul);
    _icone(canvas, Icons.directions_bus_rounded, veiculo, 20);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapaPainter oldDelegate) =>
      oldDelegate.onibus != onibus || oldDelegate.panoramico != panoramico;
}
