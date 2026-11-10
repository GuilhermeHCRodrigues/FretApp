import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MotoristasViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> motoristas = [];
  bool carregando = false;
  String? erro;
  bool _ativo = true;

  void _atualizar() {
    if (_ativo) {
      notifyListeners();
    }
  }

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    _atualizar();

    try {
      final dados = await supabase
          .from('motoristas')
          .select(
            'id, nome, cpf, telefone, email, cnh_numero, '
            'cnh_categoria, cnh_validade, ativo',
          )
          .order('nome');

      motoristas = List<Map<String, dynamic>>.from(dados);
    } catch (exception) {
      if (exception is PostgrestException) {
        if (exception.code == '42P01' || exception.code == '42703') {
          erro = 'A tabela de motoristas ainda não está pronta. '
              'Execute a migração SQL do projeto no Supabase.';
        } else if (exception.code == '42501') {
          erro = 'Seu usuário não tem permissão para consultar os motoristas. '
              'Entre com uma conta de administrador.';
        } else {
          erro = 'Não foi possível carregar os motoristas.';
        }
      } else {
        erro = 'Não foi possível conectar ao Supabase.';
      }
    } finally {
      carregando = false;
      _atualizar();
    }
  }

  Future<void> salvar({
    String? id,
    required Map<String, dynamic> dados,
  }) async {
    final registro = {
      ...dados,
      'nome': (dados['nome'] as String).trim(),
      'cpf': (dados['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
      'telefone': (dados['telefone'] as String).replaceAll(RegExp(r'\D'), ''),
      'email': (dados['email'] as String?)?.trim().toLowerCase(),
      'cnh_numero':
          (dados['cnh_numero'] as String).replaceAll(RegExp(r'\D'), ''),
    };

    if (id == null) {
      await supabase.from('motoristas').insert(registro);
    } else {
      await supabase.from('motoristas').update(registro).eq('id', id);
    }

    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('motoristas').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
