import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/rotas_viewmodel.dart';

class RotasView extends StatefulWidget {
  final VoidCallback onVoltar;
  const RotasView({super.key, required this.onVoltar});

  @override
  State<RotasView> createState() => _RotasViewState();
}

class _RotasViewState extends State<RotasView> {
  final vm = RotasViewModel();
  static const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

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

  String mensagemErro(Object erro) {
    if (erro is PostgrestException) {
      if (erro.code == '23505') return 'Já existe um ponto com essa ordem nesta rota.';
      if (erro.code == '23503') return 'Motorista ou veículo selecionado não está mais disponível.';
      if (erro.code == '42501') return 'Você não tem permissão para realizar esta operação.';
      if (erro.code == '42P01' || erro.code == '42703') return 'Execute a migração SQL de rotas no Supabase.';
    }
    return 'Não foi possível salvar. Confira os dados e tente novamente.';
  }

  Future<void> abrirFormulario([Map<String, dynamic>? rota]) async {
    final formKey = GlobalKey<FormState>();
    final novo = rota == null;
    final nome = TextEditingController(text: rota?['nome']?.toString() ?? '');
    final origem = TextEditingController(text: rota?['origem']?.toString() ?? '');
    final destino = TextEditingController(text: rota?['destino']?.toString() ?? '');
    final horario = TextEditingController(text: rota?['horario_saida']?.toString().substring(0, 5) ?? '');
    final observacoes = TextEditingController(text: rota?['observacoes']?.toString() ?? '');
    final pontosOriginais = List<Map<String, dynamic>>.from(rota?['pontos_rota'] ?? const []);
    final pontos = pontosOriginais.map((p) => {
      'nome': p['nome']?.toString() ?? '',
      'endereco': p['endereco']?.toString() ?? '',
      'bairro': p['bairro']?.toString() ?? '',
      'horario': p['horario']?.toString().substring(0, 5) ?? '',
    }).toList();
    final diasSelecionados = List<String>.from(rota?['dias_semana'] ?? const []);
    String? motoristaId = rota?['motorista_id']?.toString();
    String? veiculoId = rota?['veiculo_id']?.toString();
    bool ativo = rota?['ativo'] as bool? ?? true;

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(novo ? 'Cadastrar rota' : 'Editar rota'),
          content: SizedBox(
            width: 620,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .72),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nome,
                        decoration: const InputDecoration(labelText: 'Nome da rota', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().length < 3) ? 'Informe um nome com pelo menos 3 caracteres' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: origem,
                        decoration: const InputDecoration(labelText: 'Origem', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a origem' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: destino,
                        decoration: const InputDecoration(labelText: 'Destino', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o destino' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: horario,
                        decoration: const InputDecoration(labelText: 'Horário de saída (HH:mm)', hintText: '06:30', border: OutlineInputBorder()),
                        keyboardType: TextInputType.datetime,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v.trim()) ? null : 'Use o formato HH:mm';
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Dias de funcionamento', style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 4,
                        children: dias.map((dia) => FilterChip(
                          label: Text(dia),
                          selected: diasSelecionados.contains(dia),
                          onSelected: (selecionado) => setDialogState(() {
                            selecionado ? diasSelecionados.add(dia) : diasSelecionados.remove(dia);
                          }),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: motoristaId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Motorista (opcional)', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Não definido')),
                          ...vm.motoristas.map((m) => DropdownMenuItem<String>(
                            value: m['id'] as String,
                            child: Text(m['nome'].toString(), overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (v) => motoristaId = v,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: veiculoId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Veículo (opcional)', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Não definido')),
                          ...vm.veiculos.map((v) => DropdownMenuItem<String>(
                            value: v['id'] as String,
                            child: Text('${v['placa']} • ${v['modelo']} (${v['capacidade']} lugares)', overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (v) => veiculoId = v,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<bool>(
                        value: ativo,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Ativa')),
                          DropdownMenuItem(value: false, child: Text('Inativa')),
                        ],
                        onChanged: (v) => ativo = v ?? true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Text('Pontos de parada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          TextButton.icon(
                            onPressed: () => setDialogState(() => pontos.add({'nome': '', 'endereco': '', 'bairro': '', 'horario': ''})),
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar ponto'),
                          ),
                        ],
                      ),
                      if (pontos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Adicione os locais de embarque e desembarque na ordem da rota.'),
                        ),
                      ...pontos.asMap().entries.map((entry) {
                        final i = entry.key;
                        final ponto = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(radius: 13, child: Text('${i + 1}')),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Parada ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    IconButton(
                                      tooltip: 'Remover ponto',
                                      onPressed: () => setDialogState(() => pontos.removeAt(i)),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  initialValue: ponto['nome'],
                                  decoration: const InputDecoration(labelText: 'Nome do ponto', border: OutlineInputBorder()),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do ponto' : null,
                                  onChanged: (v) => ponto['nome'] = v,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: ponto['endereco'],
                                  decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o endereço' : null,
                                  onChanged: (v) => ponto['endereco'] = v,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: TextFormField(
                                      initialValue: ponto['bairro'],
                                      decoration: const InputDecoration(labelText: 'Bairro (opcional)', border: OutlineInputBorder()),
                                      onChanged: (v) => ponto['bairro'] = v,
                                    )),
                                    const SizedBox(width: 8),
                                    SizedBox(width: 125, child: TextFormField(
                                      initialValue: ponto['horario'],
                                      decoration: const InputDecoration(labelText: 'Horário', hintText: '06:45', border: OutlineInputBorder()),
                                      keyboardType: TextInputType.datetime,
                                      validator: (v) => (v == null || v.trim().isEmpty || RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v.trim())) ? null : 'HH:mm',
                                      onChanged: (v) => ponto['horario'] = v,
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: observacoes,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Observações (opcional)', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  'nome': nome.text.trim(),
                  'origem': origem.text.trim(),
                  'destino': destino.text.trim(),
                  'horario_saida': horario.text.trim().isEmpty ? null : horario.text.trim(),
                  'dias_semana': diasSelecionados,
                  'motorista_id': motoristaId,
                  'veiculo_id': veiculoId,
                  'ativo': ativo,
                  'observacoes': observacoes.text.trim().isEmpty ? null : observacoes.text.trim(),
                  'pontos': pontos,
                });
              },
              child: const Text('Salvar rota'),
            ),
          ],
        ),
      ),
    );

    nome.dispose();
    origem.dispose();
    destino.dispose();
    horario.dispose();
    observacoes.dispose();

    if (dados == null || !mounted) return;
    try {
      final pontosSalvos = List<Map<String, dynamic>>.from(dados.remove('pontos') as List);
      await vm.salvar(
        id: rota?['id'] as String?,
        dados: dados,
        pontos: pontosSalvos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(novo ? 'Rota cadastrada com sucesso!' : 'Rota atualizada com sucesso!')));
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> excluir(Map<String, dynamic> rota) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir rota?'),
        content: Text('Deseja excluir "${rota['nome']}" e todos os seus pontos de parada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await vm.excluir(rota['id'] as String);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota excluída.')));
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, child) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(onPressed: widget.onVoltar, icon: const Icon(Icons.arrow_back), tooltip: 'Voltar'),
              const Text('Rotas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(onPressed: () => abrirFormulario(), icon: const Icon(Icons.add), label: const Text('Nova rota')),
            ],
          ),
        ),
        if (vm.carregando) const LinearProgressIndicator(),
        Expanded(child: conteudo()),
      ],
    ),
  );

  Widget conteudo() {
    if (vm.carregando && vm.rotas.isEmpty) return const Center(child: CircularProgressIndicator());
    if (vm.erro != null && vm.rotas.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(vm.erro!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: vm.carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ]),
      ));
    }
    if (vm.rotas.isEmpty) return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        SizedBox(height: 100),
        Icon(Icons.route_outlined, size: 56, color: Colors.grey),
        SizedBox(height: 16),
        Center(child: Text('Nenhuma rota cadastrada.')),
      ]),
    );

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: vm.rotas.length,
        itemBuilder: (context, index) {
          final rota = vm.rotas[index];
          final pontos = List<Map<String, dynamic>>.from(rota['pontos_rota'] ?? const []);
          final motorista = vm.motoristas.where((m) => m['id'] == rota['motorista_id']).firstOrNull;
          final veiculo = vm.veiculos.where((v) => v['id'] == rota['veiculo_id']).firstOrNull;
          final diasRota = List<String>.from(rota['dias_semana'] ?? const []);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: ExpansionTile(
              leading: CircleAvatar(child: Icon(Icons.route, color: (rota['ativo'] as bool? ?? true) ? Colors.blue : Colors.grey)),
              title: Text(rota['nome'].toString()),
              subtitle: Text('${rota['origem']} → ${rota['destino']} • ${rota['horario_saida']?.toString().substring(0, 5) ?? 'Sem horário'} • ${pontos.length} parada(s)'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 4, children: [
                  Chip(label: Text((rota['ativo'] as bool? ?? true) ? 'Ativa' : 'Inativa')),
                  if (diasRota.isNotEmpty) Chip(label: Text(diasRota.join(', '))),
                  if (motorista != null) Chip(avatar: const Icon(Icons.person, size: 16), label: Text(motorista['nome'].toString())),
                  if (veiculo != null) Chip(avatar: const Icon(Icons.directions_bus, size: 16), label: Text('${veiculo['placa']} • ${veiculo['modelo']}')),
                ])),
                const Align(alignment: Alignment.centerLeft, child: Text('Sequência de paradas', style: TextStyle(fontWeight: FontWeight.bold))),
                if (pontos.isEmpty) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum ponto cadastrado.'))),
                ...pontos.map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 13, child: Text(p['ordem'].toString())),
                  title: Text(p['nome'].toString()),
                  subtitle: Text('${p['endereco']} • ${p['bairro'] ?? 'Bairro não informado'}'),
                  trailing: Text(p['horario']?.toString().substring(0, 5) ?? ''),
                )),
                if ((rota['observacoes'] as String?)?.isNotEmpty ?? false)
                  Align(alignment: Alignment.centerLeft, child: Text('Observações: ${rota['observacoes']}')),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(onPressed: () => abrirFormulario(rota), icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
                  TextButton.icon(onPressed: () => excluir(rota), icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Excluir', style: TextStyle(color: Colors.red))),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
