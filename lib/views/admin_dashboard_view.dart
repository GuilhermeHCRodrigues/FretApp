import 'package:flutter/material.dart';

import 'veiculos_view.dart';
import 'motoristas_view.dart';
import 'passageiros_view.dart';
import 'rotas_view.dart';
import 'viagens_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int paginaSelecionada = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuExpandido = constraints.maxWidth >= 850;

        return Row(
          children: [
            NavigationRail(
              extended: menuExpandido,
              minWidth: 72,
              minExtendedWidth: 220,
              labelType: menuExpandido
                  ? null
                  : NavigationRailLabelType.selected,

              selectedIndex: paginaSelecionada,

              onDestinationSelected: (index) {
                setState(() {
                  paginaSelecionada = index;
                });
              },

              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus, size: 32),
                    if (menuExpandido) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'FretApp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'ADMINISTRAÇÃO',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),

              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Visão geral'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.directions_bus_outlined),
                  selectedIcon: Icon(Icons.directions_bus),
                  label: Text('Veículos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Motoristas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Passageiros'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route),
                  label: Text('Rotas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: Text('Viagens'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Financeiro'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.message_outlined),
                  selectedIcon: Icon(Icons.message),
                  label: Text('Mensagens'),
                ),
              ],
            ),

            const VerticalDivider(width: 1, thickness: 1),

            Expanded(child: construirConteudo()),
          ],
        );
      },
    );
  }

  Widget construirConteudo() {
    switch (paginaSelecionada) {
      case 0:
        return construirVisaoGeral();

      case 1:
        return VeiculosView(
          onVoltar: () {
            setState(() {
              paginaSelecionada = 0;
            });
          },
        );

      case 2:
        return MotoristasView(
          onVoltar: () {
            setState(() {
              paginaSelecionada = 0;
            });
          },
        );

      case 3:
        return PassageirosView(
          onVoltar: () {
            setState(() {
              paginaSelecionada = 0;
            });
          },
        );

      case 4:
        return RotasView(
          onVoltar: () {
            setState(() {
              paginaSelecionada = 0;
            });
          },
        );

      case 5:
        return ViagensView(
          onVoltar: () {
            setState(() {
              paginaSelecionada = 0;
            });
          },
        );

      case 6:
        return paginaEmConstrucao(
          'Financeiro',
          Icons.account_balance_wallet,
          'Mensalidades e pagamentos.',
        );

      case 7:
        return paginaEmConstrucao(
          'Mensagens',
          Icons.message,
          'Comunicados e avisos aos usuários.',
        );

      default:
        return construirVisaoGeral();
    }
  }

  Widget construirVisaoGeral() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Visão geral', style: Theme.of(context).textTheme.headlineMedium),

        const SizedBox(height: 8),

        const Text('Bem-vindo ao painel administrativo do FretApp.'),

        const SizedBox(height: 24),

        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Painel administrativo'),
            subtitle: Text(
              'Utilize o menu lateral para gerenciar '
              'os recursos do aplicativo.',
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text('Acesso rápido', style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            atalho('Veículos', 'Gerenciar frota', Icons.directions_bus, 1),
            atalho('Motoristas', 'Gerenciar motoristas', Icons.people, 2),
            atalho('Passageiros', 'Gerenciar passageiros', Icons.person, 3),
            atalho(
              'Financeiro',
              'Consultar pagamentos',
              Icons.account_balance_wallet,
              6,
            ),
          ],
        ),
      ],
    );
  }

  Widget atalho(String titulo, String descricao, IconData icone, int indice) {
    return SizedBox(
      width: 230,
      child: Card(
        child: ListTile(
          leading: Icon(icone),
          title: Text(titulo),
          subtitle: Text(descricao),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            setState(() {
              paginaSelecionada = indice;
            });
          },
        ),
      ),
    );
  }

  Widget paginaEmConstrucao(String titulo, IconData icone, String descricao) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(descricao, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Esta seção será implementada nas próximas etapas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
