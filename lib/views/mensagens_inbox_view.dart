import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MensagensInboxView extends StatefulWidget {
  const MensagensInboxView({super.key});

  @override
  State<MensagensInboxView> createState() => _MensagensInboxViewState();
}

class _MensagensInboxViewState extends State<MensagensInboxView> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> mensagens = [];
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final dados = await supabase
          .from('mensagens')
          .select('id, titulo, conteudo, prioridade, publicado_em, mensagens_lidas(usuario_id)')
          .eq('publicada', true)
          .order('publicado_em', ascending: false);
      final usuarioId = supabase.auth.currentUser?.id;
      mensagens = List<Map<String, dynamic>>.from(dados).map((m) {
        final leituras = List<Map<String, dynamic>>.from(m['mensagens_lidas'] ?? const []);
        return {...m, 'lida': leituras.any((l) => l['usuario_id'] == usuarioId)};
      }).toList();
    } catch (_) {
      erro = 'Não foi possível carregar os comunicados.';
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> marcarComoLida(String id) async {
    final usuarioId = supabase.auth.currentUser?.id;
    if (usuarioId == null) return;
    try {
      await supabase.from('mensagens_lidas').upsert({
        'mensagem_id': id,
        'usuario_id': usuarioId,
      });
      if (mounted) {
        setState(() {
          mensagens = mensagens.map((m) => m['id'] == id ? {...m, 'lida': true} : m).toList();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar a leitura.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Avisos e comunicados'),
      actions: [IconButton(onPressed: carregar, icon: const Icon(Icons.refresh))],
    ),
    body: carregando
      ? const Center(child: CircularProgressIndicator())
      : erro != null
        ? Center(child: Text(erro!))
        : mensagens.isEmpty
          ? const Center(child: Text('Nenhum comunicado disponível.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: mensagens.length,
              itemBuilder: (context, index) {
                final m = mensagens[index];
                final prioridade = m['prioridade']?.toString() ?? 'normal';
                final cor = prioridade == 'urgente' ? Colors.red : prioridade == 'importante' ? Colors.orange : Colors.blue;
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: cor.withValues(alpha: .12),
                      child: Icon(m['lida'] == true ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, color: cor),
                    ),
                    title: Text(m['titulo'].toString(), style: TextStyle(fontWeight: m['lida'] == true ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text('${prioridade.toUpperCase()} • ${m['lida'] == true ? 'Lida' : 'Não lida'}'),
                    onExpansionChanged: (expandiu) {
                      if (expandiu && m['lida'] != true) marcarComoLida(m['id'].toString());
                    },
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [Align(alignment: Alignment.centerLeft, child: Text(m['conteudo'].toString()))],
                  ),
                );
              },
            ),
  );
}
