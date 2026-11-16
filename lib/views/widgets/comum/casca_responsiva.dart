import 'package:flutter/material.dart';

import '../../../tema/app_tema.dart';

/// Item de navegação usado pela [CascaResponsiva].
class DestinoCasca {
  const DestinoCasca({
    required this.icone,
    required this.iconeSelecionado,
    required this.rotulo,
  });

  final IconData icone;
  final IconData iconeSelecionado;
  final String rotulo;
}

/// Estrutura de navegação única do app.
///
/// - Largura >= [AppBreakpoints.desktop] (900 px): NavigationRail estendida à
///   esquerda + cabeçalho branco com o título da aba.
/// - Abaixo disso: AppBar no topo + NavigationBar embaixo. Com mais de
///   [maxDestinosBarra] destinos (painel do administrador), a barra de baixo
///   não comporta os itens: usa um menu lateral (gaveta) aberto pela AppBar.
///
/// O conteúdo de cada aba é decidido por quem usa, via [corpo]; a casca só
/// cuida da navegação. O índice selecionado fica no estado de quem chama.
class CascaResponsiva extends StatelessWidget {
  const CascaResponsiva({
    super.key,
    required this.destinos,
    required this.indiceSelecionado,
    required this.aoSelecionar,
    required this.corpo,
    this.titulo = 'FretApp',
    this.subtitulo,
    this.acoes = const [],
    this.rodapeLateral,
    this.botaoFlutuante,
  });

  final List<DestinoCasca> destinos;
  final int indiceSelecionado;
  final ValueChanged<int> aoSelecionar;

  /// Recebe `desktop` para o conteúdo ajustar espaçamentos se quiser.
  final Widget Function(BuildContext context, bool desktop) corpo;

  final String titulo;

  /// Texto pequeno abaixo do título na lateral (ex.: "Área do passageiro").
  final String? subtitulo;

  /// Ações da AppBar (celular) e do cabeçalho do conteúdo (desktop).
  final List<Widget> acoes;

  /// Widget no pé da NavigationRail (ex.: botão de sair).
  final Widget? rodapeLateral;

  final Widget? botaoFlutuante;

  /// Máximo de itens que cabem na NavigationBar do celular.
  static const maxDestinosBarra = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final desktop = AppBreakpoints.ehDesktop(limites.maxWidth);
        return desktop
            ? _desktop(context, limites.maxWidth)
            : _celular(context);
      },
    );
  }

  Widget _celular(BuildContext context) {
    final usarGaveta = destinos.length > maxDestinosBarra;
    return Scaffold(
      appBar: AppBar(
        title: Text(usarGaveta ? destinos[indiceSelecionado].rotulo : titulo),
        actions: acoes,
      ),
      drawer: usarGaveta ? _gaveta() : null,
      body: SafeArea(bottom: false, child: corpo(context, false)),
      floatingActionButton: botaoFlutuante,
      bottomNavigationBar: usarGaveta
          ? null
          : NavigationBar(
              selectedIndex: indiceSelecionado,
              onDestinationSelected: aoSelecionar,
              destinations: [
                for (final d in destinos)
                  NavigationDestination(
                    icon: Icon(d.icone),
                    selectedIcon: Icon(d.iconeSelecionado),
                    label: d.rotulo,
                  ),
              ],
            ),
    );
  }

  /// Menu lateral do celular quando há destinos demais para a barra inferior.
  Widget _gaveta() {
    return Builder(
      builder: (context) {
        final tema = Theme.of(context);
        final cores = tema.colorScheme;
        return NavigationDrawer(
          selectedIndex: indiceSelecionado,
          onDestinationSelected: (indice) {
            Scaffold.of(context).closeDrawer();
            aoSelecionar(indice);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus_filled,
                    size: 32,
                    color: cores.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitulo != null)
                          Text(
                            subtitulo!.toUpperCase(),
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: cores.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Divider(),
            ),
            for (final d in destinos)
              NavigationDrawerDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeSelecionado),
                label: Text(d.rotulo),
              ),
            if (rodapeLateral != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Divider(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: rodapeLateral,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _desktop(BuildContext context, double largura) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;

    return Scaffold(
      floatingActionButton: botaoFlutuante,
      body: Row(
        children: [
          NavigationRail(
            // Em janelas baixas (muitos destinos), cabeçalho e itens rolam;
            // o rodapé (sair) fica sempre visível embaixo.
            scrollable: true,
            leadingAtTop: false,
            trailingAtBottom: true,
            extended: true,
            minExtendedWidth: 232,
            labelType: NavigationRailLabelType.none,
            selectedIndex: indiceSelecionado,
            onDestinationSelected: aoSelecionar,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
              child: SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bus_filled,
                      size: 36,
                      color: cores.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!.toUpperCase(),
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: cores.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                  ],
                ),
              ),
            ),
            trailing: rodapeLateral == null
                ? null
                : SizedBox(
                    width: 232,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: rodapeLateral,
                        ),
                      ],
                    ),
                  ),
            destinations: [
              for (final d in destinos)
                NavigationRailDestination(
                  icon: Icon(d.icone),
                  selectedIcon: Icon(d.iconeSelecionado),
                  label: Text(d.rotulo),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabecalhoDesktop(
                  titulo: destinos[indiceSelecionado].rotulo,
                  acoes: acoes,
                ),
                Expanded(child: corpo(context, true)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa branca no topo do conteúdo (desktop), igual ao painel do passageiro.
class _CabecalhoDesktop extends StatelessWidget {
  const _CabecalhoDesktop({required this.titulo, required this.acoes});

  final String titulo;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surfaceContainerLowest,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: tema.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Semantics(
              header: true,
              child: Text(
                titulo,
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            ...acoes,
          ],
        ),
      ),
    );
  }
}
