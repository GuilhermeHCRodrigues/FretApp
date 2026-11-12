import 'package:flutter/material.dart';

/// Cartão padrão do app (branco, raio 16, borda). Substitui o uso misto de
/// `Card` e `Container + BoxDecoration`. A aparência vem do `cardTheme`.
class CartaoApp extends StatelessWidget {
  const CartaoApp({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.cor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Cor de fundo alternativa (ex.: `colorScheme.primaryContainer`).
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final conteudo = Padding(padding: padding, child: child);
    return Card(
      color: cor,
      child: onTap == null ? conteudo : InkWell(onTap: onTap, child: conteudo),
    );
  }
}
