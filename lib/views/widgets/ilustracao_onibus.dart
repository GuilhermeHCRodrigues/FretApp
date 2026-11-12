import 'package:flutter/material.dart';

class IlustracaoOnibus extends StatelessWidget {
  const IlustracaoOnibus({super.key});

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.contain,
      child: CustomPaint(size: Size(140, 76), painter: _OnibusPainter()),
    );
  }
}

class _OnibusPainter extends CustomPainter {
  const _OnibusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const marinho = Color(0xFF0E3E82);
    const vidro = Color(0xFF125BA7);
    final tinta = Paint();
    void forma(Path path, Color cor) =>
        canvas.drawPath(path, tinta..color = cor);
    void oval(Rect rect, Color cor) =>
        canvas.drawOval(rect, tinta..color = cor);

    // Nuvem e colinas ao fundo.
    forma(
      Path()
        ..moveTo(5, 29)
        ..quadraticBezierTo(6, 18, 16, 21)
        ..cubicTo(20, 7, 36, 9, 40, 21)
        ..quadraticBezierTo(51, 18, 54, 29)
        ..close(),
      const Color(0xFFBFDDFA),
    );
    forma(
      Path()
        ..moveTo(0, 49)
        ..quadraticBezierTo(24, 26, 58, 41)
        ..quadraticBezierTo(85, 50, 107, 45)
        ..quadraticBezierTo(127, 38, 140, 40)
        ..lineTo(140, 57)
        ..close(),
      const Color(0xFFD4E8FD),
    );
    oval(const Rect.fromLTWH(26, 65, 109, 4), const Color(0x333F7EBB));
    oval(const Rect.fromLTWH(101, 55, 12, 12), marinho);

    final carroceria = Path()
      ..moveTo(30, 32)
      ..quadraticBezierTo(31, 29, 36, 27)
      ..lineTo(85, 12)
      ..quadraticBezierTo(91, 10, 97, 11)
      ..lineTo(120, 13)
      ..quadraticBezierTo(126, 13, 128, 19)
      ..quadraticBezierTo(133, 34, 133, 55)
      ..quadraticBezierTo(134, 62, 128, 64)
      ..lineTo(89, 65)
      ..lineTo(32, 62)
      ..quadraticBezierTo(28, 61, 29, 56)
      ..close();
    final verniz = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF8FCFF), Color(0xFFABCCF5)],
      stops: [0, 0.65, 1],
    ).createShader(const Rect.fromLTWH(29, 11, 104, 54));
    canvas.drawPath(carroceria, Paint()..shader = verniz);

    // Vidros laterais em perspectiva.
    forma(
      Path()
        ..moveTo(31, 33)
        ..lineTo(86, 16)
        ..quadraticBezierTo(88, 15, 88, 19)
        ..lineTo(88, 52)
        ..quadraticBezierTo(81, 52, 80, 43)
        ..quadraticBezierTo(80, 39, 76, 40)
        ..lineTo(30, 48)
        ..close(),
      vidro,
    );
    for (final x in [40.0, 52.0, 66.0, 80.0]) {
      canvas.drawLine(
        Offset(x, 42.5 - x * 0.31),
        Offset(x, 53 - x * 0.17),
        Paint()
          ..color = marinho
          ..strokeWidth = 1,
      );
    }
    forma(
      Path()
        ..moveTo(92, 16)
        ..quadraticBezierTo(107, 15, 123, 18)
        ..quadraticBezierTo(128, 18, 129, 25)
        ..lineTo(131, 44)
        ..quadraticBezierTo(130, 49, 124, 49)
        ..lineTo(99, 49)
        ..quadraticBezierTo(92, 48, 92, 42)
        ..close(),
      vidro,
    );
    forma(
      Path()
        ..moveTo(94, 42)
        ..quadraticBezierTo(110, 38, 119, 23)
        ..lineTo(120, 35)
        ..lineTo(105, 47)
        ..quadraticBezierTo(96, 48, 94, 42),
      const Color(0xFF1A70BC),
    );
    forma(
      Path()
        ..moveTo(126, 21)
        ..lineTo(134, 21)
        ..quadraticBezierTo(137, 21, 137, 24)
        ..lineTo(137, 31)
        ..quadraticBezierTo(134, 33, 134, 29)
        ..lineTo(134, 24)
        ..lineTo(127, 24)
        ..close(),
      marinho,
    );
    forma(
      Path()
        ..moveTo(30, 55)
        ..lineTo(79, 49)
        ..lineTo(79, 53)
        ..lineTo(30, 58)
        ..close(),
      const Color(0xFFCCE3FC),
    );
    for (final (x, y, largura, altura) in [
      (40.0, 60.0, 6.0, 12.0),
      (74.0, 60.0, 8.0, 16.0),
    ]) {
      final centro = Offset(x, y);
      oval(
        Rect.fromCenter(center: centro, width: largura, height: altura),
        marinho,
      );
      oval(
        Rect.fromCenter(
          center: centro,
          width: largura * 0.45,
          height: altura * 0.52,
        ),
        const Color(0xFF88B5E4),
      );
    }
    forma(
      Path()
        ..moveTo(92, 57)
        ..quadraticBezierTo(114, 59, 132, 56)
        ..lineTo(131, 60)
        ..quadraticBezierTo(110, 63, 92, 60)
        ..close(),
      const Color(0xFF80AADC),
    );
    oval(const Rect.fromLTWH(95, 52, 5, 2.7), const Color(0xFFFABB52));
    oval(const Rect.fromLTWH(127, 51, 4, 2.7), const Color(0xFFFABB52));
    canvas.drawRect(const Rect.fromLTWH(107, 59, 9, 2), tinta..color = marinho);
  }

  @override
  bool shouldRepaint(_OnibusPainter oldDelegate) => false;
}
