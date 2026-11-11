part of 'motorista_view.dart';

class PassageirosViagemView extends StatefulWidget {
  const PassageirosViagemView({super.key, required this.modelo});

  final MotoristaViewModel modelo;

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
    final bordaBusca = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xffd6dfec)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Passageiros',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: _tinta,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ResumoEmbarque(modelo: modelo),
          const SizedBox(height: 16),
          TextField(
            controller: _busca,
            onChanged: modelo.pesquisar,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, color: _tinta),
            decoration: InputDecoration(
              hintText: 'Buscar por nome',
              hintStyle: const TextStyle(
                color: _secundaria,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: _azulEscuro),
              suffixIcon: modelo.busca.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => modelo.pesquisar(''),
                    ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              filled: true,
              fillColor: const Color(0xfff7f9fd),
              enabledBorder: bordaBusca,
              focusedBorder: bordaBusca.copyWith(
                borderSide: const BorderSide(color: _azul, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (passageiros.isEmpty)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  modelo.totalPassageiros == 0
                      ? 'Nenhum passageiro nesta viagem'
                      : 'Nenhum passageiro encontrado',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _secundaria, fontSize: 15),
                ),
              ),
            ),
          for (final passageiro in passageiros)
            _CartaoPassageiro(
              key: ValueKey(passageiro.id),
              passageiro: passageiro,
              aoAlterar: () =>
                  modelo.definirEmbarque(passageiro.id, !passageiro.embarcou),
            ),
        ],
      ),
    );
  }
}

class _ResumoEmbarque extends StatelessWidget {
  const _ResumoEmbarque({required this.modelo});

  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xfff1f6ff),
      border: Border.all(color: const Color(0xffd7e5fa)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 21, color: _azul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${modelo.origem} → ${modelo.destino}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _tinta,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule_rounded, size: 16, color: _azulEscuro),
              const SizedBox(width: 4),
              Text(
                modelo.horarioSaida,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _azulEscuro,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xffd7e5fa)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContadorEmbarque('Total', modelo.totalPassageiros, _azulEscuro),
              _ContadorEmbarque(
                'Embarcados',
                modelo.embarcados,
                const Color(0xff176d45),
              ),
              _ContadorEmbarque(
                'Pendentes',
                modelo.pendentes,
                const Color(0xff915509),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ContadorEmbarque extends StatelessWidget {
  const _ContadorEmbarque(this.rotulo, this.valor, this.cor);
  final String rotulo;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      container: true,
      label: '$rotulo: $valor',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _secundaria,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CartaoPassageiro extends StatelessWidget {
  const _CartaoPassageiro({
    super.key,
    required this.passageiro,
    required this.aoAlterar,
  });
  final PassageiroViagem passageiro;
  final VoidCallback aoAlterar;

  @override
  Widget build(BuildContext context) {
    final embarcou = passageiro.embarcou;
    final acao = embarcou ? 'Desfazer' : 'Confirmar';
    final corStatus = embarcou
        ? const Color(0xff176d45)
        : const Color(0xff915509);
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffdfe6f1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 9, 9, 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passageiro.nome,
                        style: const TextStyle(
                          fontSize: 16,
                          color: _tinta,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: _secundaria,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              passageiro.pontoEmbarque,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _secundaria,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: embarcou
                              ? const Color(0xffe5f5eb)
                              : const Color(0xfffff1d9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          embarcou ? 'Embarcou' : 'Pendente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corStatus,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: '$acao embarque de ${passageiro.nome}',
                  excludeFromSemantics: true,
                  child: TextButton.icon(
                    onPressed: aoAlterar,
                    icon: Icon(
                      embarcou ? Icons.undo_rounded : Icons.check_rounded,
                      size: 17,
                    ),
                    label: Text(
                      acao,
                      semanticsLabel: '$acao embarque de ${passageiro.nome}',
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: embarcou
                          ? const Color(0xffeff4fc)
                          : _azul,
                      foregroundColor: embarcou ? _azulEscuro : Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
