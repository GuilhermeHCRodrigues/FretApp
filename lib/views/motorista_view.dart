import 'package:flutter/material.dart';

import 'mensagens_inbox_view.dart';

import '../models/passageiro_viagem.dart';
import '../viewmodels/motorista_viewmodel.dart';
import 'widgets/ilustracao_onibus.dart';
import 'widgets/mapa_trajeto_demo.dart';

part 'passageiros_viagem_view.dart';

// Cores de identidade usadas também no painel do passageiro.
const _azul = Color(0xff1d4ed8);
const _azulEscuro = Color(0xff172554);
const _azulClaro = Color(0xffdbeafe);
const _fundo = Color(0xfff5f7fb);
const _borda = Color(0xffe2e8f0);
const _abas = ['Início', 'Passageiros', 'Avisos', 'Perfil'];
const _icones = [
  Icons.home_outlined,
  Icons.groups_outlined,
  Icons.notifications_none_rounded,
  Icons.person_outline_rounded,
];
const _iconesAtivos = [
  Icons.home_rounded,
  Icons.groups_rounded,
  Icons.notifications_rounded,
  Icons.person_rounded,
];

class MotoristaView extends StatefulWidget {
  const MotoristaView({super.key, this.modelo, this.onSair});

  /// Permite que a rota forneça o modelo da viagem atribuída ao motorista.
  final MotoristaViewModel? modelo;
  final Future<void> Function()? onSair;

  @override
  State<MotoristaView> createState() => _MotoristaViewState();
}

class _MotoristaViewState extends State<MotoristaView> {
  MotoristaViewModel? _demo;
  MotoristaViewModel get _motorista =>
      widget.modelo ?? (_demo ??= MotoristaViewModel());
  int _aba = 0;

