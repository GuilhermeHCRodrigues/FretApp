part of 'motorista_view.dart';

/// Lista de embarque: passageiros que responderam a enquete de hoje.
class PassageirosViagemView extends StatefulWidget {
  const PassageirosViagemView({
    super.key,
    required this.modelo,
    this.desktop = false,
  });

  final MotoristaViewModel modelo;
  final bool desktop;

  @override
  State<PassageirosViagemView> createState() => _PassageirosViagemViewState();
}

class _PassageirosViagemViewState extends State<PassageirosViagemView> {
  late final _busca = TextEditingController(text: widget.modelo.busca);

  @override
  void didUpdateWidget(PassageirosViagemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final termo = widget.modelo.busca;
    if (_busca.text != termo) {
      _busca.value = TextEditingValue(
        text: termo,
        selection: TextSelection.collapsed(offset: termo.length),
      );
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.modelo;
    final passageiros = modelo.passageirosFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResumoEmbarque(modelo: modelo, desktop: widget.desktop),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busca,
                onChanged: modelo.pesquisar,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar por nome',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: modelo.busca.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close),
                          onPressed: () => modelo.pesquisar(''),
                        ),
                ),
              ),
            ),
            if (modelo.fontePassageiros != null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Atualizar lista da enquete',
                onPressed: modelo.carregando
                    ? null
                    : modelo.carregarPassageiros,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (modelo.carregando && modelo.totalPassageiros == 0)
          const EstadoCarregando(mensagem: 'Buscando a enquete de hoje…')
        else if (modelo.erroPassageiros != null)
          EstadoErro(
            mensagem: modelo.erroPassageiros,
            aoTentarDeNovo: modelo.carregarPassageiros,
          )
        else if (passageiros.isEmpty)
          Semantics(
            liveRegion: true,
            child: modelo.totalPassageiros == 0
                ? const EstadoVazio(
                    icone: Icons.how_to_vote_outlined,
                    titulo: 'Ninguém confirmou presença hoje',
                    mensagem:
                        'Os passageiros aparecem aqui quando respondem a '
                        'enquete do dia.',
                  )
                : const EstadoVazio(
                    icone: Icons.search_off,
                    titulo: 'Nenhum passageiro encontrado',
                  ),
          )
        else
          LayoutBuilder(
            builder: (context, limites) {
              const espaco = 12.0;
              final duasColunas = widget.desktop && limites.maxWidth >= 624;
              final largura = duasColunas
                  ? (limites.maxWidth - espaco) / 2
                  : limites.maxWidth;
              return Wrap(
                spacing: espaco,
                runSpacing: espaco,
                children: [
                  for (final passageiro in passageiros)
                    SizedBox(
                      key: ValueKey(passageiro.id),
                      width: largura,
                      child: _CartaoPassageiro(
                        passageiro: passageiro,
                        aoAlterar: () => modelo.definirEmbarque(
                          passageiro.id,
                          !passageiro.embarcou,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ResumoEmbarque extends StatelessWidget {
  const _ResumoEmbarque({required this.modelo, required this.desktop});
  final MotoristaViewModel modelo;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rota = Row(
      children: [
        Icon(Icons.route_outlined, color: tema.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${modelo.origem} '),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                TextSpan(text: ' ${modelo.destino}'),
              ],
            ),
            semanticsLabel: 'Rota de ${modelo.origem} para ${modelo.destino}',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.schedule_outlined,
          size: 18,
          color: tema.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(modelo.horarioSaida, style: tema.textTheme.labelLarge),
      ],
    );
    final contadores = _ContadoresEmbarque(modelo: modelo);
    return _CartaoPainel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: desktop
            ? Row(
                children: [
                  Expanded(child: rota),
                  const SizedBox(width: 32),
                  Expanded(child: contadores),
                ],
              )
            : Column(children: [rota, const Divider(height: 24), contadores]),
      ),
    );
  }
}

class _ContadoresEmbarque extends StatelessWidget {
  const _ContadoresEmbarque({required this.modelo});
  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) {
    final status = CoresStatus.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContadorEmbarque(
          'Total',
          modelo.totalPassageiros,
          Theme.of(context).colorScheme.primary,
        ),
        _ContadorEmbarque('Embarcados', modelo.embarcados, status.sucesso.cor),
        _ContadorEmbarque('Pendentes', modelo.pendentes, status.atencao.cor),
      ],
    );
  }
}

class _ContadorEmbarque extends StatelessWidget {
  const _ContadorEmbarque(this.rotulo, this.valor, this.cor);
  final String rotulo;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        container: true,
        label: '$rotulo: $valor',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              '$valor',
              style: texto.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            Text(rotulo, textAlign: TextAlign.center, style: texto.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _CartaoPassageiro extends StatelessWidget {
  const _CartaoPassageiro({required this.passageiro, required this.aoAlterar});
  final PassageiroViagem passageiro;
  final VoidCallback aoAlterar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final embarcou = passageiro.embarcou;
    final acao = embarcou ? 'Desfazer' : 'Confirmar';
    final rotuloAcao = '$acao embarque de ${passageiro.nome}';
    final textoAcao = Text(acao, semanticsLabel: rotuloAcao);
    final detalhe = [
      if (passageiro.trajeto != null) statusTrajeto(passageiro.trajeto).rotulo,
      if (passageiro.pontoEmbarque != null) passageiro.pontoEmbarque!,
    ].join(' · ');
    return _CartaoPainel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: tema.colorScheme.primaryContainer,
                foregroundColor: tema.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.person_outline),
              ),
              title: Text(
                passageiro.nome,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: detalhe.isEmpty ? null : Text(detalhe),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.start,
              spacing: 8,
              children: [
                embarcou
                    ? ChipStatus(
                        rotulo: 'Embarcou',
                        tom: TomStatus.sucesso,
                        icone: Icons.check_circle_outline,
                      )
                    : const ChipStatus(
                        rotulo: 'Pendente',
                        tom: TomStatus.atencao,
                        icone: Icons.schedule,
                      ),
                Tooltip(
                  message: rotuloAcao,
                  excludeFromSemantics: true,
                  child: embarcou
                      ? TextButton.icon(
                          onPressed: aoAlterar,
                          icon: const Icon(Icons.undo),
                          label: textoAcao,
                        )
                      : FilledButton.icon(
                          onPressed: aoAlterar,
                          icon: const Icon(Icons.check),
                          label: textoAcao,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
