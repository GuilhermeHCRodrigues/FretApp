
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
          .select('id, placa, modelo, capacidade, ativo')
          .order('placa');

      veiculos = List<Map<String, dynamic>>.from(dados);
    } catch (_) {
      erro = 'Não foi possível carregar os veículos.';
    } finally {
      carregando = false;
      atualizar();
    }
  }

  Future<void> salvar({
    String? id,
    required String placa,
    required String modelo,
    required int capacidade,
  }) async {
    final dados = {
      'placa': placa.trim().toUpperCase(),
      'modelo': modelo.trim(),
      'capacidade': capacidade,
    };

    if (id == null) {
      await supabase.from('veiculos').insert(dados);
    } else {
      await supabase
          .from('veiculos')
          .update(dados)
          .eq('id', id);
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
