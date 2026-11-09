
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final Future<String?> tipoFuturo;

  @override
  void initState() {
    super.initState();
    tipoFuturo = buscarPerfil();
  }

  Future<String?> buscarPerfil() async {
    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) return null;

    final perfil = await Supabase.instance.client
        .from('perfis')
        .select('tipo')
        .eq('id', usuario.id)
        .maybeSingle();

    return perfil?['tipo'] as String?;
  }

  Future<void> sair() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível sair.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FretApp'),
        actions: [
          IconButton(
            onPressed: sair,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: tipoFuturo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Erro ao carregar o perfil.'),
            );
          }

          final tipo = snapshot.data;

          if (tipo == null) {
            return const Center(
              child: Text('Usuário sem perfil cadastrado.'),
            );
          }

          if (tipo == 'administrador') {
            return const AdminDashboardView();
          }


          final titulo = switch (tipo) {
            'administrador' => 'Painel do Administrador',
            'motorista' => 'Área do Motorista',
            'passageiro' => 'Área do Passageiro',
            _ => 'Perfil não reconhecido',
          };

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_bus,
                  size: 70,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(usuario?.email ?? ''),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: sair,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
