import 'package:flutter/material.dart';

import '../models/situacao_financeira.dart';
import '../services/mensalidade_servico.dart';
import '../tema/cores_status.dart';
import '../viewmodels/financeiro_viewmodel.dart';
import 'widgets/comum/cartao_app.dart';
import 'widgets/comum/chip_status.dart';
import 'widgets/comum/estados.dart';

/// Financeiro do administrador: tabela com todos os passageiros e o status
/// de pagamento da mensalidade do mês, com filtro "pagaram / não pagaram".
class FinanceiroView extends StatefulWidget {
  const FinanceiroView({super.key, this.onVoltar, this.modelo});

  /// Quando nulo (painel do administrador), a tela não mostra o próprio
  /// título nem o botão voltar: a navegação fica a cargo da casca.
  final VoidCallback? onVoltar;

  /// Permite que um teste forneça o modelo (sem Supabase).
  final FinanceiroViewModel? modelo;

  @override
  State<FinanceiroView> createState() => _FinanceiroViewState();
}

class _FinanceiroViewState extends State<FinanceiroView> {
  FinanceiroViewModel? _proprio;
  FinanceiroViewModel get vm =>
      widget.modelo ?? (_proprio ??= FinanceiroViewModel());

  final _busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    _busca.text = vm.busca;
    vm.carregar();
    vm.carregarValor();
  }

  @override
  void dispose() {
    _proprio?.dispose();
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => LayoutBuilder(
        builder: (context, limites) {
          final largo = limites.maxWidth >= 720;
          final margem = largo ? 24.0 : 12.0;
          return RefreshIndicator(
            onRefresh: vm.carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(margem, 12, margem, 24),
              children: [
                _cabecalho(),
                if (vm.carregando) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
                _CartaoValorMensalidade(vm: vm, aoAlterar: _abrirAlterarValor),
                const SizedBox(height: 12),
                _ResumoMes(resumo: vm.resumo),
                const SizedBox(height: 16),
                _filtros(largo),
                const SizedBox(height: 12),
                _conteudo(largo),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirAlterarValor() async {
    final atual = vm.valorMensalidade;
    if (atual == null) return;
    final resultado = await showDialog<ResultadoAlteracao>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoAlterarValor(vm: vm, atual: atual),
    );
    if (resultado == null || !mounted) return;
    final valor = formatarCentavos(resultado.valorCentavos);
    final partes = [
      'Mensalidade alterada para $valor.',
      if (resultado.atualizadas > 0)
        '${resultado.atualizadas} assinatura(s) passam a pagar o novo valor '
            'na próxima cobrança.',
      if (resultado.falhas > 0)
        '${resultado.falhas} assinatura(s) não puderam ser atualizadas; '
            'confira no painel do Stripe.',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(partes.join(' ')),
      ),
    );
    vm.carregarValor();
  }

  Widget _cabecalho() {
    final tema = Theme.of(context);
    return Row(
      children: [
        if (widget.onVoltar != null) ...[
          IconButton(
            onPressed: widget.onVoltar,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
          ),
          Text(
            'Financeiro',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: vm.carregando ? null : () => vm.mudarMes(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          flex: 3,
          child: Semantics(
            label: 'Competência',
            child: Text(
              formatarCompetencia(vm.competencia),
              textAlign: TextAlign.center,
              style: tema.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: vm.carregando ? null : () => vm.mudarMes(1),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: vm.carregando ? null : vm.carregar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _filtros(bool largo) {
    final tema = Theme.of(context);
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Status:',
          style: tema.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final f in FiltroPagamento.values)
          ChoiceChip(
            label: Text('${f.rotulo} (${vm.contar(f)})'),
            selected: vm.filtro == f,
            onSelected: (_) => vm.filtrar(f),
          ),
      ],
    );
    final busca = TextField(
      controller: _busca,
      onChanged: vm.buscar,
      decoration: InputDecoration(
        hintText: 'Buscar passageiro',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: vm.busca.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                onPressed: () {
                  _busca.clear();
                  vm.buscar('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [chips, const SizedBox(height: 12), busca],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: chips),
        const SizedBox(width: 16),
        SizedBox(width: 280, child: busca),
      ],
    );
  }

  Widget _conteudo(bool largo) {
    // Os estados têm rolagem própria: altura fixa dentro do ListView.
    Widget estado(Widget filho) => SizedBox(height: 320, child: filho);

    if (vm.erro != null && vm.linhas.isEmpty) {
      return estado(EstadoErro(mensagem: vm.erro, aoTentarDeNovo: vm.carregar));
    }
    if (vm.carregando && vm.linhas.isEmpty) {
      return estado(const EstadoCarregando());
    }
    if (vm.linhas.isEmpty) {
      return estado(
        const EstadoVazio(
          icone: Icons.groups_outlined,
          titulo: 'Nenhum passageiro cadastrado',
          mensagem: 'Cadastre passageiros e crie o acesso deles ao app.',
        ),
      );
    }
    final linhas = vm.linhasFiltradas;
    if (linhas.isEmpty) {
      return estado(
        EstadoVazio(
          icone: Icons.filter_alt_off_outlined,
          titulo: 'Ninguém neste filtro',
          mensagem: vm.busca.isEmpty
              ? 'Nenhum passageiro com status "${vm.filtro.rotulo}" em '
                    '${formatarCompetencia(vm.competencia)}.'
              : 'Nenhum passageiro encontrado para "${vm.busca}".',
        ),
      );
    }
    return largo
        ? _TabelaPassageiros(linhas: linhas)
        : _ListaPassageiros(linhas: linhas);
  }
}

/// Valor vigente da mensalidade no Stripe + botão "Alterar valor".
class _CartaoValorMensalidade extends StatelessWidget {
  const _CartaoValorMensalidade({required this.vm, required this.aoAlterar});

  final FinanceiroViewModel vm;
  final VoidCallback aoAlterar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final valor = vm.valorMensalidade;

    final Widget detalhe;
    if (valor != null) {
      detalhe = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatarCentavos(valor.valorCentavos)} / mês',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cores.onPrimaryContainer,
            ),
          ),
          Text(
            valor.assinaturas == 1
                ? '1 assinatura em vigor'
                : '${valor.assinaturas} assinaturas em vigor',
            style: tema.textTheme.bodySmall?.copyWith(
              color: cores.onPrimaryContainer,
            ),
          ),
        ],
      );
    } else if (vm.carregandoValor) {
      detalhe = Text(
        'Consultando o Stripe…',
        style: tema.textTheme.bodyMedium?.copyWith(
          color: cores.onPrimaryContainer,
        ),
      );
    } else {
      detalhe = Text(
        vm.erroValor ?? 'Valor indisponível.',
        style: tema.textTheme.bodyMedium?.copyWith(color: cores.error),
      );
    }

    final botao = valor != null
        ? FilledButton.icon(
            onPressed: aoAlterar,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Alterar valor'),
          )
        : vm.carregandoValor
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : OutlinedButton.icon(
            onPressed: vm.carregarValor,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          );

    return CartaoApp(
      cor: cores.primaryContainer,
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_outlined, color: cores.primary),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mensalidade no Stripe',
                      style: tema.textTheme.labelLarge?.copyWith(
                        color: cores.onPrimaryContainer,
                      ),
                    ),
                    detalhe,
                  ],
                ),
              ),
            ],
          ),
          botao,
        ],
      ),
    );
  }
}

