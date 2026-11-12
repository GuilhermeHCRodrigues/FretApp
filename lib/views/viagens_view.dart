import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/viagens_viewmodel.dart';

class ViagensView extends StatefulWidget {
  const ViagensView({super.key, required this.onVoltar});

  final VoidCallback onVoltar;

  @override
  State<ViagensView> createState() => _ViagensViewState();
}

class _ViagensViewState extends State<ViagensView> {
  final vm = ViagensViewModel();
  final buscaController = TextEditingController();
  String filtroStatus = 'todas';

  static const statusDisponiveis = [
    'programada',
    'em_andamento',
    'finalizada',
    'cancelada',
  ];

  @override
  void initState() {
    super.initState();
    vm.carregar();
  }

  @override
  void dispose() {
    buscaController.dispose();
    vm.dispose();
    super.dispose();
  }

  String mensagemErro(Object erro) {
    if (erro is PostgrestException) {
      if (erro.code == '23503') {
        return 'A rota, o motorista, o veículo ou um passageiro selecionado não está mais disponível.';
      }
      if (erro.code == '23505') {
        return 'Este passageiro já está vinculado à viagem.';
      }
      if (erro.code == '42501') {
        return 'Seu usuário não tem permissão para realizar esta operação.';
      }
      if (erro.code == '42P01' || erro.code == '42703') {
        return 'Execute a migração SQL de viagens no Supabase.';
      }
    }
    return 'Não foi possível concluir a operação. Confira os dados e tente novamente.';
  }

  String rotuloStatus(String status) => switch (status) {
    'programada' => 'Programada',
    'em_andamento' => 'Em andamento',
    'finalizada' => 'Finalizada',
    'cancelada' => 'Cancelada',
    _ => status,
  };

  Color corStatus(String status) => switch (status) {
    'programada' => Colors.blue,
    'em_andamento' => Colors.orange.shade800,
    'finalizada' => Colors.green.shade700,
    'cancelada' => Colors.red.shade700,
    _ => Colors.grey,
  };

