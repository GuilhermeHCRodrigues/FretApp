import 'package:flutter/material.dart';

import '../viewmodels/mensagens_viewmodel.dart';

class MensagensView extends StatefulWidget {
  const MensagensView({super.key, required this.onVoltar});
  final VoidCallback onVoltar;

  @override
  State<MensagensView> createState() => _MensagensViewState();
}

class _MensagensViewState extends State<MensagensView> {
  final vm = MensagensViewModel();
  String filtro = 'todas';

  @override
  void initState() {
    super.initState();
    vm.carregar();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> abrirEditor({Map<String, dynamic>? mensagem}) async {
    final titulo = TextEditingController(text: mensagem?['titulo']?.toString() ?? '');
    final conteudo = TextEditingController(text: mensagem?['conteudo']?.toString() ?? '');
    String publico = mensagem?['publico_alvo']?.toString() ?? 'todos';
    String prioridade = mensagem?['prioridade']?.toString() ?? 'normal';
    bool publicada = mensagem?['publicada'] == true;
    final formKey = GlobalKey<FormState>();

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(mensagem == null ? 'Novo comunicado' : 'Editar comunicado'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titulo,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Informe um título com pelo menos 3 caracteres.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: conteudo,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 5000,
                      decoration: const InputDecoration(labelText: 'Mensagem', alignLabelWithHint: true, border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escreva o conteúdo do comunicado.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: publico,
                      decoration: const InputDecoration(labelText: 'Destinatários', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos os usuários')),
                        DropdownMenuItem(value: 'passageiros', child: Text('Somente passageiros')),
                        DropdownMenuItem(value: 'motoristas', child: Text('Somente motoristas')),
                      ],
                      onChanged: (v) => setDialogState(() => publico = v ?? 'todos'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: prioridade,
                      decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'importante', child: Text('Importante')),
                        DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                      ],
                      onChanged: (v) => setDialogState(() => prioridade = v ?? 'normal'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publicar imediatamente'),
                      subtitle: const Text('Se desativado, o comunicado ficará como rascunho.'),
                      value: publicada,
                      onChanged: (v) => setDialogState(() => publicada = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'titulo': titulo.text,
                  'conteudo': conteudo.text,
                  'publico': publico,
                  'prioridade': prioridade,
                  'publicada': publicada,
                });
              },
              child: const Text('Salvar comunicado'),
            ),
          ],
        ),
      ),
    );
    titulo.dispose();
    conteudo.dispose();
    if (dados == null || !mounted) return;
    try {
      await vm.salvar(
        id: mensagem?['id']?.toString(),
        titulo: dados['titulo'] as String,
        conteudo: dados['conteudo'] as String,
        publicoAlvo: dados['publico'] as String,
        prioridade: dados['prioridade'] as String,
        publicada: dados['publicada'] as bool,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comunicado salvo.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  Future<void> confirmarExclusao(Map<String, dynamic> mensagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir comunicado?'),
        content: Text('O comunicado "${mensagem['titulo']}" será removido para todos os destinatários.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await vm.excluir(mensagem['id'].toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível excluir: $e')));
    }
  }

  String publicoLabel(String valor) => switch (valor) {
    'passageiros' => 'Passageiros',
    'motoristas' => 'Motoristas',
    _ => 'Todos',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) {
      final lista = vm.mensagens.where((m) =>
        filtro == 'todas' || (filtro == 'publicadas' ? m['publicada'] == true : m['publicada'] == false)
      ).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton(onPressed: widget.onVoltar, icon: const Icon(Icons.arrow_back)),
                const Expanded(child: Text('Mensagens', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                FilledButton.icon(onPressed: () => abrirEditor(), icon: const Icon(Icons.add), label: const Text('Novo comunicado')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Publique avisos e comunicados para passageiros e motoristas.'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Exibir: '),
                DropdownButton<String>(
                  value: filtro,
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Todas')),
                    DropdownMenuItem(value: 'publicadas', child: Text('Publicadas')),
                    DropdownMenuItem(value: 'rascunhos', child: Text('Rascunhos')),
                  ],
                  onChanged: (v) => setState(() => filtro = v ?? 'todas'),
                ),
                const Spacer(),
                IconButton(onPressed: vm.carregar, icon: const Icon(Icons.refresh), tooltip: 'Atualizar'),
              ],
            ),
          ),
          if (vm.carregando) const LinearProgressIndicator(),
          if (vm.erro != null) Padding(padding: const EdgeInsets.all(12), child: Text(vm.erro!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: lista.isEmpty
              ? Center(child: Text(vm.erro == null ? 'Nenhum comunicado cadastrado.' : 'Não foi possível carregar os comunicados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final m = lista[index];
                    final prioridade = m['prioridade']?.toString() ?? 'normal';
                    final cor = prioridade == 'urgente' ? Colors.red : prioridade == 'importante' ? Colors.orange : Colors.blue;
                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(backgroundColor: cor.withValues(alpha: .12), child: Icon(Icons.campaign_outlined, color: cor)),
                        title: Text(m['titulo'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${publicoLabel(m['publico_alvo'].toString())} • ${m['publicada'] == true ? 'Publicada' : 'Rascunho'} • ${prioridade.toUpperCase()}'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          Align(alignment: Alignment.centerLeft, child: Text(m['conteudo'].toString())),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(onPressed: () => abrirEditor(mensagem: m), icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
                              TextButton.icon(onPressed: () => confirmarExclusao(m), icon: const Icon(Icons.delete_outline), label: const Text('Excluir')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      );
    },
  );
}
