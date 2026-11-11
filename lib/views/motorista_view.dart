import 'package:flutter/material.dart';

import '../models/passageiro_viagem.dart';
import '../viewmodels/motorista_viewmodel.dart';
import 'widgets/ilustracao_onibus.dart';
import 'widgets/mapa_trajeto_demo.dart';

part 'passageiros_viagem_view.dart';

const _azul = Color(0xff075be5);
const _azulEscuro = Color(0xff093ba4);
const _tinta = Color(0xff111e48);
const _secundaria = Color(0xff414c67);
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
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        colorScheme: ColorScheme.fromSeed(seedColor: _azul),
        scaffoldBackgroundColor: Colors.white,
        dividerColor: const Color(0xffe1e7f1),
      ),
      child: ColoredBox(
        color: const Color(0xffeff2f8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Scaffold(
              body: SafeArea(
                bottom: false,
                child: ListenableBuilder(
                  listenable: _motorista,
                  builder: (context, _) => ListView(
                    key: PageStorageKey(_abas[_aba]),
                    padding: EdgeInsets.zero,
                    children: [
                      const _Cabecalho(),
                      Stack(
                        children: [
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 28,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_azulEscuro, Color(0xff0879f5)],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 11, 12, 24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(26),
                              ),
                            ),
                            child: switch (_aba) {
                              0 => _Inicio(modelo: _motorista),
                              1 => PassageirosViagemView(
                                key: ObjectKey(_motorista),
                                modelo: _motorista,
                              ),
                              _ => _AbaSecundaria(
                                aba: _aba,
                                modelo: _motorista,
                                onSair: widget.onSair,
                              ),
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: _MenuInferior(
                selecionada: _aba,
                aoSelecionar: (aba) => setState(() => _aba = aba),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _FundoCabecalho(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
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
              color: const Color(0xffb8d9ff),
            ),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FretApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Motorista',
                    style: TextStyle(
                      color: Color(0xffdceaff),
                      fontSize: 15,
                      height: 1.2,
                    ),
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
        ..shader = const LinearGradient(
          colors: [Color(0xff073993), Color(0xff0649b0)],
        ).createShader(area),
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
        ..shader = const LinearGradient(
          colors: [Color(0xff0868e7), Color(0xff0879f5)],
        ).createShader(area),
    );
  }

  @override
  bool shouldRepaint(_FundoCabecalho oldDelegate) => false;
}

class _Inicio extends StatelessWidget {
  const _Inicio({required this.modelo});
  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) {
    final emViagem = modelo.situacao == SituacaoViagem.emAndamento;
    final (iconePrincipal, textoPrincipal) = switch (modelo.situacao) {
      SituacaoViagem.aguardando => (Icons.play_arrow_rounded, 'Iniciar viagem'),
      SituacaoViagem.emAndamento => (
        Icons.directions_bus_rounded,
        'Viagem em andamento',
      ),
      SituacaoViagem.finalizada => (
        Icons.check_circle_outline,
        'Viagem finalizada',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _CartaoViagem(modelo: modelo),
        ),
        const SizedBox(height: 14),
        MapaTrajetoDemo(
          etapa: emViagem && modelo.etapaMapa == 0 ? -1 : modelo.etapaMapa,
        ),
        const SizedBox(height: 12),
        _CartaoGps(modelo: modelo),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: modelo.podeIniciar ? modelo.iniciarViagem : null,
          icon: Icon(iconePrincipal, size: 33),
          label: Text(textoPrincipal, textAlign: TextAlign.center),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: _azul,
            foregroundColor: Colors.white,
            disabledBackgroundColor: emViagem
                ? _azulEscuro
                : const Color(0xffe5e9f0),
            disabledForegroundColor: emViagem ? Colors.white : _secundaria,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Acao(
              'Estou saindo',
              Icons.login_rounded,
              modelo.podeSair ? modelo.registrarSaida : null,
            ),
            const SizedBox(width: 6),
            _Acao(
              'Cheguei ao ponto',
              Icons.location_on_outlined,
              modelo.podeChegar ? modelo.registrarChegada : null,
            ),
            const SizedBox(width: 6),
            _Acao(
              'Finalizar',
              Icons.sports_score_rounded,
              modelo.podeFinalizar ? modelo.finalizarViagem : null,
            ),
          ],
        ),
        if (modelo.ultimoAviso != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              modelo.ultimoAviso!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _secundaria),
            ),
          ),
        ],
      ],
    );
  }
}

