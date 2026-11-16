import 'package:supabase_flutter/supabase_flutter.dart';

/// Valor vigente da mensalidade no Stripe.
class ValorMensalidade {
  const ValorMensalidade({required this.valorCentavos, this.assinaturas = 0});

  final int valorCentavos;

  /// Assinaturas em vigor (ativas, em teste ou em atraso).
  final int assinaturas;
}

/// Resultado de uma alteração de valor.
class ResultadoAlteracao {
  const ResultadoAlteracao({
    required this.valorCentavos,
    this.atualizadas = 0,
    this.falhas = 0,
  });

  final int valorCentavos;
  final int atualizadas;
  final int falhas;
}

/// Erro com a mensagem pronta para o usuário.
class MensalidadeException implements Exception {
  const MensalidadeException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

typedef ConsultarValor = Future<ValorMensalidade> Function();
typedef AlterarValor = Future<ResultadoAlteracao> Function(
  int valorCentavos,
  bool aplicarAtuais,
);

/// Converte "250", "250,5", "1.250,00" ou "R$ 250,00" em centavos.
int? centavosDoTexto(String texto) {
  final limpo = texto.replaceAll(RegExp(r'[R$\s]'), '');
  if (!RegExp(r'^\d{1,3}(\.\d{3})*(,\d{1,2})?$|^\d+(,\d{1,2})?$')
      .hasMatch(limpo)) {
    return null;
  }
  final partes = limpo.replaceAll('.', '').split(',');
  final reais = int.parse(partes[0]);
  final centavos = partes.length > 1
      ? int.parse(partes[1].padRight(2, '0'))
      : 0;
  return reais * 100 + centavos;
}

Future<Map<String, dynamic>> _invocar(Map<String, dynamic> corpo) async {
  try {
    final resposta = await Supabase.instance.client.functions.invoke(
      'mensalidade-stripe',
      body: corpo,
    );
    return Map<String, dynamic>.from(resposta.data as Map);
  } on FunctionException catch (erro) {
    final detalhes = erro.details;
    if (detalhes is Map && detalhes['erro'] is String) {
      throw MensalidadeException(detalhes['erro'] as String);
    }
    if (erro.status == 404) {
      throw const MensalidadeException(
        'A função "mensalidade-stripe" ainda não foi publicada no Supabase.',
      );
    }
    throw MensalidadeException(
      'Não foi possível falar com o Stripe (erro ${erro.status}). '
      'Confira se a função "mensalidade-stripe" está publicada no Supabase.',
    );
  } catch (erro) {
    if (erro is MensalidadeException) rethrow;
    // No navegador, função não publicada falha no CORS antes do 404.
    throw const MensalidadeException(
      'Não foi possível falar com o servidor. Confira a internet e se a '
      'função "mensalidade-stripe" está publicada no Supabase.',
    );
  }
}

/// Valor atual e quantidade de assinaturas (consulta o Stripe).
Future<ValorMensalidade> consultarValorMensalidade() async {
  final dados = await _invocar({'acao': 'consultar'});
  return ValorMensalidade(
    valorCentavos: (dados['valor_centavos'] as num).toInt(),
    assinaturas: (dados['assinaturas'] as num?)?.toInt() ?? 0,
  );
}

/// Cria o preço novo no Stripe e, se pedido, migra as assinaturas atuais.
Future<ResultadoAlteracao> alterarValorMensalidade(
  int valorCentavos,
  bool aplicarAtuais,
) async {
  final dados = await _invocar({
    'acao': 'alterar',
    'valor_centavos': valorCentavos,
    'aplicar_assinaturas': aplicarAtuais,
  });
  return ResultadoAlteracao(
    valorCentavos: (dados['valor_centavos'] as num).toInt(),
    atualizadas: (dados['atualizadas'] as num?)?.toInt() ?? 0,
    falhas: (dados['falhas'] as num?)?.toInt() ?? 0,
  );
}
