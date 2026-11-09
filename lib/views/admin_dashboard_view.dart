
import 'package:flutter/material.dart';
import 'veiculos_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() =>
      _AdminDashboardViewState();
}

class _AdminDashboardViewState
    extends State<AdminDashboardView> {
  bool mostrarVeiculos = false;

  @override
  Widget build(BuildContext context) {
    if (mostrarVeiculos) {
      return VeiculosView(
        onVoltar: () {
          setState(() => mostrarVeiculos = false);
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Painel Administrativo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Gerencie os recursos do FretApp.'),
        const SizedBox(height: 24),

        Card(
          child: ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Veículos'),
            subtitle: const Text('Cadastrar e gerenciar'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              setState(() => mostrarVeiculos = true);
            },
          ),
        ),

        const Card(
          child: ListTile(
            leading: Icon(Icons.people),
            title: Text('Motoristas'),
            subtitle: Text('Em breve'),
          ),
        ),

        const Card(
          child: ListTile(
            leading: Icon(Icons.route),
            title: Text('Rotas'),
            subtitle: Text('Em breve'),
          ),
        ),

        const Card(
          child: ListTile(
            leading: Icon(Icons.school),
            title: Text('Passageiros'),
            subtitle: Text('Em breve'),
          ),
        ),
      ],
    );
  }
}
