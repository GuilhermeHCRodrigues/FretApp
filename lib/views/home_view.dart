import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard_view.dart';
import 'motorista_view.dart';
import 'passageiro_home_view.dart';

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Não foi possível sair.')));
    }
  }

  AppBar construirAppBar() => AppBar(
    title: const Text('FretApp'),
    actions: [
      IconButton(
        onPressed: sair,
        icon: const Icon(Icons.logout),
        tooltip: 'Sair',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final usuario = Supabase.instance.client.auth.currentUser;

    return FutureBuilder<String?>(
      future: tipoFuturo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: construirAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: construirAppBar(),
            body: const Center(child: Text('Erro ao carregar o perfil.')),
          );
        }

        final tipo = snapshot.data;

        if (tipo == null) {
          return Scaffold(
            appBar: construirAppBar(),
            body: const Center(child: Text('Usuário sem perfil cadastrado.')),
          );
        }

        if (tipo == 'motorista') {
          return MotoristaView(onSair: sair);
        }

        if (tipo == 'administrador') {
          return Scaffold(
            appBar: construirAppBar(),
            body: const AdminDashboardView(),
          );
        }

        if (tipo == 'passageiro') {
          // A tela do passageiro já tem a própria AppBar (celular) e o menu
          // lateral com "Sair" (desktop); envolver aqui duplicava a barra.
          return const PassageiroHomeView();
        }

        return Scaffold(
          appBar: construirAppBar(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bus, size: 70, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Perfil não reconhecido',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
          ),
        );
      },
    );
  }
}
