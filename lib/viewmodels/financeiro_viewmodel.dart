import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceiroViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> mensalidades = [];
  List<Map<String, dynamic>> passageiros = [];
  bool carregando = false;
  String? erro;
  bool _ativo = true;

  void _notificar() {
    if (_ativo) notifyListeners();
  }

  Future<void> carregar({DateTime? competencia}) async {
    carregando = true;
    erro = null;
    _notificar();
    try {
      var consulta = supabase.from('mensalidades').select(
        'id, passageiro_id, competencia, valor, vencimento, descricao, criado_em, '
        'passageiros(nome), pagamentos(id, valor, pago_em, forma_pagamento, observacao)',
      );
      if (competencia != null) {
        final inicio = DateTime(competencia.year, competencia.month, 1);
        final fim = DateTime(competencia.year, competencia.month + 1, 1);
        consulta = consulta
            .gte('competencia', inicio.toIso8601String().substring(0, 10))
            .lt('competencia', fim.toIso8601String().substring(0, 10));
      }
      final resultados = await Future.wait([
        consulta.order('vencimento'),
        supabase.from('passageiros').select('id, nome').eq('ativo', true).order('nome'),
      ]);
      mensalidades = List<Map<String, dynamic>>.from(resultados[0]);
      passageiros = List<Map<String, dynamic>>.from(resultados[1]);
    } on PostgrestException catch (e) {
      erro = e.code == '42P01' || e.code == '42703'
          ? 'As tabelas financeiras ainda não foram criadas. Execute a migration do Financeiro no Supabase.'
          : e.code == '42501'
              ? 'Seu usuário não tem permissão para acessar o Financeiro.'
              : 'Não foi possível carregar os dados financeiros: ${e.message}';
    } catch (_) {
      erro = 'Não foi possível conectar ao Supabase.';
    } finally {
      carregando = false;
      _notificar();
    }
  }

  double recebido(Map<String, dynamic> mensalidade) {
    final pagamentos = List<Map<String, dynamic>>.from(
      mensalidade['pagamentos'] ?? const [],
    );
    return pagamentos.fold<double>(
      0,
      (total, pagamento) => total + (pagamento['valor'] as num).toDouble(),
    );
  }

  double saldo(Map<String, dynamic> mensalidade) {
    final valor = (mensalidade['valor'] as num).toDouble();
    return (valor - recebido(mensalidade)).clamp(0, double.infinity).toDouble();
  }

  String status(Map<String, dynamic> mensalidade) {
    if (saldo(mensalidade) <= 0.009) return 'paga';
    final vencimento = DateTime.parse(mensalidade['vencimento'].toString());
    final hoje = DateTime.now();
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    return vencimento.isBefore(dataHoje) ? 'atrasada' : recebido(mensalidade) > 0 ? 'parcial' : 'pendente';
  }

  Future<void> gerarMensalidades({
    required DateTime competencia,
    required DateTime vencimento,
    required double valor,
    String? descricao,
  }) async {
    final mes = DateTime(competencia.year, competencia.month, 1);
    if (passageiros.isEmpty) await carregar();
    final registros = passageiros.map((p) => {
      'passageiro_id': p['id'],
      'competencia': mes.toIso8601String().substring(0, 10),
      'valor': valor,
      'vencimento': vencimento.toIso8601String().substring(0, 10),
      'descricao': descricao,
    }).toList();
    if (registros.isNotEmpty) {
      await supabase.from('mensalidades').upsert(
        registros,
        onConflict: 'passageiro_id,competencia',
        ignoreDuplicates: true,
      );
    }
    await carregar(competencia: competencia);
  }

  Future<void> registrarPagamento({
    required String mensalidadeId,
    required double valor,
    required String formaPagamento,
    String? observacao,
  }) async {
    await supabase.from('pagamentos').insert({
      'mensalidade_id': mensalidadeId,
      'valor': valor,
      'forma_pagamento': formaPagamento,
      'observacao': observacao,
    });
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
