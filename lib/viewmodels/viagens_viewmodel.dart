import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViagensViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> viagens = [];
  List<Map<String, dynamic>> rotas = [];
  List<Map<String, dynamic>> motoristas = [];
  List<Map<String, dynamic>> veiculos = [];
  List<Map<String, dynamic>> passageiros = [];
  bool carregando = false;
  String? erro;
  bool _ativo = true;

  void _notificar() {
    if (_ativo) notifyListeners();
  }

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    _notificar();

    try {
      final resultados = await Future.wait([
        supabase
            .from('viagens')
            .select(
              '*, '
              'rotas(nome, origem, destino), '
              'motoristas(nome), '
              'veiculos(placa, modelo, capacidade), '
              'viagem_passageiros('
              'id, passageiro_id, embarcou, horario_embarque, '
              'passageiros(nome)'
              ')',
            )
            .order('data_viagem', ascending: false)
            .order('horario_saida'),
        supabase
            .from('rotas')
            .select('id, nome, origem, destino, horario_saida')
            .eq('ativo', true)
            .order('nome'),
        supabase
            .from('motoristas')
            .select('id, nome')
            .eq('ativo', true)
            .order('nome'),
        supabase
            .from('veiculos')
            .select('id, placa, modelo, capacidade')
            .eq('ativo', true)
            .order('placa'),
        supabase
            .from('passageiros')
            .select('id, nome')
            .eq('ativo', true)
            .order('nome'),
      ]);

      viagens = List<Map<String, dynamic>>.from(resultados[0]);
      rotas = List<Map<String, dynamic>>.from(resultados[1]);
      motoristas = List<Map<String, dynamic>>.from(resultados[2]);
      veiculos = List<Map<String, dynamic>>.from(resultados[3]);
      passageiros = List<Map<String, dynamic>>.from(resultados[4]);
    } catch (exception) {
      if (exception is PostgrestException) {
        if (exception.code == '42P01' || exception.code == '42703') {
          erro = 'A estrutura de viagens ainda não está pronta. '
              'Execute a migração SQL de viagens no Supabase.';
        } else if (exception.code == '42501') {
          erro = 'Seu usuário não tem permissão para gerenciar viagens. '
              'Entre com uma conta de administrador.';
        } else if (exception.code == 'PGRST200' ||
            exception.code == 'PGRST201') {
          erro = 'Não foi possível localizar os relacionamentos das tabelas. '
              'Confira as chaves estrangeiras da migração SQL.';
        } else {
          erro = 'Não foi possível carregar as viagens. '
              'Verifique as tabelas e a conexão com o Supabase.';
        }
      } else {
        erro = 'Não foi possível conectar ao Supabase.';
      }
    } finally {
      carregando = false;
      _notificar();
    }
  }

  Future<void> salvar({
    String? id,
    required Map<String, dynamic> dados,
    required List<String> passageirosIds,
  }) async {
    String viagemId;

    if (id == null) {
      final criada = await supabase
          .from('viagens')
          .insert(dados)
          .select('id')
          .single();
      viagemId = criada['id'] as String;
    } else {
      await supabase.from('viagens').update(dados).eq('id', id);
      viagemId = id;
    }

    final atuais = await supabase
        .from('viagem_passageiros')
        .select('passageiro_id')
        .eq('viagem_id', viagemId);

    final idsAtuais = List<Map<String, dynamic>>.from(atuais)
        .map((registro) => registro['passageiro_id'].toString())
        .toSet();
    final idsSelecionados = passageirosIds.toSet();

    for (final passageiroId in idsAtuais.difference(idsSelecionados)) {
      await supabase
          .from('viagem_passageiros')
          .delete()
          .eq('viagem_id', viagemId)
          .eq('passageiro_id', passageiroId);
    }

    final novos = idsSelecionados.difference(idsAtuais);
    if (novos.isNotEmpty) {
      await supabase.from('viagem_passageiros').insert(
        novos
            .map((passageiroId) => {
                  'viagem_id': viagemId,
                  'passageiro_id': passageiroId,
                })
            .toList(),
      );
    }

    await carregar();
  }

  Future<void> atualizarStatus(String id, String status) async {
    await supabase
        .from('viagens')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('viagens').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
