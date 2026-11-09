
import 'package:flutter/material.dart';
import '../viewmodels/login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final viewModel = LoginViewModel();

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  
Future<void> entrar() async {
  if (!formKey.currentState!.validate()) {
    return;
  }

  final sucesso = await viewModel.entrar(
    emailController.text,
    senhaController.text,
  );

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sucesso
            ? 'Login realizado com sucesso!'
            : viewModel.mensagemErro ?? 'Não foi possível entrar.',
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.directions_bus,
                    size: 64,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'FretApp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Entre na sua conta',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: viewModel.validarEmail,
                  ),

                  const SizedBox(height: 16),

                  AnimatedBuilder(
                    animation: viewModel,
                    builder: (context, child) {
                      return TextFormField(
                        controller: senhaController,
                        obscureText: !viewModel.senhaVisivel,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: viewModel.alternarSenha,
                            icon: Icon(
                              viewModel.senhaVisivel
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: viewModel.validarSenha,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  AnimatedBuilder(
  animation: viewModel,
  builder: (context, child) {
    return FilledButton(
      onPressed: viewModel.carregando ? null : entrar,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          viewModel.carregando ? 'Entrando...' : 'Entrar',
        ),
      ),
    );
  },
),

                  const SizedBox(height: 16),

                  const Text(
                    'Protótipo: autenticação ainda não conectada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
