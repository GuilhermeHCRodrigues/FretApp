
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'views/login_view.dart';
import 'views/home_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const chavePublica = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  if (chavePublica.isEmpty) {
    throw StateError(
      'Chave pública do Supabase não configurada.',
    );
  }

  await Supabase.initialize(
    url: 'https://pzisjltouwrmhmamskfw.supabase.co',
    publishableKey: chavePublica,
  );

  runApp(const FretApp());
}

class FretApp extends StatelessWidget {
  const FretApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FretApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: auth.onAuthStateChange,
        builder: (context, snapshot) {
          final sessao =
              snapshot.data?.session ?? auth.currentSession;

          if (sessao == null) {
            return const LoginView();
          }

          return const HomeView();
        },
      ),
    );
  }
}
