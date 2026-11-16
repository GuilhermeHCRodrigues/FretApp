import 'package:flutter/widgets.dart';

/// Descarta [controladores] quando o diálogo sai da tela de vez.
///
/// Use em diálogos cujos controladores são criados por quem chama:
///
/// ```dart
/// final nome = TextEditingController();
/// await showDialog(
///   context: context,
///   builder: (_) => DescartarAoFechar(
///     controladores: [nome],
///     child: AlertDialog(...),
///   ),
/// );
/// // NÃO chamar nome.dispose() aqui.
/// ```
///
/// Descartar logo após o `showDialog` retornar quebra o app
/// ("_dependents.isEmpty" / "TextEditingController was used after being
/// disposed"): o diálogo ainda está na animação de fechar e continua usando
/// os controladores. Este widget só descarta no próprio `dispose`, que roda
/// depois que a rota do diálogo foi removida.
class DescartarAoFechar extends StatefulWidget {
  const DescartarAoFechar({
    super.key,
    required this.controladores,
    required this.child,
  });

  final List<ChangeNotifier> controladores;
  final Widget child;

  @override
  State<DescartarAoFechar> createState() => _DescartarAoFecharState();
}

class _DescartarAoFecharState extends State<DescartarAoFechar> {
  @override
  void dispose() {
    for (final c in widget.controladores) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
