import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VeiculosViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> veiculos = [];
  bool carregando = false;
  String? erro;
  bool _ativo = true;

  void atualizar() {
    if (_ativo) notifyListeners();
  }

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    atualizar();

    try {
      final dados = await supabase
          .from('veiculos')
          .select(
            'id, placa, marca, modelo, ano_fabricacao, ano_modelo, cor, '
            'capacidade, tipo, chassi_final, motor_final, renavam, uf, '
            'municipio, quilometragem, combustivel, observacoes, ativo',
          )
          .order('placa');

      veiculos = List<Map<String, dynamic>>.from(dados);
    } catch (exception) {
      if (exception is PostgrestException && exception.code == '42703') {
        erro = 'Os novos campos ainda não existem no Supabase. '
            'Execute a migração SQL do projeto.';
      } else {
        erro = 'Não foi possível carregar os veículos.';
      }
    } finally {
      carregando = false;
      atualizar();
    }
  }

  Future<void> salvar({
    String? id,
    required Map<String, dynamic> dados,
  }) async {
    final registro = {
      ...dados,
      'placa': (dados['placa'] as String).trim().toUpperCase(),
      'modelo': (dados['modelo'] as String).trim(),
    };

    if (id == null) {
      await supabase.from('veiculos').insert(registro);
    } else {
      await supabase.from('veiculos').update(registro).eq('id', id);
    }

    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('veiculos').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
