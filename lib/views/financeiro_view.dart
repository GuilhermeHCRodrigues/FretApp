import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/financeiro_viewmodel.dart';

class FinanceiroView extends StatefulWidget {
  const FinanceiroView({super.key, required this.onVoltar});
  final VoidCallback onVoltar;

  @override
  State<FinanceiroView> createState() => _FinanceiroViewState();
}

class _FinanceiroViewState extends State<FinanceiroView> {
  final vm = FinanceiroViewModel();
  DateTime competencia = DateTime(DateTime.now().year, DateTime.now().month);
  String filtro = 'todas';

  @override
  void initState() {
    super.initState();
    vm.carregar(competencia: competencia);
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  String moeda(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  String mesLabel(DateTime data) =>
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
  String dataLabel(String data) {
    final d = DateTime.parse(data);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> gerarMensalidades() async {
    final valorController = TextEditingController();
    final descricaoController = TextEditingController(
      text: 'Mensalidade de transporte',
    );
    DateTime vencimento = DateTime(competencia.year, competencia.month, 10);
    final formKey = GlobalKey<FormState>();
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gerar mensalidades'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Competência: ${mesLabel(competencia)}'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: valorController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor por passageiro (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return n == null || n <= 0
                          ? 'Informe um valor válido.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vencimento'),
                    subtitle: Text(dataLabel(vencimento.toIso8601String())),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: vencimento,
                        firstDate: DateTime(
                          competencia.year,
                          competencia.month,
                          1,
                        ),
                        lastDate: DateTime(
                          competencia.year,
                          competencia.month + 1,
                          0,
                        ),
                      );
                      if (data != null) setDialogState(() => vencimento = data);
                    },
                  ),
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Será criada uma cobrança para cada passageiro ativo. Cobranças já existentes nessa competência serão preservadas.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'valor': double.parse(
                    valorController.text.replaceAll(',', '.'),
                  ),
                  'vencimento': vencimento,
                  'descricao': descricaoController.text.trim(),
                });
              },
              child: const Text('Gerar'),
            ),
          ],
        ),
      ),
    );
    valorController.dispose();
    descricaoController.dispose();
    if (resultado == null || !mounted) return;
    try {
      await vm.gerarMensalidades(
        competencia: competencia,
        vencimento: resultado['vencimento'] as DateTime,
        valor: resultado['valor'] as double,
        descricao: (resultado['descricao'] as String).isEmpty
            ? null
            : resultado['descricao'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mensalidades geradas. Cobranças existentes foram mantidas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar mensalidades: $e')),
      );
    }
  }

  Future<void> registrarPagamento(Map<String, dynamic> mensalidade) async {
    final valorController = TextEditingController(
      text: vm.saldo(mensalidade).toStringAsFixed(2),
    );
    final observacaoController = TextEditingController();
    String forma = 'pix';
    final formKey = GlobalKey<FormState>();
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Registrar pagamento — ${mensalidade['passageiros']?['nome'] ?? 'Passageiro'}',
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Saldo em aberto: ${moeda(vm.saldo(mensalidade))}'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: valorController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor recebido (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (n == null || n <= 0)
                        return 'Informe um valor válido.';
                      if (n > vm.saldo(mensalidade) + 0.009)
                        return 'O valor excede o saldo em aberto.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: forma,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pix', child: Text('Pix')),
                      DropdownMenuItem(
                        value: 'dinheiro',
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferência'),
                      ),
                      DropdownMenuItem(value: 'cartao', child: Text('Cartão')),
                      DropdownMenuItem(value: 'outro', child: Text('Outro')),
                    ],
                    onChanged: (v) => setDialogState(() => forma = v ?? 'pix'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacaoController,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'valor': double.parse(
                    valorController.text.replaceAll(',', '.'),
                  ),
                  'forma': forma,
                  'observacao': observacaoController.text.trim(),
                });
              },
              child: const Text('Confirmar recebimento'),
            ),
          ],
        ),
      ),
    );
    valorController.dispose();
    observacaoController.dispose();
    if (resultado == null || !mounted) return;
    try {
      await vm.registrarPagamento(
        mensalidadeId: mensalidade['id'].toString(),
        valor: resultado['valor'] as double,
        formaPagamento: resultado['forma'] as String,
        observacao: (resultado['observacao'] as String).isEmpty
            ? null
            : resultado['observacao'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pagamento registrado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar o pagamento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) {
      final lista = vm.mensalidades.where((m) {
        final s = vm.status(m);
        return filtro == 'todas' || filtro == s;
      }).toList();
      final total = vm.mensalidades.fold<double>(
        0,
        (a, m) => a + (m['valor'] as num).toDouble(),
      );
      final recebido = vm.mensalidades.fold<double>(
        0,
        (a, m) => a + vm.recebido(m),
      );
      final pendente = vm.mensalidades.fold<double>(
        0,
        (a, m) => a + vm.saldo(m),
      );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onVoltar,
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Text(
                    'Financeiro',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => setState(() {
                    competencia = DateTime(
                      competencia.year,
                      competencia.month - 1,
                    );
                    vm.carregar(competencia: competencia);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  mesLabel(competencia),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => setState(() {
                    competencia = DateTime(
                      competencia.year,
                      competencia.month + 1,
                    );
                    vm.carregar(competencia: competencia);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: gerarMensalidades,
                  icon: const Icon(Icons.post_add),
                  label: const Text('Gerar mensalidades'),
                ),
              ],
            ),
          ),
          if (vm.carregando) const LinearProgressIndicator(),
          if (vm.erro != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(vm.erro!, style: const TextStyle(color: Colors.red)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _resumo('Cobrado', moeda(total), Icons.receipt_long),
                _resumo('Recebido', moeda(recebido), Icons.payments_outlined),
                _resumo('Em aberto', moeda(pendente), Icons.pending_actions),
                _resumo(
                  'Mensalidades',
                  '${vm.mensalidades.length}',
                  Icons.people_alt_outlined,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Text('Exibir: '),
                DropdownButton<String>(
                  value: filtro,
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'pendente',
                      child: Text('Pendentes'),
                    ),
                    DropdownMenuItem(value: 'parcial', child: Text('Parciais')),
                    DropdownMenuItem(
                      value: 'atrasada',
                      child: Text('Atrasadas'),
                    ),
                    DropdownMenuItem(value: 'paga', child: Text('Pagas')),
                  ],
                  onChanged: (v) => setState(() => filtro = v ?? 'todas'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => vm.carregar(competencia: competencia),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.carregando && vm.mensalidades.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma mensalidade nesta competência. Gere as mensalidades para começar.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final m = lista[index];
                      final nome =
                          m['passageiros']?['nome']?.toString() ?? 'Passageiro';
                      final status = vm.status(m);
                      final saldo = vm.saldo(m);
                      final cor = status == 'paga'
                          ? Colors.green
                          : status == 'atrasada'
                          ? Colors.red
                          : status == 'parcial'
                          ? Colors.orange
                          : Colors.blue;
                      final pagamentos = List<Map<String, dynamic>>.from(
                        m['pagamentos'] ?? const [],
                      );
                      return Card(
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: cor.withValues(alpha: .12),
                            child: Icon(Icons.person_outline, color: cor),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${moeda((m['valor'] as num).toDouble())} • Vencimento ${dataLabel(m['vencimento'].toString())} • ${status.toUpperCase()}',
                          ),
                          trailing: saldo > 0.009
                              ? TextButton(
                                  onPressed: () => registrarPagamento(m),
                                  child: const Text('Registrar pagamento'),
                                )
                              : const Chip(label: Text('Quitada')),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            12,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Recebido: ${moeda(vm.recebido(m))}   |   Saldo: ${moeda(saldo)}',
                              ),
                            ),
                            if (pagamentos.isEmpty)
                              const ListTile(
                                title: Text('Nenhum pagamento registrado.'),
                              )
                            else
                              ...pagamentos.map(
                                (p) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.payments_outlined),
                                  title: Text(
                                    moeda((p['valor'] as num).toDouble()),
                                  ),
                                  subtitle: Text(
                                    '${dataLabel(p['pago_em'].toString())} • ${p['forma_pagamento']}',
                                  ),
                                ),
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

  Widget _resumo(String titulo, String valor, IconData icone) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icone, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.grey)),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