class _CartaoViagem extends StatelessWidget {
  const _CartaoViagem({required this.modelo});
  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) {
    final titulo = switch (modelo.situacao) {
      SituacaoViagem.aguardando => 'Próxima viagem',
      SituacaoViagem.emAndamento => 'Viagem atual',
      SituacaoViagem.finalizada => 'Viagem encerrada',
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomCenter,
          colors: [Color(0xffc9e2ff), Color(0xfff5f9ff), Colors.white],
          stops: [0, .64, 1],
        ),
        border: Border.all(color: const Color(0xffe0e8f5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x201e3a89),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final artWidth = (box.maxWidth * .28)
                  .clamp(65.0, 118.0)
                  .toDouble();
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
                          decoration: const BoxDecoration(
                            color: Color(0xffdceafe),
                            borderRadius: BorderRadius.horizontal(
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
                                  style: const TextStyle(
                                    color: _tinta,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 9, 0, 11),
                          child: Semantics(
                            label:
                                'Rota de ${modelo.origem} para ${modelo.destino}',
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
                                  Text(modelo.origem, style: _textoRota),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _azulEscuro,
                                      size: 21,
                                    ),
                                  ),
                                  Text(modelo.destino, style: _textoRota),
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
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 11, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 95,
                  child: _DadoViagem(
                    Icons.schedule_rounded,
                    'Saída',
                    modelo.horarioSaida,
                  ),
                ),
                const _Divisoria(),
                const Expanded(
                  flex: 120,
                  child: _DadoViagem(
                    Icons.directions_bus_outlined,
                    'Veículo',
                    'Ônibus 12',
                  ),
                ),
                const _Divisoria(),
                Expanded(
                  flex: 99,
                  child: _DadoViagem(
                    Icons.people_outline_rounded,
                    modelo.totalPassageiros == 1 ? 'passageiro' : 'passageiros',
                    modelo.totalPassageiros.toString(),
                    valorPrimeiro: true,
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

const _textoRota = TextStyle(
  color: _tinta,
  fontSize: 19,
  fontWeight: FontWeight.w800,
);

class _Divisoria extends StatelessWidget {
  const _Divisoria();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: const Color(0xffd5deed),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _DadoViagem extends StatelessWidget {
  const _DadoViagem(
    this.icone,
    this.rotulo,
    this.valor, {
    this.valorPrimeiro = false,
  });
  final IconData icone;
  final String rotulo;
  final String valor;
  final bool valorPrimeiro;

  @override
  Widget build(BuildContext context) {
    final nome = Text(
      rotulo,
      style: const TextStyle(fontSize: 12, color: _secundaria, height: 1.15),
    );
    final numero = Text(
      valor,
      style: const TextStyle(
        fontSize: 17,
        color: _tinta,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icone, size: 22, color: _azulEscuro),
          const SizedBox(width: 6),
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
    final cor = ativo ? const Color(0xff12712a) : const Color(0xffa33b10);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ativo ? const Color(0xffeaf9ec) : const Color(0xfffff1e8),
        border: Border.all(
          color: ativo ? const Color(0xffade2b7) : const Color(0xffefc0a5),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ativo
                    ? const Color(0xffc5f2ce)
                    : const Color(0xffffdeca),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  ativo ? Icons.location_on : Icons.location_off,
                  color: cor,
                  size: 26,
                ),
              ),
            ),
            Container(
              height: 37,
              width: 1,
              color: ativo ? const Color(0xffa4d7af) : const Color(0xfff0bb9b),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ativo ? 'GPS ativado' : 'GPS desativado',
                    style: TextStyle(
                      fontSize: 17,
                      color: cor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Localização simulada',
                    style: TextStyle(fontSize: 13, color: _secundaria),
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
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: aoPressionar,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0xffd2e5ff),
        disabledBackgroundColor: const Color(0xffe4edfc),
        foregroundColor: _azulEscuro,
        disabledForegroundColor: const Color(0xff3d608f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 24),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MenuInferior extends StatelessWidget {
  const _MenuInferior({required this.selecionada, required this.aoSelecionar});
  final int selecionada;
  final ValueChanged<int> aoSelecionar;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xffe1e7f1))),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _abas.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selecionada,
                  child: Material(
                    color: i == selecionada
                        ? const Color(0xffdceafe)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => aoSelecionar(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              i == selecionada ? _iconesAtivos[i] : _icones[i],
                              size: 24,
                              color: i == selecionada ? _azul : _secundaria,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _abas[i],
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                  fontWeight: i == selecionada
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == selecionada
                                      ? _azulEscuro
                                      : _secundaria,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
              style: const TextStyle(
                fontSize: 23,
                color: _tinta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: const Color(0xffeff5ff),
            borderRadius: BorderRadius.circular(14),
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
