import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RotasViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> rotas = [];
  List<Map<String, dynamic>> motoristas = [];
  List<Map<String, dynamic>> veiculos = [];
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
            .from('rotas')
            .select('*, pontos_rota(*)')
            .order('nome'),
        supabase.from('motoristas').select('id, nome').eq('ativo', true).order('nome'),
        supabase.from('veiculos').select('id, placa, modelo, capacidade')
            .eq('ativo', true).order('placa'),
      ]);

      rotas = List<Map<String, dynamic>>.from(resultados[0]).map((rota) {
        final pontos = List<Map<String, dynamic>>.from(
          rota['pontos_rota'] ?? const [],
        )..sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));
        return {...rota, 'pontos_rota': pontos};
      }).toList();
      motoristas = List<Map<String, dynamic>>.from(resultados[1]);
      veiculos = List<Map<String, dynamic>>.from(resultados[2]);
    } catch (exception) {
      if (exception is PostgrestException &&
          (exception.code == '42P01' || exception.code == '42703')) {
        erro = 'As tabelas de rotas ainda não existem. Execute a migração SQL no Supabase.';
      } else if (exception is PostgrestException && exception.code == '42501') {
        erro = 'Seu usuário não tem permissão para gerenciar rotas.';
      } else {
        erro = 'Não foi possível carregar as rotas. Verifique sua conexão e as tabelas do Supabase.';
      }
    } finally {
      carregando = false;
      _notificar();
    }
  }

  Future<void> salvar({
    String? id,
    required Map<String, dynamic> dados,
    required List<Map<String, dynamic>> pontos,
  }) async {
    final registro = {
      ...dados,
      'nome': (dados['nome'] as String).trim(),
      'origem': (dados['origem'] as String).trim(),
      'destino': (dados['destino'] as String).trim(),
    };

    String rotaId;
    if (id == null) {
      final criada = await supabase.from('rotas').insert(registro).select('id').single();
      rotaId = criada['id'] as String;
    } else {
      await supabase.from('rotas').update(registro).eq('id', id);
      rotaId = id;
      await supabase.from('pontos_rota').delete().eq('rota_id', rotaId);
    }

    if (pontos.isNotEmpty) {
      final registros = pontos.asMap().entries.map((entry) => {
        'rota_id': rotaId,
        'nome': (entry.value['nome'] as String).trim(),
        'endereco': (entry.value['endereco'] as String).trim(),
        'bairro': (entry.value['bairro'] as String?)?.trim().isEmpty ?? true
            ? null : (entry.value['bairro'] as String).trim(),
        'horario': (entry.value['horario'] as String?)?.trim().isEmpty ?? true
            ? null : (entry.value['horario'] as String).trim(),
        'ordem': entry.key + 1,
      }).toList();
      await supabase.from('pontos_rota').insert(registros);
    }

    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('rotas').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