class _DialogoAlterarValor extends StatefulWidget {
  const _DialogoAlterarValor({required this.vm, required this.atual});

  final FinanceiroViewModel vm;
  final ValorMensalidade atual;

  @override
  State<_DialogoAlterarValor> createState() => _DialogoAlterarValorState();
}

class _DialogoAlterarValorState extends State<_DialogoAlterarValor> {
  final _form = GlobalKey<FormState>();
  late final _valor = TextEditingController(
    text: formatarCentavos(widget.atual.valorCentavos).replaceFirst(r'R$ ', ''),
  );
  late var _aplicarAtuais = widget.atual.assinaturas > 0;
  var _enviando = false;
  String? _erro;

  /// Teto padrão do Pix Automático autorizado pelos assinantes (R$ 250,00).
  static const _tetoPixPadrao = 25000;

  @override
  void initState() {
    super.initState();
    _valor.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  String? _validar(String? texto) {
    final centavos = centavosDoTexto(texto ?? '');
    if (centavos == null) return 'Informe um valor, ex.: 250,00';
    if (centavos < 100 || centavos > 1000000) {
      return 'Use um valor entre R\$ 1,00 e R\$ 10.000,00';
    }
    if (centavos == widget.atual.valorCentavos) {
      return 'Este já é o valor atual';
    }
    return null;
  }

  Future<void> _confirmar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final resultado = await widget.vm.alterarValor(
        centavosDoTexto(_valor.text)!,
        aplicarAtuais: _aplicarAtuais,
      );
      if (!mounted) return;
      Navigator.of(context).pop(resultado);
    } on MensalidadeException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final assinaturas = widget.atual.assinaturas;
    final novo = centavosDoTexto(_valor.text);
    final acimaTetoPix =
        _aplicarAtuais && novo != null && novo > _tetoPixPadrao;

    return AlertDialog(
      title: const Text('Alterar valor da mensalidade'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valor atual: '
                  '${formatarCentavos(widget.atual.valorCentavos)} / mês',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valor,
                  enabled: !_enviando,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Novo valor mensal',
                    prefixText: 'R\$ ',
                    hintText: '250,00',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validar,
                  onFieldSubmitted: (_) => _confirmar(),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _aplicarAtuais,
                  onChanged: _enviando || assinaturas == 0
                      ? null
                      : (v) => setState(() => _aplicarAtuais = v ?? false),
                  title: Text(
                    assinaturas == 0
                        ? 'Nenhuma assinatura em vigor'
                        : assinaturas == 1
                        ? 'Aplicar também à assinatura atual'
                        : 'Aplicar também às $assinaturas assinaturas atuais',
                  ),
                  subtitle: const Text(
                    'Sem cobrança proporcional: o novo valor vale a partir da '
                    'próxima fatura. Desmarcado, só novas assinaturas pagam o '
                    'novo valor.',
                  ),
                ),
                if (acimaTetoPix) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: cores.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Quem paga por Pix Automático autorizou cobranças '
                          'de até R\$ 250,00. Acima disso, a cobrança Pix '
                          'dessas pessoas pode falhar até elas autorizarem '
                          'de novo pelo portal de pagamento.',
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(_erro!, style: TextStyle(color: cores.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _enviando ? null : _confirmar,
          icon: _enviando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Alterar no Stripe'),
        ),
      ],
    );
  }
}

