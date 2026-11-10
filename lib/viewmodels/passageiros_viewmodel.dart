import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassageirosViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> passageiros = [];
  bool carregando = false;
  String? erro;
  bool _ativo = true;

  void _atualizar() {
    if (_ativo) notifyListeners();
  }

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    _atualizar();

    try {
      final dados = await supabase
          .from('passageiros')
          .select(
            'id, nome, cpf, telefone, email, data_nascimento, cep, '
            'logradouro, numero, complemento, bairro, cidade, uf, '
            'nome_responsavel, telefone_responsavel, observacoes, ativo',
          )
          .order('nome');

      passageiros = List<Map<String, dynamic>>.from(dados);
    } catch (exception) {
      if (exception is PostgrestException) {
        if (exception.code == '42P01' || exception.code == '42703') {
          erro = 'A tabela de passageiros ainda não está pronta. '
              'Execute a migração SQL do projeto no Supabase.';
        } else if (exception.code == '42501') {
          erro = 'Seu usuário não tem permissão para consultar os passageiros. '
              'Entre com uma conta de administrador.';
        } else {
          erro = 'Não foi possível carregar os passageiros.';
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
    final registro = <String, dynamic>{
      ...dados,
      'nome': (dados['nome'] as String).trim(),
      'cpf': (dados['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
      'telefone': (dados['telefone'] as String).replaceAll(RegExp(r'\D'), ''),
      'email': (dados['email'] as String?)?.trim().toLowerCase(),
      'cep': (dados['cep'] as String?)?.replaceAll(RegExp(r'\D'), ''),
      'uf': (dados['uf'] as String?)?.trim().toUpperCase(),
      'telefone_responsavel': (dados['telefone_responsavel'] as String?)
          ?.replaceAll(RegExp(r'\D'), ''),
    };

    for (final campo in ['email', 'cep', 'uf', 'telefone_responsavel']) {
      if ((registro[campo] as String?)?.isEmpty ?? false) {
        registro[campo] = null;
      }
    }

    if (id == null) {
      await supabase.from('passageiros').insert(registro);
    } else {
      await supabase.from('passageiros').update(registro).eq('id', id);
    }

    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('passageiros').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
