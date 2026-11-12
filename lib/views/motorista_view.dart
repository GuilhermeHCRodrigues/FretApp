import 'package:flutter/material.dart';

import '../models/passageiro_viagem.dart';
import '../services/motorista_servico.dart' as servico;
import '../tema/cores_status.dart';
import '../viewmodels/motorista_viewmodel.dart';
import 'widgets/comum/casca_responsiva.dart';
import 'widgets/comum/chip_status.dart';
import 'widgets/comum/estados.dart';
import 'widgets/ilustracao_onibus.dart';
import 'widgets/mapa_motorista.dart';

part 'passageiros_viagem_view.dart';

const _destinos = [
  DestinoCasca(
    icone: Icons.home_outlined,
    iconeSelecionado: Icons.home_rounded,
    rotulo: 'Início',
  ),
  DestinoCasca(
    icone: Icons.groups_outlined,
    iconeSelecionado: Icons.groups_rounded,
    rotulo: 'Passageiros',
  ),
  DestinoCasca(
    icone: Icons.notifications_none_rounded,
    iconeSelecionado: Icons.notifications_rounded,
    rotulo: 'Avisos',
  ),
  DestinoCasca(
    icone: Icons.person_outline_rounded,
    iconeSelecionado: Icons.person_rounded,
    rotulo: 'Perfil',
  ),
];

class MotoristaView extends StatefulWidget {
  const MotoristaView({super.key, this.modelo, this.onSair});

  /// Permite que a rota (ou um teste) forneça o modelo da viagem.
  final MotoristaViewModel? modelo;
  final Future<void> Function()? onSair;

  @override
  State<MotoristaView> createState() => _MotoristaViewState();
}

