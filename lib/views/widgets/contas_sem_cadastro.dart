import 'package:flutter/material.dart';

import '../../services/acesso_servico.dart';

/// Aviso com os logins que sobraram de cadastros excluídos.
///
/// Esses logins seguram o e-mail (impedem criar o acesso de novo) e aparecem
/// no Financeiro como "Passageiro sem nome". Some quando não há nenhum.
class ContasSemCadastro extends StatefulWidget {
  const ContasSemCadastro({
    super.key,
    required this.tipo,
    this.listar = listarContasSemCadastro,
    this.remover = removerAcesso,
  });

  final TipoAcesso tipo;
  final Future<List<ContaOrfa>> Function(TipoAcesso? tipo) listar;
  final Future<void> Function(String perfilId) remover;

  @override
  State<ContasSemCadastro> createState() => ContasSemCadastroState();
}

class ContasSemCadastroState extends State<ContasSemCadastro> {
  List<ContaOrfa> _contas = const [];
  final _removendo = <String>{};

  @override
  void initState() {
    super.initState();
    recarregar();
  }

  /// Chamado pela tela depois de excluir/criar cadastros.
  Future<void> recarregar() async {
    try {
      final contas = await widget.listar(widget.tipo);
      if (mounted) setState(() => _contas = contas);
    } catch (_) {
      // Função não publicada ou sem conexão: só não mostra o aviso.
      if (mounted) setState(() => _contas = const []);
    }
  }

  Future<void> _remover(ContaOrfa conta) async {
    final rotulo = conta.email ?? conta.nome ?? 'esta conta';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Remover conta?'),
        content: Text(
          'O login $rotulo será apagado e o e-mail ficará livre para um novo '
          'cadastro. Se houver assinatura no Stripe, ela será cancelada, e o '
          'histórico de mensalidades dessa conta será apagado. '
          'Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogo).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _removendo.add(conta.perfilId));
    try {
      await widget.remover(conta.perfilId);
      if (!mounted) return;
      setState(
        () => _contas = [
          for (final c in _contas)
            if (c.perfilId != conta.perfilId) c,
        ],
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Conta $rotulo removida.')));
    } on AcessoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _removendo.remove(conta.perfilId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contas.isEmpty) return const SizedBox.shrink();
    final cores = Theme.of(context).colorScheme;
    final n = _contas.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: cores.errorContainer,
        child: ExpansionTile(
          leading: Icon(Icons.person_off_outlined, color: cores.error),
          title: Text(
            n == 1 ? '1 conta sem cadastro' : '$n contas sem cadastro',
            style: TextStyle(
              color: cores.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Logins que sobraram de cadastros excluídos. Eles ocupam o '
            'e-mail e aparecem no Financeiro.',
            style: TextStyle(color: cores.onErrorContainer),
          ),
          children: [
            for (final c in _contas)
              ListTile(
                title: Text(c.email ?? 'Sem e-mail'),
                subtitle: Text(
                  [
                    c.nome ?? 'Sem nome',
                    if (c.tipo == null) 'sem perfil' else c.tipo!,
                  ].join(' • '),
                ),
                trailing: _removendo.contains(c.perfilId)
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: () => _remover(c),
                        icon: Icon(Icons.delete_outline, color: cores.error),
                        label: Text(
                          'Remover',
                          style: TextStyle(color: cores.error),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
