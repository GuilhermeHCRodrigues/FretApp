import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipo de conta que o administrador pode criar.
enum TipoAcesso {
  motorista('motorista', 'motorista'),
  passageiro('passageiro', 'passageiro');

  const TipoAcesso(this.valor, this.rotulo);

  /// Valor gravado em `perfis.tipo`.
  final String valor;
  final String rotulo;
}

/// Erro de criação de acesso já com a mensagem pronta para o usuário.
class AcessoException implements Exception {
  const AcessoException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Regras do formulário de acesso, compartilhadas entre motorista e passageiro.
abstract final class RegrasAcesso {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validarEmail(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Informe o e-mail de acesso';
    return _email.hasMatch(texto) ? null : 'Informe um e-mail válido';
  }

  static String? validarSenha(String? valor) {
    final texto = valor ?? '';
    if (texto.length < 8) return 'Use pelo menos 8 caracteres';
    if (texto.length > 72) return 'Use no máximo 72 caracteres';
    return null;
  }
}

/// Cria a conta de login (Supabase Auth + `perfis`) de um cadastro existente.
///
/// A criação acontece na Edge Function `criar-acesso`, que usa a service_role
/// no servidor e confere se quem chamou é administrador.
Future<void> criarAcesso({
  required TipoAcesso tipo,
  required String cadastroId,
  required String email,
  required String senha,
}) async {
  try {
    await Supabase.instance.client.functions.invoke(
      'criar-acesso',
      body: {
        'tipo': tipo.valor,
        'cadastro_id': cadastroId,
        'email': email.trim().toLowerCase(),
        'senha': senha,
      },
    );
  } on FunctionException catch (erro) {
    final detalhes = erro.details;
    if (detalhes is Map && detalhes['erro'] is String) {
      throw AcessoException(detalhes['erro'] as String);
    }
    if (erro.status == 404) {
      throw const AcessoException(
        'A função "criar-acesso" ainda não foi publicada no Supabase.',
      );
    }
    throw AcessoException(
      'Não foi possível criar o acesso (erro ${erro.status}). '
      'Confira se a função "criar-acesso" está publicada no Supabase.',
    );
  } catch (erro) {
    if (erro is AcessoException) rethrow;
    // No navegador, função não publicada falha no CORS antes do 404.
    throw const AcessoException(
      'Não foi possível falar com o servidor. Confira a internet e se a '
      'função "criar-acesso" está publicada no Supabase.',
    );
  }
}

/// Conta de login sem cadastro ligado (sobrou de um cadastro excluído).
class ContaOrfa {
  const ContaOrfa({
    required this.perfilId,
    this.email,
    this.tipo,
    this.nome,
    this.telefone,
  });

  factory ContaOrfa.deJson(Map<String, dynamic> j) => ContaOrfa(
    perfilId: j['perfil_id'] as String,
    email: j['email'] as String?,
    tipo: j['tipo'] as String?,
    nome: j['nome'] as String?,
    telefone: j['telefone'] as String?,
  );

  final String perfilId;
  final String? email;

  /// `perfis.tipo`; null quando o login nem tem perfil.
  final String? tipo;
  final String? nome;
  final String? telefone;
}

Future<Map<String, dynamic>> _invocarRemover(Map<String, dynamic> corpo) async {
  try {
    final resposta = await Supabase.instance.client.functions.invoke(
      'remover-acesso',
      body: corpo,
    );
    return Map<String, dynamic>.from(resposta.data as Map);
  } on FunctionException catch (erro) {
    final detalhes = erro.details;
    if (detalhes is Map && detalhes['erro'] is String) {
      throw AcessoException(detalhes['erro'] as String);
    }
    throw AcessoException(
      'Não foi possível remover o acesso (erro ${erro.status}). '
      'Confira se a função "remover-acesso" está publicada no Supabase.',
    );
  } catch (erro) {
    if (erro is AcessoException) rethrow;
    throw const AcessoException(
      'Não foi possível falar com o servidor. Confira a internet e se a '
      'função "remover-acesso" está publicada no Supabase.',
    );
  }
}

/// Apaga o login (Auth + perfis) para liberar o e-mail. Cancela a assinatura
/// no Stripe e apaga o histórico financeiro dessa conta.
Future<void> removerAcesso(String perfilId) =>
    _invocarRemover({'perfil_id': perfilId});

/// Logins de [tipo] (ou de qualquer tipo, com null) sem cadastro ligado.
Future<List<ContaOrfa>> listarContasSemCadastro(TipoAcesso? tipo) async {
  final dados = await _invocarRemover({
    'acao': 'listar',
    if (tipo != null) 'tipo': tipo.valor,
  });
  return [
    for (final c in (dados['contas'] as List? ?? const []))
      ContaOrfa.deJson(Map<String, dynamic>.from(c as Map)),
  ];
}