class _MotoristaViewState extends State<MotoristaView> {
  MotoristaViewModel? _proprio;
  MotoristaViewModel get _motorista =>
      widget.modelo ??
      (_proprio ??= MotoristaViewModel(
        fontePassageiros: servico.buscarPassageirosDaEnquete,
        solicitarLocalizacao: servico.solicitarLocalizacao,
        acompanharLocalizacao: servico.acompanharLocalizacao,
        publicarPosicao: servico.publicarPosicao,
        fonteViagem: servico.buscarViagemDoDia,
        atualizarStatus: servico.atualizarStatusViagem,
      ));
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    _motorista
      ..carregarViagem()
      ..carregarPassageiros();
  }

  @override
  void dispose() {
    _proprio?.dispose();
    super.dispose();
  }

  void _selecionar(int indice) => setState(() => _aba = indice);

  @override
  Widget build(BuildContext context) {
    return CascaResponsiva(
      destinos: _destinos,
      indiceSelecionado: _aba,
      aoSelecionar: _selecionar,
      subtitulo: 'Área do motorista',
      rodapeLateral: widget.onSair == null
          ? null
          : ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text('Motorista'),
              subtitle: const Text('Sair da conta'),
              trailing: const Icon(Icons.logout, size: 20),
              onTap: widget.onSair,
            ),
      corpo: (context, desktop) => ListenableBuilder(
        listenable: _motorista,
        builder: (context, _) => ListView(
          key: PageStorageKey(_destinos[_aba].rotulo),
          padding: desktop
              ? const EdgeInsets.all(24)
              : const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [_conteudo(desktop)],
        ),
      ),
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

/// Cartão branco com borda, vindo do `cardTheme`.
class _CartaoPainel extends StatelessWidget {
  const _CartaoPainel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(child: child);
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
    final mapa = LayoutBuilder(
      builder: (context, limites) {
        final teto = (MediaQuery.sizeOf(context).height * .6).clamp(
          320.0,
          620.0,
        );
        return MapaMotorista(
          posicao: modelo.posicao,
          rastro: modelo.rastro,
          trajeto: modelo.viagem?.trajeto ?? const [],
          pontos: modelo.viagem?.pontos ?? const [],
          aguardandoGps: modelo.localizacao == EstadoLocalizacao.permitida ||
              modelo.localizacao == EstadoLocalizacao.solicitando,
          aoCompartilhar: modelo.compartilharLocalizacao,
          altura: desktop
              ? (limites.maxWidth * .62).clamp(320.0, teto)
              : 360,
        );
      },
    );
    final controles = _ControlesViagem(modelo: modelo, desktop: desktop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (modelo.carregandoViagem && modelo.viagem == null)
          const _CartaoPainel(
            child: EstadoCarregando(mensagem: 'Buscando a viagem de hoje…'),
          )
        else if (modelo.erroViagem != null)
          _CartaoPainel(
            child: EstadoErro(
              mensagem: modelo.erroViagem,
              aoTentarDeNovo: modelo.carregarViagem,
            ),
          )
        else if (modelo.semViagem)
          const _CartaoPainel(
            child: EstadoVazio(
              icone: Icons.event_busy_outlined,
              titulo: 'Nenhuma viagem programada para hoje',
              mensagem:
                  'Quando o administrador programar uma viagem para você, '
                  'ela aparece aqui.',
            ),
          )
        else
          _CartaoViagem(modelo: modelo, desktop: desktop),
        SizedBox(height: desktop ? 24 : 12),
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
                        leading: Icon(
                          Icons.notifications_none_rounded,
                          color: Theme.of(context).colorScheme.primary,
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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (modelo.carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else
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
    final cores = Theme.of(context).colorScheme;
    final solicitando =
        modelo.localizacao == EstadoLocalizacao.solicitando;

    final (Widget icone, String texto, VoidCallback? acao) = switch (modelo
        .situacao) {
      SituacaoViagem.aguardando when solicitando => (
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Aguardando localização…',
        null,
      ),
      SituacaoViagem.aguardando => (
        const Icon(Icons.play_arrow_rounded),
        'Iniciar viagem',
        modelo.podeIniciar ? modelo.iniciarViagem : null,
      ),
      SituacaoViagem.emAndamento => (
        const Icon(Icons.directions_bus_rounded),
        'Viagem em andamento',
        null,
      ),
      SituacaoViagem.finalizada => (
        const Icon(Icons.replay_rounded),
        'Nova viagem',
        modelo.novaViagem,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoLocalizacao(modelo: modelo),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: acao,
          icon: icone,
          label: Text(texto, textAlign: TextAlign.center),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            // Em andamento o botão fica "travado" em azul-claro, não cinza.
            disabledBackgroundColor:
                modelo.situacao == SituacaoViagem.emAndamento
                ? cores.primaryContainer
                : null,
            disabledForegroundColor:
                modelo.situacao == SituacaoViagem.emAndamento
                ? cores.onPrimaryContainer
                : null,
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        _Acao(
          'Finalizar viagem',
          Icons.sports_score_rounded,
          modelo.podeFinalizar ? modelo.finalizarViagem : null,
        ),
        if (!desktop && modelo.ultimoAviso != null) ...[
          const SizedBox(height: 12),
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
    final cores = tema.colorScheme;
    final textoRota = tema.textTheme.titleLarge?.copyWith(
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
              top: 4,
              bottom: 0,
              width: artWidth,
              child: const ExcludeSemantics(child: IlustracaoOnibus()),
            ),
            Padding(
              padding: EdgeInsets.only(right: artWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cores.primaryContainer,
                      borderRadius: desktop
                          ? BorderRadius.circular(12)
                          : const BorderRadius.horizontal(
                              right: Radius.circular(12),
                            ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: cores.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              titulo,
                              style: tema.textTheme.titleSmall?.copyWith(
                                color: cores.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: desktop
                        ? const EdgeInsets.only(top: 8)
                        : const EdgeInsets.fromLTRB(12, 8, 0, 12),
                    child: Semantics(
                      label: 'Rota de ${modelo.origem} para ${modelo.destino}',
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: cores.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(modelo.origem, style: textoRota),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
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
          : const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              modelo.veiculo,
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
              modelo.carregando ? '…' : modelo.totalPassageiros.toString(),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                const Divider(height: 1, indent: 12, endIndent: 12),
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
    color: Theme.of(context).colorScheme.outlineVariant,
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
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: desktop ? Alignment.center : Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icone, size: 22, color: tema.colorScheme.primary),
          SizedBox(width: desktop ? 12 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: valorPrimeiro ? [numero, nome] : [nome, numero],
          ),
        ],
      ),
    );
  }
}

/// Mostra se o motorista já compartilhou a localização.
/// A permissão é pedida ao tocar em "Iniciar viagem".
class _CartaoLocalizacao extends StatelessWidget {
  const _CartaoLocalizacao({required this.modelo});
  final MotoristaViewModel modelo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (tom, icone, titulo, detalhe) = switch (modelo.localizacao) {
      EstadoLocalizacao.naoSolicitada => (
        TomStatus.neutro,
        Icons.location_searching,
        'Localização',
        'Será solicitada ao iniciar a viagem',
      ),
      EstadoLocalizacao.solicitando => (
        TomStatus.atencao,
        Icons.location_searching,
        'Aguardando permissão',
        'Confirme o compartilhamento no aviso do navegador',
      ),
      EstadoLocalizacao.permitida => (
        TomStatus.sucesso,
        Icons.location_on,
        'Localização compartilhada',
        'GPS ativo nesta viagem',
      ),
      EstadoLocalizacao.negada => (
        TomStatus.erro,
        Icons.location_off,
        'Localização não permitida',
        'Libere o acesso à localização e toque em Iniciar viagem',
      ),
    };
    final cores = CoresStatus.of(context).de(tom);
    return _CartaoPainel(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cores.fundo,
              child: Icon(icone, color: cores.cor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: tema.textTheme.titleMedium?.copyWith(
                        color: cores.cor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      detalhe,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
    final destino = _destinos[aba];
    final (titulo, texto) = switch (aba) {
      2 => (
        modelo.ultimoAviso ?? 'Nenhum aviso',
        'Atividade da viagem de hoje',
      ),
      _ => ('Motorista', 'Seus dados de perfil aparecerão aqui'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoPainel(
          child: ListTile(
            leading: Icon(
              destino.icone,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(titulo),
            subtitle: Text(texto),
          ),
        ),
        if (aba == 3 && onSair != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onSair,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ],
      ],
    );
  }
}
