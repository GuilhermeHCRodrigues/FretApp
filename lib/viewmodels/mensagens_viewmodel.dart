import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MensagensViewModel extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> mensagens = [];
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
      final dados = await supabase
          .from('mensagens')
          .select('id, titulo, conteudo, publico_alvo, prioridade, publicada, publicado_em, criado_em')
          .order('publicado_em', ascending: false);
      mensagens = List<Map<String, dynamic>>.from(dados);
    } on PostgrestException catch (e) {
      erro = e.code == '42P01' || e.code == '42703'
          ? 'A estrutura de mensagens ainda não foi criada. Execute a migration no Supabase.'
          : e.code == '42501'
              ? 'Seu usuário não tem permissão para gerenciar mensagens.'
              : 'Não foi possível carregar as mensagens: ${e.message}';
    } catch (_) {
      erro = 'Não foi possível conectar ao Supabase.';
    } finally {
      carregando = false;
      _notificar();
    }
  }

  Future<void> salvar({
    String? id,
    required String titulo,
    required String conteudo,
    required String publicoAlvo,
    required String prioridade,
    required bool publicada,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    final dados = {
      'titulo': titulo.trim(),
      'conteudo': conteudo.trim(),
      'publico_alvo': publicoAlvo,
      'prioridade': prioridade,
      'publicada': publicada,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      if (id == null) 'criado_por': userId,
      if (id == null) 'publicado_em': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await supabase.from('mensagens').insert(dados);
    } else {
      await supabase.from('mensagens').update(dados).eq('id', id);
    }
    await carregar();
  }

  Future<void> excluir(String id) async {
    await supabase.from('mensagens').delete().eq('id', id);
    await carregar();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
