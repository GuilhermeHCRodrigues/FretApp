import 'package:flutter/material.dart';

/// Indicador de carregamento centralizado, com mensagem opcional.
class EstadoCarregando extends StatelessWidget {
  const EstadoCarregando({super.key, this.mensagem});

  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (mensagem != null) ...[
              const SizedBox(height: 16),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista vazia ou "nada por aqui ainda".
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.titulo,
    this.mensagem,
    this.icone = Icons.inbox_outlined,
    this.acao,
  });

  final String titulo;
  final String? mensagem;
  final IconData icone;

  /// Botão opcional (ex.: "Cadastrar veículo").
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return _EstadoBase(
      icone: icone,
      corIcone: Theme.of(context).colorScheme.primary,
      titulo: titulo,
      mensagem: mensagem,
      acao: acao,
    );
  }
}

/// Falha ao carregar, com botão "Tentar de novo".
class EstadoErro extends StatelessWidget {
  const EstadoErro({
    super.key,
    this.titulo = 'Não foi possível carregar',
    this.mensagem,
    this.aoTentarDeNovo,
  });

  final String titulo;
  final String? mensagem;
  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return _EstadoBase(
      icone: Icons.error_outline,
      corIcone: Theme.of(context).colorScheme.error,
      titulo: titulo,
      mensagem: mensagem,
      acao: aoTentarDeNovo == null
          ? null
          : OutlinedButton.icon(
              onPressed: aoTentarDeNovo,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
    );
  }
}

class _EstadoBase extends StatelessWidget {
  const _EstadoBase({
    required this.icone,
    required this.corIcone,
    required this.titulo,
    this.mensagem,
    this.acao,
  });

  final IconData icone;
  final Color corIcone;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 48, color: corIcone),
              const SizedBox(height: 16),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (mensagem != null) ...[
                const SizedBox(height: 8),
                Text(
                  mensagem!,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (acao != null) ...[const SizedBox(height: 24), acao!],
            ],
          ),
        ),
      ),
    );
  }
}
