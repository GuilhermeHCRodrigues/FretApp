import 'package:flutter/material.dart';

import 'financeiro_view.dart';
import 'mensagens_view.dart';
import 'motoristas_view.dart';
import 'passageiros_view.dart';
import 'rotas_view.dart';
import 'veiculos_view.dart';
import 'viagens_view.dart';
import 'widgets/comum/cartao_app.dart';
import 'widgets/comum/casca_responsiva.dart';

/// Índices das abas do painel (ordem de [_destinos]).
abstract final class _Aba {
  static const visaoGeral = 0;
  static const veiculos = 1;
  static const motoristas = 2;
  static const passageiros = 3;
  static const rotas = 4;
  static const viagens = 5;
  static const financeiro = 6;
  static const mensagens = 7;
}

const _destinos = [
  DestinoCasca(
    icone: Icons.dashboard_outlined,
    iconeSelecionado: Icons.dashboard_rounded,
    rotulo: 'Visão geral',
  ),
  DestinoCasca(
    icone: Icons.directions_bus_outlined,
    iconeSelecionado: Icons.directions_bus_rounded,
    rotulo: 'Veículos',
  ),
  DestinoCasca(
    icone: Icons.badge_outlined,
    iconeSelecionado: Icons.badge_rounded,
    rotulo: 'Motoristas',
  ),
  DestinoCasca(
    icone: Icons.groups_outlined,
    iconeSelecionado: Icons.groups_rounded,
    rotulo: 'Passageiros',
  ),
  DestinoCasca(
    icone: Icons.route_outlined,
    iconeSelecionado: Icons.route_rounded,
    rotulo: 'Rotas',
  ),
  DestinoCasca(
    icone: Icons.location_on_outlined,
    iconeSelecionado: Icons.location_on_rounded,
    rotulo: 'Viagens',
  ),
  DestinoCasca(
    icone: Icons.account_balance_wallet_outlined,
    iconeSelecionado: Icons.account_balance_wallet_rounded,
    rotulo: 'Financeiro',
  ),
  DestinoCasca(
    icone: Icons.campaign_outlined,
    iconeSelecionado: Icons.campaign_rounded,
    rotulo: 'Mensagens',
  ),
];

/// Painel do administrador, com a mesma casca do motorista e do passageiro.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key, this.onSair});

  final Future<void> Function()? onSair;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _aba = _Aba.visaoGeral;

  void _selecionar(int indice) => setState(() => _aba = indice);

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return CascaResponsiva(
      destinos: _destinos,
      indiceSelecionado: _aba,
      aoSelecionar: _selecionar,
      subtitulo: 'Administração',
      rodapeLateral: widget.onSair == null
          ? null
          : ListTile(
              leading: CircleAvatar(
                backgroundColor: cores.primaryContainer,
                child: Icon(Icons.admin_panel_settings, color: cores.primary),
              ),
              title: const Text('Administrador'),
              subtitle: const Text('Sair da conta'),
              trailing: const Icon(Icons.logout, size: 20),
              onTap: widget.onSair,
            ),
      corpo: (context, desktop) => KeyedSubtree(
        // Cada aba recria o próprio estado ao ser aberta.
        key: ValueKey(_aba),
        child: _conteudo(desktop),
      ),
    );
  }

  Widget _conteudo(bool desktop) => switch (_aba) {
    _Aba.veiculos => const VeiculosView(),
    _Aba.motoristas => const MotoristasView(),
    _Aba.passageiros => const PassageirosView(),
    _Aba.rotas => const RotasView(),
    _Aba.viagens => const ViagensView(),
    _Aba.financeiro => const FinanceiroView(),
    _Aba.mensagens => const MensagensView(),
    _ => _VisaoGeral(desktop: desktop, abrir: _selecionar),
  };
}

class _Atalho {
  const _Atalho(this.aba, this.titulo, this.descricao, this.icone);

  final int aba;
  final String titulo;
  final String descricao;
  final IconData icone;
}

const _atalhos = [
  _Atalho(
    _Aba.motoristas,
    'Motoristas',
    'Cadastrar motoristas e criar o acesso ao app',
    Icons.badge_rounded,
  ),
  _Atalho(
    _Aba.passageiros,
    'Passageiros',
    'Cadastrar passageiros e criar o acesso ao app',
    Icons.groups_rounded,
  ),
  _Atalho(
    _Aba.veiculos,
    'Veículos',
    'Gerenciar a frota',
    Icons.directions_bus_rounded,
  ),
  _Atalho(
    _Aba.rotas,
    'Rotas',
    'Trajetos e pontos de parada',
    Icons.route_rounded,
  ),
  _Atalho(
    _Aba.viagens,
    'Viagens',
    'Agendar e acompanhar viagens',
    Icons.location_on_rounded,
  ),
  _Atalho(
    _Aba.financeiro,
    'Financeiro',
    'Mensalidades e pagamentos',
    Icons.account_balance_wallet_rounded,
  ),
  _Atalho(
    _Aba.mensagens,
    'Mensagens',
    'Comunicados para motoristas e passageiros',
    Icons.campaign_rounded,
  ),
];

class _VisaoGeral extends StatelessWidget {
  const _VisaoGeral({required this.desktop, required this.abrir});

  final bool desktop;
  final ValueChanged<int> abrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;

    return ListView(
      padding: desktop
          ? const EdgeInsets.all(24)
          : const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        CartaoApp(
          cor: cores.primaryContainer,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 40, color: cores.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bem-vindo ao painel do FretApp',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cores.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cadastre motoristas e passageiros e crie o login '
                      'deles. Ao entrar, cada um vê a tela do seu perfil.',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: cores.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Acesso rápido',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, limites) {
            final colunas = switch (limites.maxWidth) {
              < 560 => 1,
              < 960 => 2,
              _ => 3,
            };
            const espaco = 12.0;
            final largura =
                (limites.maxWidth - espaco * (colunas - 1)) / colunas;
            return Wrap(
              spacing: espaco,
              runSpacing: espaco,
              children: [
                for (final atalho in _atalhos)
                  SizedBox(
                    width: largura,
                    child: _CartaoAtalho(
                      atalho: atalho,
                      aoTocar: () => abrir(atalho.aba),
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

class _CartaoAtalho extends StatelessWidget {
  const _CartaoAtalho({required this.atalho, required this.aoTocar});

  final _Atalho atalho;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return CartaoApp(
      onTap: aoTocar,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cores.primaryContainer,
            child: Icon(atalho.icone, color: cores.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atalho.titulo,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  atalho.descricao,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cores.onSurfaceVariant),
        ],
      ),
    );
  }
}
