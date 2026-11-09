
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginViewModel extends ChangeNotifier {
  bool senhaVisivel = false;
  bool carregando = false;
  String? mensagemErro;

  void alternarSenha() {
    senhaVisivel = !senhaVisivel;
    notifyListeners();
  }

  String? validarEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Informe seu e-mail';
    }

    if (!email.contains('@')) {
      return 'Digite um e-mail válido';
    }

    return null;
  }

  String? validarSenha(String? senha) {
    if (senha == null || senha.isEmpty) {
      return 'Informe sua senha';
    }

    return null;
  }

  Future<bool> entrar(String email, String senha) async {
    if (carregando) return false;

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final resposta =
          await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );

      return resposta.session != null;
    } on AuthException catch (erro) {
      mensagemErro = erro.message;
      return false;
    } catch (_) {
      mensagemErro = 'Não foi possível conectar ao servidor.';
      return false;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }
}
