import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/situacao_financeira.dart';
import '../services/mensalidade_servico.dart';

/// Lê do banco os dados financeiros de uma competência (primeiro dia do mês).
typedef FonteFinanceira = Future<DadosFinanceiros> Function(
  DateTime competencia,
);

/// Financeiro do administrador: todos os passageiros e a situação do mês.
///
/// A cobrança é feita pelo Stripe: o webhook grava `mensalidades`
/// (uma por passageiro e mês, ligada a `perfis`) e `pagamentos`.
/// Aqui só lemos e cruzamos com o cadastro de passageiros.
class FinanceiroViewModel extends ChangeNotifier {
  FinanceiroViewModel({
    FonteFinanceira? fonte,
    DateTime Function()? agora,
    ConsultarValor? consultarValor,
    AlterarValor? alterarValor,
  }) : _fonte = fonte ?? buscarDadosFinanceiros,
       _agora = agora ?? DateTime.now,
       _consultarValor = consultarValor ?? consultarValorMensalidade,
       _alterarValor = alterarValor ?? alterarValorMensalidade {
    final hoje = _agora();
    competencia = DateTime(hoje.year, hoje.month);
  }

  final FonteFinanceira _fonte;
  final DateTime Function() _agora;
  final ConsultarValor _consultarValor;
  final AlterarValor _alterarValor;

  /// Valor vigente da mensalidade no Stripe (null enquanto não carregou).
  ValorMensalidade? valorMensalidade;
  bool carregandoValor = false;
  String? erroValor;

  late DateTime competencia;
  FiltroPagamento filtro = FiltroPagamento.todos;
  String busca = '';

  List<LinhaFinanceira> linhas = const [];
  bool carregando = false;
  String? erro;

  bool _ativo = true;
  int _requisicao = 0;

  void _notificar() {
    if (_ativo) notifyListeners();
  }

  ResumoFinanceiro get resumo => ResumoFinanceiro.de(linhas);

  /// Linhas após o filtro de status e a busca por nome/telefone/instituição.
  List<LinhaFinanceira> get linhasFiltradas {
    final termo = _normalizar(busca);
    return [
      for (final l in linhas)
        if (filtro.aceita(l.situacao) &&
            (termo.isEmpty ||
                _normalizar(
                  '${l.nome} ${l.telefone ?? ''} ${l.instituicao ?? ''}',
                ).contains(termo)))
          l,
    ];
  }

  /// Quantas linhas cada filtro mostraria (para os contadores dos chips).
  int contar(FiltroPagamento f) =>
      linhas.where((l) => f.aceita(l.situacao)).length;

  bool get competenciaEhAtual {
    final hoje = _agora();
    return competencia.year == hoje.year && competencia.month == hoje.month;
  }

  Future<void> carregar() async {
    final requisicao = ++_requisicao;
    carregando = true;
    erro = null;
    _notificar();
    try {
      final dados = await _fonte(competencia);
      if (requisicao != _requisicao) return;
      linhas = montarLinhas(dados, _agora());
    } on PostgrestException catch (e) {
      if (requisicao != _requisicao) return;
      erro = switch (e.code) {
        '42501' => 'Seu usuário não tem permissão para acessar o Financeiro.',
        '42P01' || '42703' =>
          'A estrutura do Financeiro no Supabase está diferente da esperada.',
        _ => 'Não foi possível carregar os dados financeiros.',
      };
    } catch (_) {
      if (requisicao != _requisicao) return;
      erro = 'Não foi possível conectar ao Supabase.';
    } finally {
      if (requisicao == _requisicao) {
        carregando = false;
        _notificar();
      }
    }
  }

  Future<void> carregarValor() async {
    carregandoValor = true;
    erroValor = null;
    _notificar();
    try {
      valorMensalidade = await _consultarValor();
    } on MensalidadeException catch (e) {
      erroValor = e.mensagem;
    } catch (_) {
      erroValor = 'Não foi possível consultar o valor no Stripe.';
    } finally {
      carregandoValor = false;
      _notificar();
    }
  }

  /// Altera o valor no Stripe. Lança [MensalidadeException] em caso de erro.
  Future<ResultadoAlteracao> alterarValor(
    int valorCentavos, {
    required bool aplicarAtuais,
  }) async {
    final resultado = await _alterarValor(valorCentavos, aplicarAtuais);
    valorMensalidade = ValorMensalidade(
      valorCentavos: resultado.valorCentavos,
      assinaturas: valorMensalidade?.assinaturas ?? 0,
    );
    erroValor = null;
    _notificar();
    return resultado;
  }

  Future<void> mudarMes(int delta) {
    competencia = DateTime(competencia.year, competencia.month + delta);
    return carregar();
  }

  void filtrar(FiltroPagamento novo) {
    if (filtro == novo) return;
    filtro = novo;
    _notificar();
  }

  void buscar(String texto) {
    busca = texto;
    _notificar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}

String _normalizar(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c')
    .trim();

String _dataIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Implementação real: quatro consultas em paralelo no Supabase.
Future<DadosFinanceiros> buscarDadosFinanceiros(DateTime competencia) async {
  final supabase = Supabase.instance.client;
  final mes = _dataIso(DateTime(competencia.year, competencia.month));

  final resultados = await Future.wait([
    supabase
        .from('perfis')
        .select('id, nome_completo, telefone, instituicao')
        .eq('tipo', 'passageiro'),
    supabase
        .from('mensalidades')
        .select(
          'id, passageiro_id, valor_centavos, vencimento, status, '
          'pagamentos(status, pago_em, valor_centavos)',
        )
        .eq('competencia', mes),
    supabase.from('assinaturas_stripe').select('passageiro_id, status'),
    _buscarCadastros(supabase),
  ]);

  return DadosFinanceiros(
    perfis: List<Map<String, dynamic>>.from(resultados[0]),
    mensalidades: List<Map<String, dynamic>>.from(resultados[1]),
    assinaturas: List<Map<String, dynamic>>.from(resultados[2]),
    cadastros: List<Map<String, dynamic>>.from(resultados[3]),
  );
}

/// Cadastros ativos ligados (ou não) a uma conta.
///
/// Sem a coluna `perfil_id` (migration de acesso ainda não aplicada), não dá
/// para cruzar cadastro e conta; mostrar os dois duplicaria as pessoas, então
/// a tabela fica só com as contas.
Future<List<Map<String, dynamic>>> _buscarCadastros(
  SupabaseClient supabase,
) async {
  try {
    return List<Map<String, dynamic>>.from(
      await supabase
          .from('passageiros')
          .select('id, nome, telefone, perfil_id')
          .eq('ativo', true),
    );
  } on PostgrestException catch (e) {
    if (e.code == '42703') return const [];
    rethrow;
  }
}