  @override
  void dispose() {
    _demo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _fundo,
      child: LayoutBuilder(
        builder: (context, limites) {
          final largura = limites.maxWidth;
          final desktop = largura >= 1024;
          final larguraMaxima = switch (largura) {
            < 600 => largura,
            < 1024 => 720.0,
            _ => 1680.0,
          };
          final margemHorizontal = switch (largura) {
            < 600 => 0.0,
            < 1024 => 24.0,
            _ => 16.0,
          };
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: margemHorizontal),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: larguraMaxima),
                child: _painel(desktop, expandirMenu: largura >= 1200),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _painel(bool desktop, {required bool expandirMenu}) => Scaffold(
    backgroundColor: _fundo,
    body: SafeArea(
      bottom: desktop,
      child: Row(
        children: [
          if (desktop) ...[
            _navegacaoLateral(expandida: expandirMenu),
            const VerticalDivider(width: 1, color: _borda),
          ],
          Expanded(
            key: const ValueKey('conteudo-motorista'),
            child: ListenableBuilder(
              listenable: _motorista,
              builder: (context, _) => ListView(
                key: PageStorageKey(_abas[_aba]),
                padding: EdgeInsets.zero,
                children: [
                  const _Cabecalho(),
                  Padding(
                    padding: desktop
                        ? const EdgeInsets.all(24)
                        : const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: _conteudo(desktop),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: desktop
        ? null
        : NavigationBar(
            height: 68,
            backgroundColor: Colors.white,
            indicatorColor: _azulClaro,
            selectedIndex: _aba,
            onDestinationSelected: _selecionar,
            destinations: [
              for (int i = 0; i < _abas.length; i++)
                NavigationDestination(
                  icon: Icon(_icones[i]),
                  selectedIcon: Icon(_iconesAtivos[i], color: _azul),
                  label: _abas[i],
                ),
            ],
          ),
  );

  void _selecionar(int indice) => setState(() => _aba = indice);

  Widget _navegacaoLateral({required bool expandida}) {
    final texto = Theme.of(context).textTheme;
    final rotulo = expandida ? texto.titleSmall : texto.labelLarge;
    return NavigationRail(
      extended: expandida,
      minWidth: expandida ? 64 : 108,
      minExtendedWidth: 172,
      scrollable: true,
      backgroundColor: Colors.white,
      indicatorColor: _azulClaro,
      labelType: expandida
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedLabelTextStyle: rotulo?.copyWith(
        color: _azulEscuro,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: rotulo?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      selectedIndex: _aba,
      onDestinationSelected: _selecionar,
      destinations: [
        for (int i = 0; i < _abas.length; i++)
          NavigationRailDestination(
            padding: const EdgeInsets.symmetric(vertical: 6),
            icon: Icon(_icones[i], size: 26),
            selectedIcon: Icon(_iconesAtivos[i], size: 26, color: _azul),
            label: Text(_abas[i]),
          ),
      ],
    );
  }

  Widget _conteudo(bool desktop) {
    if (_aba == 0) {
      return _Inicio(
        modelo: _motorista,
        desktop: desktop,
        abrirPassageiros: () => _selecionar(1),
      );
    }
    if (_aba == 1) {
      return PassageirosViagemView(
        key: ObjectKey(_motorista),
        modelo: _motorista,
        desktop: desktop,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _AbaSecundaria(
          aba: _aba,
          modelo: _motorista,
          onSair: widget.onSair,
        ),
      ),
    );
  }
}

class _CartaoPainel extends StatelessWidget {
  const _CartaoPainel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card.outlined(
    color: Colors.white,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _borda),
    ),
    child: child,
  );
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return CustomPaint(
      painter: const _FundoCabecalho(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            const Icon(
              Icons.directions_bus_filled_rounded,
              size: 42,
              color: Colors.white,
            ),
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: _azulClaro,
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FretApp',
                    style: texto.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Motorista',
                    style: texto.bodyMedium?.copyWith(color: _azulClaro),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundoCabecalho extends CustomPainter {
  const _FundoCabecalho();

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(colors: [_azulEscuro, _azul])
            .createShader(area),
    );
    final onda = Path()
      ..moveTo(size.width * .48, size.height)
      ..cubicTo(
        size.width * .72,
        size.height * .88,
        size.width * .76,
        size.height * .27,
        size.width,
        size.height * .33,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      onda,
      Paint()
        ..shader = const LinearGradient(colors: [_azul, Color(0xff3b82f6)])
            .createShader(area),
    );
  }

  @override
  bool shouldRepaint(_FundoCabecalho oldDelegate) => false;
}

class _Inicio extends StatelessWidget {
  const _Inicio({
    required this.modelo,
    required this.desktop,
    required this.abrirPassageiros,
  });
  final MotoristaViewModel modelo;
  final bool desktop;
  final VoidCallback abrirPassageiros;

  @override
  Widget build(BuildContext context) {
    final emViagem = modelo.situacao == SituacaoViagem.emAndamento;
    final mapa = LayoutBuilder(
      builder: (context, limites) {
        final teto = (MediaQuery.sizeOf(context).height * .56).clamp(
          280.0,
          560.0,
        );
        return MapaTrajetoDemo(
          etapa: emViagem && modelo.etapaMapa == 0 ? -1 : modelo.etapaMapa,
          altura: desktop
              ? (limites.maxWidth / MapaTrajetoDemo.proporcaoOriginal).clamp(
                  0.0,
                  teto,
                )
              : null,
        );
      },
    );
    final controles = _ControlesViagem(modelo: modelo, desktop: desktop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: desktop ? 0 : 2),
          child: _CartaoViagem(modelo: modelo, desktop: desktop),
        ),
        SizedBox(height: desktop ? 20 : 14),
        Flex(
          direction: desktop ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: desktop
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: desktop ? 2 : 0, child: mapa),
            SizedBox(width: desktop ? 24 : 0, height: desktop ? 0 : 12),
            Expanded(
              flex: desktop ? 1 : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  controles,
                  if (desktop) ...[
                    const SizedBox(height: 12),
                    _ResumoPassageiros(
                      modelo: modelo,
                      abrirPassageiros: abrirPassageiros,
                    ),
                    const SizedBox(height: 12),
                    _CartaoPainel(
                      child: ListTile(
                        leading: const Icon(
                          Icons.notifications_none_rounded,
                          color: _azul,
                        ),
                        title: const Text('Último aviso'),
                        subtitle: Semantics(
                          liveRegion: true,
                          child: Text(
                            modelo.ultimoAviso ?? 'Nenhum aviso registrado.',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResumoPassageiros extends StatelessWidget {
  const _ResumoPassageiros({
    required this.modelo,
    required this.abrirPassageiros,
  });
  final MotoristaViewModel modelo;
  final VoidCallback abrirPassageiros;

  @override
  Widget build(BuildContext context) => _CartaoPainel(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumo dos passageiros',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: _azulEscuro, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ContadoresEmbarque(modelo: modelo),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: abrirPassageiros,
              label: const Text('Ver passageiros'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ControlesViagem extends StatelessWidget {
  const _ControlesViagem({required this.modelo, required this.desktop});
  final MotoristaViewModel modelo;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final emViagem = modelo.situacao == SituacaoViagem.emAndamento;
    final (
      iconePrincipal,
      textoPrincipal,
      acaoPrincipal,
    ) = switch (modelo.situacao) {
      SituacaoViagem.aguardando => (
        Icons.play_arrow_rounded,
        'Iniciar viagem',
        modelo.podeIniciar ? modelo.iniciarViagem : null,
      ),
      SituacaoViagem.emAndamento => (
        Icons.directions_bus_rounded,
        'Viagem em andamento',
        null,
      ),
      SituacaoViagem.finalizada => (
        Icons.replay_rounded,
        'Nova viagem',
        modelo.podeReiniciarDemonstracao ? modelo.reiniciarDemonstracao : null,
      ),
    };
    final acoes = [
      _Acao(
        'Estou saindo',
        Icons.login_rounded,
        modelo.podeSair ? modelo.registrarSaida : null,
      ),
      _Acao(
        'Cheguei ao ponto',
        Icons.location_on_outlined,
        modelo.podeChegar ? modelo.registrarChegada : null,
      ),
      _Acao(
        'Finalizar',
        Icons.sports_score_rounded,
        modelo.podeFinalizar ? modelo.finalizarViagem : null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoGps(modelo: modelo),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: acaoPrincipal,
          icon: Icon(iconePrincipal),
          label: Text(textoPrincipal, textAlign: TextAlign.center),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: _azul,
            foregroundColor: Colors.white,
            disabledBackgroundColor: emViagem ? _azulClaro : null,
            disabledForegroundColor: emViagem ? _azulEscuro : null,
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        if (desktop)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: acoes,
          )
        else
          Row(
            spacing: 6,
            children: [for (final acao in acoes) Expanded(child: acao)],
          ),
        if (!desktop && modelo.ultimoAviso != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              modelo.ultimoAviso!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _CartaoViagem extends StatelessWidget {
  const _CartaoViagem({required this.modelo, required this.desktop});
  final MotoristaViewModel modelo;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textoRota = tema.textTheme.titleLarge?.copyWith(
      color: _azulEscuro,
      fontWeight: FontWeight.bold,
    );
    final titulo = switch (modelo.situacao) {
      SituacaoViagem.aguardando => 'Próxima viagem',
      SituacaoViagem.emAndamento => 'Viagem atual',
      SituacaoViagem.finalizada => 'Viagem encerrada',
    };
    final rota = LayoutBuilder(
      builder: (context, box) {
        final artWidth = desktop
            ? (box.maxWidth * .22).clamp(54.0, 96.0)
            : (box.maxWidth * .28).clamp(65.0, 118.0);
        return Stack(
          children: [
            Positioned(
              right: 2,
              top: 3,
              bottom: 0,
              width: artWidth,
              child: const ExcludeSemantics(child: IlustracaoOnibus()),
            ),
            Padding(
              padding: EdgeInsets.only(right: artWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _azulClaro,
                      borderRadius: desktop
                          ? BorderRadius.circular(14)
                          : const BorderRadius.horizontal(
                              right: Radius.circular(14),
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 21,
                          color: _azul,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            titulo,
                            style: tema.textTheme.titleSmall?.copyWith(
                              color: _azulEscuro,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: desktop
                        ? const EdgeInsets.only(top: 8)
                        : const EdgeInsets.fromLTRB(12, 9, 0, 11),
                    child: Semantics(
                      label: 'Rota de ${modelo.origem} para ${modelo.destino}',
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: _azul,
                              size: 23,
                            ),
                            const SizedBox(width: 7),
                            Text(modelo.origem, style: textoRota),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: _azulEscuro,
                                size: 21,
                              ),
                            ),
                            Text(modelo.destino, style: textoRota),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    final dados = Padding(
      padding: desktop
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 10, 11, 12),
      child: Row(
        children: [
          Expanded(
            flex: desktop ? 1 : 95,
            child: _DadoViagem(
              Icons.schedule_rounded,
              'Saída',
              modelo.horarioSaida,
              desktop: desktop,
            ),
          ),
          const _Divisoria(),
          Expanded(
            flex: desktop ? 1 : 120,
            child: _DadoViagem(
              Icons.directions_bus_outlined,
              'Veículo',
              'Ônibus 12',
              desktop: desktop,
            ),
          ),
          const _Divisoria(),
          Expanded(
            flex: desktop ? 1 : 99,
            child: _DadoViagem(
              Icons.people_outline_rounded,
              desktop
                  ? 'Passageiros'
                  : modelo.totalPassageiros == 1
                  ? 'passageiro'
                  : 'passageiros',
              modelo.totalPassageiros.toString(),
              valorPrimeiro: !desktop,
              desktop: desktop,
            ),
          ),
        ],
      ),
    );
    return _CartaoPainel(
      child: desktop
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 4, child: rota),
                  const _Divisoria(),
                  Expanded(flex: 6, child: dados),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rota,
                const Divider(height: 1, indent: 14, endIndent: 14),
                dados,
              ],
            ),
    );
  }
}

class _Divisoria extends StatelessWidget {
  const _Divisoria();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: _borda,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _DadoViagem extends StatelessWidget {
  const _DadoViagem(
    this.icone,
    this.rotulo,
    this.valor, {
    required this.desktop,
    this.valorPrimeiro = false,
  });
  final IconData icone;
  final String rotulo;
  final String valor;
  final bool valorPrimeiro;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nome = Text(
      rotulo,
      style: (desktop ? tema.textTheme.labelLarge : tema.textTheme.bodySmall)
          ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
    );
    final numero = Text(
      valor,
      style: (desktop ? tema.textTheme.titleLarge : tema.textTheme.titleMedium)
          ?.copyWith(color: _azulEscuro, fontWeight: FontWeight.w700),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: desktop ? Alignment.center : Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icone, size: 22, color: _azul),
          SizedBox(width: desktop ? 10 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: valorPrimeiro ? [numero, nome] : [nome, numero],
          ),
        ],
      ),
    );
  }
}

class _CartaoGps extends StatelessWidget {
  const _CartaoGps({required this.modelo});
  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) {
    final ativo = modelo.gpsAtivado;
    final cor = ativo ? Colors.green.shade800 : Colors.orange.shade900;
    final tema = Theme.of(context);
    return _CartaoPainel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cor.withValues(alpha: .10),
              child: Icon(
                ativo ? Icons.location_on : Icons.location_off,
                color: cor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ativo ? 'GPS ativado' : 'GPS desativado',
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: cor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Localização simulada',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Simular GPS',
              child: Switch(
                value: ativo,
                onChanged: modelo.definirGps,
                activeTrackColor: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao(this.texto, this.icone, this.aoPressionar);
  final String texto;
  final IconData icone;
  final VoidCallback? aoPressionar;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: aoPressionar,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      minimumSize: const Size.fromHeight(48),
      foregroundColor: _azul,
      disabledForegroundColor: Theme.of(context).colorScheme.onSurfaceVariant
          .withValues(alpha: .75),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, size: 20),
        const SizedBox(width: 4),
        Flexible(child: Text(texto, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class _AbaSecundaria extends StatelessWidget {
  const _AbaSecundaria({
    required this.aba,
    required this.modelo,
    required this.onSair,
  });
  final int aba;
  final MotoristaViewModel modelo;
  final Future<void> Function()? onSair;

  @override
  Widget build(BuildContext context) {
    if (aba == 2) return const MensagensInboxView();
    final (titulo, texto) = switch (aba) {
      2 => (
        modelo.ultimoAviso ?? 'Nenhum aviso',
        'Atividade local da viagem demonstrativa',
      ),
      _ => ('Motorista', 'Perfil de demonstração do FretApp'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              _abas[aba],
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: _azulEscuro, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          _CartaoPainel(
            child: ListTile(
              leading: Icon(_icones[aba], color: _azul),
              title: Text(titulo),
              subtitle: Text(texto),
            ),
          ),
          if (aba == 3 && onSair != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSair,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ],
        ],
      ),
    );
  }
}