  String formatarData(String data) {
    final partes = data.split('-');
    if (partes.length != 3) return data;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String dataIso(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  DateTime? dataHoraSaida(Map<String, dynamic>? viagem) =>
      DateTime.tryParse(viagem?['saida_prevista']?.toString() ?? '')?.toLocal();

  String dataViagem(Map<String, dynamic>? viagem) {
    final data = dataHoraSaida(viagem);
    return data == null ? dataIso(DateTime.now()) : dataIso(data);
  }

  String horaSaida(Map<String, dynamic>? viagem) {
    final data = dataHoraSaida(viagem);
    if (data == null) return '--:--';
    return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  String timestampSaida(DateTime data, String horario) {
    final partes = horario.split(':');
    final local = DateTime(
      data.year,
      data.month,
      data.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );
    return local.toUtc().toIso8601String();
  }

  Future<void> abrirFormulario([Map<String, dynamic>? viagem]) async {
    if (vm.rotas.isEmpty || vm.motoristas.isEmpty || vm.veiculos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre pelo menos uma rota, um motorista e um veículo ativos antes de criar uma viagem.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nova = viagem == null;
    final observacoes = TextEditingController(
      text: viagem?['observacoes']?.toString() ?? '',
    );
    final dataInicial = DateUtils.dateOnly(
      dataHoraSaida(viagem) ?? DateTime.now(),
    );
    DateTime dataSelecionada = dataInicial;

    final horarioController = TextEditingController(text: horaSaida(viagem));

    String? rotaId = viagem?['rota_id']?.toString();
    String? motoristaId = viagem?['motorista_id']?.toString();
    String? veiculoId = viagem?['veiculo_id']?.toString();
    String status = viagem?['status']?.toString() ?? 'programada';

    final passageirosAtuais = List<Map<String, dynamic>>.from(
      viagem?['viagem_passageiros'] ?? const [],
    );
    final selecionados = passageirosAtuais
        .map((registro) => registro['passageiro_id'].toString())
        .toSet();

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(nova ? 'Agendar viagem' : 'Editar viagem'),
          content: SizedBox(
            width: 620,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .72,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: rotaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Rota',
                          border: OutlineInputBorder(),
                        ),
                        items: vm.rotas
                            .map(
                              (rota) => DropdownMenuItem<String>(
                                value: rota['id'].toString(),
                                child: Text(
                                  '${rota['nome']} • ${rota['origem']} → ${rota['destino']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (valor) =>
                            valor == null ? 'Selecione uma rota' : null,
                        onChanged: (valor) => rotaId = valor,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: motoristaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Motorista',
                          border: OutlineInputBorder(),
                        ),
                        items: vm.motoristas
                            .map(
                              (motorista) => DropdownMenuItem<String>(
                                value: motorista['id'].toString(),
                                child: Text(motorista['nome'].toString()),
                              ),
                            )
                            .toList(),
                        validator: (valor) =>
                            valor == null ? 'Selecione um motorista' : null,
                        onChanged: (valor) => motoristaId = valor,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: veiculoId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Veículo',
                          border: OutlineInputBorder(),
                        ),
                        items: vm.veiculos
                            .map(
                              (veiculo) => DropdownMenuItem<String>(
                                value: veiculo['id'].toString(),
                                child: Text(
                                  '${veiculo['placa']} • ${veiculo['modelo']} (${veiculo['capacidade']} lugares)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (valor) =>
                            valor == null ? 'Selecione um veículo' : null,
                        onChanged: (valor) => veiculoId = valor,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                formatarData(dataIso(dataSelecionada)),
                              ),
                              onPressed: () async {
                                final escolhida = await showDatePicker(
                                  context: context,
                                  initialDate: dataSelecionada,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2100),
                                );
                                if (escolhida != null) {
                                  setDialogState(() {
                                    dataSelecionada = DateUtils.dateOnly(
                                      escolhida,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 125,
                            child: TextFormField(
                              controller: horarioController,
                              decoration: const InputDecoration(
                                labelText: 'Saída',
                                hintText: '06:30',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.datetime,
                              validator: (valor) =>
                                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                      .hasMatch((valor ?? '').trim())
                                  ? null
                                  : 'Use HH:mm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Status da viagem',
                          border: OutlineInputBorder(),
                        ),
                        items: statusDisponiveis
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(rotuloStatus(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) => status = valor ?? 'programada',
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Passageiros',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text('${selecionados.length} selecionado(s)'),
                        ],
                      ),
                      if (vm.passageiros.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Nenhum passageiro ativo cadastrado.'),
                        )
                      else
                        ...vm.passageiros.map(
                          (passageiro) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: selecionados.contains(
                              passageiro['id'].toString(),
                            ),
                            title: Text(passageiro['nome'].toString()),
                            onChanged: (marcado) {
                              setDialogState(() {
                                final id = passageiro['id'].toString();
                                if (marcado == true) {
                                  selecionados.add(id);
                                } else {
                                  selecionados.remove(id);
                                }
                              });
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: observacoes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop({
                  'rota_id': rotaId,
                  'motorista_id': motoristaId,
                  'veiculo_id': veiculoId,
                  'saida_prevista': timestampSaida(
                    dataSelecionada,
                    horarioController.text.trim(),
                  ),
                  'status': status,
                  'observacoes': observacoes.text.trim().isEmpty
                      ? null
                      : observacoes.text.trim(),
                  'passageiros_ids': selecionados.toList(),
                });
              },
              child: const Text('Salvar viagem'),
            ),
          ],
        ),
      ),
    );

    observacoes.dispose();
    horarioController.dispose();

    if (dados == null || !mounted) return;

    try {
      final passageirosIds = List<String>.from(
        dados.remove('passageiros_ids') as List,
      );
      await vm.salvar(
        id: viagem?['id'] as String?,
        dados: dados,
        passageirosIds: passageirosIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nova
                ? 'Viagem agendada com sucesso!'
                : 'Viagem atualizada com sucesso!',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> alterarStatus(Map<String, dynamic> viagem, String status) async {
    try {
      await vm.atualizarStatus(viagem['id'].toString(), status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status alterado para ${rotuloStatus(status)}.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> excluir(Map<String, dynamic> viagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir viagem?'),
        content: const Text(
          'A viagem e os vínculos com os passageiros serão removidos. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    try {
      await vm.excluir(viagem['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Viagem excluída.')));
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  List<Map<String, dynamic>> get viagensFiltradas {
    final termo = buscaController.text.trim().toLowerCase();
    return vm.viagens.where((viagem) {
      final status = viagem['status']?.toString() ?? 'programada';
      final rota = viagem['rotas'] as Map<String, dynamic>? ?? {};
      final motorista = viagem['motoristas'] as Map<String, dynamic>? ?? {};
      final texto = [
        rota['nome'],
        rota['origem'],
        rota['destino'],
        motorista['nome'],
        viagem['saida_prevista'],
      ].join(' ').toLowerCase();
      return (filtroStatus == 'todas' || status == filtroStatus) &&
          texto.contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, child) {
      final lista = viagensFiltradas;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onVoltar,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                ),
                const Expanded(
                  child: Text(
                    'Gerenciamento de viagens',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => abrirFormulario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agendar viagem'),
                ),
              ],
            ),
          ),
          if (vm.carregando) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _indicador('Total', vm.viagens.length, Colors.blue),
                _indicador(
                  'Agendadas',
                  vm.viagens.where((v) => v['status'] == 'programada').length,
                  Colors.blue,
                ),
                _indicador(
                  'Em andamento',
                  vm.viagens.where((v) => v['status'] == 'em_andamento').length,
                  Colors.orange,
                ),
                _indicador(
                  'Finalizadas',
                  vm.viagens.where((v) => v['status'] == 'finalizada').length,
                  Colors.green,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: buscaController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por rota, motorista ou data',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: filtroStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'todas',
                        child: Text('Todas'),
                      ),
                      ...statusDisponiveis.map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(rotuloStatus(status)),
                        ),
                      ),
                    ],
                    onChanged: (valor) =>
                        setState(() => filtroStatus = valor ?? 'todas'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _conteudo(lista)),
        ],
      );
    },
  );

  Widget _indicador(String titulo, int valor, Color cor) => Chip(
    avatar: CircleAvatar(radius: 8, backgroundColor: cor),
    label: Text('$titulo: $valor'),
  );

  Widget _conteudo(List<Map<String, dynamic>> lista) {
    if (vm.carregando && vm.viagens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.erro != null && vm.viagens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(vm.erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: vm.carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (lista.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 90),
            Icon(Icons.directions_bus_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('Nenhuma viagem encontrada.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final viagem = lista[index];
          final rota = viagem['rotas'] as Map<String, dynamic>? ?? {};
          final motorista = viagem['motoristas'] as Map<String, dynamic>? ?? {};
          final veiculo = viagem['veiculos'] as Map<String, dynamic>? ?? {};
          final passageiros = List<Map<String, dynamic>>.from(
            viagem['viagem_passageiros'] ?? const [],
          );
          final embarcados = passageiros
              .where((p) => p['embarcou'] == true)
              .length;
          final status = viagem['status']?.toString() ?? 'programada';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: corStatus(status).withValues(alpha: .12),
                child: Icon(Icons.directions_bus, color: corStatus(status)),
              ),
              title: Text(
                '${rota['nome'] ?? 'Rota não encontrada'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${rota['origem'] ?? '--'} → ${rota['destino'] ?? '--'}'
                ' • ${formatarData(dataViagem(viagem))}'
                ' • ${horaSaida(viagem)}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(rotuloStatus(status)),
                        backgroundColor: corStatus(status)
                            .withValues(alpha: .12),
                      ),
                      Chip(
                        avatar: const Icon(Icons.person_outline, size: 16),
                        label: Text(
                          motorista['nome']?.toString() ?? 'Sem motorista',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.directions_bus_outlined,
                          size: 16,
                        ),
                        label: Text(
                          veiculo['placa']?.toString() ?? 'Sem veículo',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.groups_outlined, size: 16),
                        label: Text(
                          '$embarcados/${passageiros.length} embarcados',
                        ),
                      ),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Passageiros vinculados',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (passageiros.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhum passageiro vinculado.'),
                    ),
                  )
                else
                  ...passageiros.map((registro) {
                    final pessoa =
                        registro['passageiros'] as Map<String, dynamic>? ?? {};
                    final embarcou = registro['embarcou'] == true;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        embarcou ? Icons.check_circle : Icons.schedule,
                        color: embarcou ? Colors.green : Colors.orange,
                      ),
                      title: Text(pessoa['nome']?.toString() ?? 'Passageiro'),
                      subtitle: Text(embarcou ? 'Embarcou' : 'Pendente'),
                    );
                  }),
                if ((viagem['observacoes']?.toString() ?? '').isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Observações: ${viagem['observacoes']}'),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Alterar status',
                      onSelected: (valor) => alterarStatus(viagem, valor),
                      itemBuilder: (context) => statusDisponiveis
                          .map(
                            (item) => PopupMenuItem(
                              value: item,
                              child: Text(rotuloStatus(item)),
                            ),
                          )
                          .toList(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Icon(Icons.sync_alt),
                            SizedBox(width: 4),
                            Text('Status'),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => abrirFormulario(viagem),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => excluir(viagem),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Excluir',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