class _ResumoMes extends StatelessWidget {
  const _ResumoMes({required this.resumo});

  final ResumoFinanceiro resumo;

  @override
  Widget build(BuildContext context) {
    final cores = CoresStatus.of(context);
    final itens = [
      (
        'Pagaram',
        '${resumo.pagaram} de ${resumo.total}',
        Icons.check_circle_outline,
        cores.sucesso,
      ),
      (
        'Não pagaram',
        '${resumo.naoPagaram}',
        Icons.pending_outlined,
        resumo.naoPagaram == 0 ? cores.neutro : cores.atencao,
      ),
      (
        'Recebido no mês',
        formatarCentavos(resumo.recebidoCentavos),
        Icons.payments_outlined,
        cores.informativo,
      ),
      (
        'Em aberto',
        formatarCentavos(resumo.emAbertoCentavos),
        Icons.account_balance_wallet_outlined,
        resumo.atrasados > 0 ? cores.erro : cores.neutro,
      ),
    ];

    return LayoutBuilder(
      builder: (context, limites) {
        final colunas = limites.maxWidth >= 900 ? 4 : 2;
        const espaco = 12.0;
        final largura = (limites.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final (titulo, valor, icone, cor) in itens)
              SizedBox(
                width: largura,
                child: _CartaoResumo(
                  titulo: titulo,
                  valor: valor,
                  icone: icone,
                  cor: cor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final CorStatus cor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return CartaoApp(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cor.fundo,
            child: Icon(icone, color: cor.cor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  valor,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _valor(LinhaFinanceira l) =>
    l.valorCentavos == null ? '—' : formatarCentavos(l.valorCentavos!);

String _dataOuTraco(DateTime? d) => d == null ? '—' : formatarData(d);

/// Tabela (tablet/desktop).
class _TabelaPassageiros extends StatelessWidget {
  const _TabelaPassageiros({required this.linhas});

  final List<LinhaFinanceira> linhas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    return CartaoApp(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, limites) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: limites.maxWidth),
            child: DataTable(
              headingTextStyle: tema.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              dataRowMinHeight: 56,
              dataRowMaxHeight: 68,
              columns: const [
                DataColumn(label: Text('Passageiro')),
                DataColumn(label: Text('Telefone')),
                DataColumn(label: Text('Assinatura')),
                DataColumn(label: Text('Valor'), numeric: true),
                DataColumn(label: Text('Vencimento')),
                DataColumn(label: Text('Pago em')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final l in linhas)
                  DataRow(
                    key: ValueKey(l.chave),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (l.instituicao != null)
                              Text(l.instituicao!, style: secundario),
                          ],
                        ),
                      ),
                      DataCell(Text(_formatarTelefone(l.telefone))),
                      DataCell(
                        l.perfilId == null
                            ? Text('—', style: secundario)
                            : ChipStatus.de(
                                statusAssinatura(l.statusAssinatura),
                              ),
                      ),
                      DataCell(Text(_valor(l))),
                      DataCell(Text(_dataOuTraco(l.vencimento))),
                      DataCell(Text(_dataOuTraco(l.pagoEm))),
                      DataCell(ChipStatus.de(l.situacao.info)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de cartões (celular): mesma informação da tabela, sem rolar de lado.
class _ListaPassageiros extends StatelessWidget {
  const _ListaPassageiros({required this.linhas});

  final List<LinhaFinanceira> linhas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final secundario = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        for (final l in linhas)
          Padding(
            key: ValueKey(l.chave),
            padding: const EdgeInsets.only(bottom: 8),
            child: CartaoApp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.nome,
                              style: tema.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (l.instituicao != null)
                              Text(l.instituicao!, style: secundario),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChipStatus.de(l.situacao.info),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('Valor: ${_valor(l)}', style: secundario),
                      Text(
                        'Vencimento: ${_dataOuTraco(l.vencimento)}',
                        style: secundario,
                      ),
                      if (l.pagoEm != null)
                        Text(
                          'Pago em: ${formatarData(l.pagoEm!)}',
                          style: secundario,
                        ),
                      if (l.telefone != null)
                        Text(_formatarTelefone(l.telefone), style: secundario),
                      if (l.perfilId != null)
                        Text(
                          'Assinatura: '
                          '${statusAssinatura(l.statusAssinatura).rotulo}',
                          style: secundario,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _formatarTelefone(String? telefone) {
  if (telefone == null) return '—';
  final d = telefone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return telefone;
}
