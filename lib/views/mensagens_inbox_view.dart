import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Busca os comunicados publicados visíveis ao usuário logado.
///
/// O filtro por público (todos / passageiros / motoristas) é feito pela RLS
/// da tabela `mensagens`, de acordo com o `perfis.tipo` de quem consulta.
Future<List<Map<String, dynamic>>> buscarComunicados({int? limite}) async {
  final supabase = Supabase.instance.client;
  var consulta = supabase
      .from('mensagens')
      .select(
        'id, titulo, conteudo, prioridade, publicado_em, '
        'mensagens_lidas(usuario_id)',
      )
      .eq('publicada', true)
      .order('publicado_em', ascending: false);
  final dados = await (limite == null ? consulta : consulta.limit(limite));
  final usuarioId = supabase.auth.currentUser?.id;
  return List<Map<String, dynamic>>.from(dados).map((m) {
    final leituras = List<Map<String, dynamic>>.from(
      m['mensagens_lidas'] ?? const [],
    );
    return {...m, 'lida': leituras.any((l) => l['usuario_id'] == usuarioId)};
  }).toList();
}

Color _corPrioridade(String prioridade) => switch (prioridade) {
  'urgente' => Colors.red,
  'importante' => Colors.orange,
  _ => Colors.blue,
};

String _dataCurta(Object? valor) {
  final data = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
  if (data == null) return '';
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)}/${data.year} '
      '${dois(data.hour)}:${dois(data.minute)}';
}

/// Caixa de entrada de avisos e comunicados do administrador.
///
/// [embutida] = true quando a tela já está dentro de uma casca com a própria
/// barra (aba "Avisos" do motorista): sem `AppBar`, ocupa o espaço que recebe.
class MensagensInboxView extends StatefulWidget {
  const MensagensInboxView({super.key, this.embutida = false});

  final bool embutida;

  @override
  State<MensagensInboxView> createState() => _MensagensInboxViewState();
}

class _MensagensInboxViewState extends State<MensagensInboxView> {
  SupabaseClient get supabase => Supabase.instance.client;
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
      final dados = await buscarComunicados();
      if (!mounted) return;
      mensagens = dados;
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
          mensagens = mensagens
              .map((m) => m['id'] == id ? {...m, 'lida': true} : m)
              .toList();
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

  Widget _corpo() {
    if (carregando && mensagens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (erro != null && mensagens.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(erro!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: carregar,
      child: mensagens.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Nenhum comunicado disponível.')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: mensagens.length,
              itemBuilder: (context, index) {
                final m = mensagens[index];
                final prioridade = m['prioridade']?.toString() ?? 'normal';
                final cor = _corPrioridade(prioridade);
                final lida = m['lida'] == true;
                final data = _dataCurta(m['publicado_em']);
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: cor.withValues(alpha: .12),
                      child: Icon(
                        lida
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        color: cor,
                      ),
                    ),
                    title: Text(
                      m['titulo'].toString(),
                      style: TextStyle(
                        fontWeight: lida ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      [
                        prioridade.toUpperCase(),
                        if (data.isNotEmpty) data,
                        lida ? 'Lida' : 'Não lida',
                      ].join(' • '),
                    ),
                    onExpansionChanged: (expandiu) {
                      if (expandiu && !lida) {
                        marcarComoLida(m['id'].toString());
                      }
                    },
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(m['conteudo'].toString()),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embutida) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Avisos e comunicados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: carregando ? null : carregar,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(child: _corpo()),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos e comunicados'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: carregando ? null : carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _corpo(),
    );
  }
}

/// Cartão com os últimos comunicados (tela inicial do passageiro).
class UltimosComunicados extends StatefulWidget {
  const UltimosComunicados({
    super.key,
    required this.aoVerTodos,
    this.decoracao,
    this.buscar,
  });

  /// Abre a caixa de entrada; ao voltar, o cartão recarrega (lidas mudam).
  final Future<void> Function() aoVerTodos;
  final BoxDecoration? decoracao;

  /// Permite que um teste forneça os dados (sem Supabase).
  final Future<List<Map<String, dynamic>>> Function()? buscar;

  @override
  State<UltimosComunicados> createState() => _UltimosComunicadosState();
}

class _UltimosComunicadosState extends State<UltimosComunicados> {
  late Future<List<Map<String, dynamic>>> _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _dados = (widget.buscar ?? () => buscarComunicados(limite: 3))();
  }

  Future<void> _abrir() async {
    await widget.aoVerTodos();
    if (mounted) setState(_carregar);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: widget.decoracao,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dados,
        builder: (context, snapshot) {
          final itens = snapshot.data ?? const [];
          final naoLidas = itens.where((m) => m['lida'] != true).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(Icons.campaign, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comunicados',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          naoLidas == 0
                              ? 'Enviados pela administração'
                              : naoLidas == 1
                              ? '1 não lido'
                              : '$naoLidas não lidos',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _abrir,
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else if (snapshot.hasError)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Não foi possível carregar os comunicados.',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_carregar),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                )
              else if (itens.isEmpty)
                const Text(
                  'Nenhum comunicado por enquanto. Aqui você receberá avisos '
                  'sobre horários, alterações de rotas e informações '
                  'importantes enviadas pela administração.',
                  style: TextStyle(color: Colors.blueGrey, height: 1.5),
                )
              else
                for (final m in itens)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: _corPrioridade(
                        m['prioridade']?.toString() ?? 'normal',
                      ),
                    ),
                    title: Text(
                      m['titulo'].toString(),
                      style: TextStyle(
                        fontWeight: m['lida'] == true
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      m['conteudo'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall,
                    ),
                    onTap: _abrir,
                  ),
            ],
          );
        },
      ),
    );
  }
}
