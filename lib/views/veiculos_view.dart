
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../viewmodels/veiculos_viewmodel.dart';

class VeiculosView extends StatefulWidget {
  final VoidCallback onVoltar;

  const VeiculosView({
    super.key,
    required this.onVoltar,
  });

  @override
  State<VeiculosView> createState() => _VeiculosViewState();
}

class _VeiculosViewState extends State<VeiculosView> {
  final vm = VeiculosViewModel();

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
    if (erro is PostgrestException && erro.code == '23505') {
      return 'Essa placa já está cadastrada.';
    }
    return 'Não foi possível concluir a operação.';
  }

  Future<void> abrirFormulario([
    Map<String, dynamic>? veiculo,
  ]) async {
    final placa = TextEditingController(
      text: veiculo?['placa'] ?? '',
    );
    final modelo = TextEditingController(
      text: veiculo?['modelo'] ?? '',
    );
    final capacidade = TextEditingController(
      text: veiculo?['capacidade']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    final sucesso = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizarDialogo) {
          return AlertDialog(
            title: Text(
              veiculo == null
                  ? 'Cadastrar veículo'
                  : 'Editar veículo',
            ),
            content: SizedBox(
              width: 360,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: placa,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Placa',
                        hintText: 'ABC1D23',
                      ),
                      validator: (valor) {
                        final texto =
                            (valor ?? '').trim().toUpperCase();

                        if (!RegExp(
                          r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$',
                        ).hasMatch(texto)) {
                          return 'Informe uma placa válida';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: modelo,
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        hintText: 'Mercedes-Benz',
                      ),
                      validator: (valor) =>
                          (valor ?? '').trim().isEmpty
                              ? 'Informe o modelo'
                              : null,
                    ),
                    TextFormField(
                      controller: capacidade,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacidade',
                        hintText: '40',
                      ),
                      validator: (valor) {
                        final numero =
                            int.tryParse((valor ?? '').trim());
                        if (numero == null ||
                            numero < 1 ||
                            numero > 100) {
                          return 'Informe de 1 a 100 lugares';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: salvando
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: salvando
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        atualizarDialogo(() => salvando = true);

                        try {
                          await vm.salvar(
                            id: veiculo?['id'] as String?,
                            placa: placa.text,
                            modelo: modelo.text,
                            capacidade:
                                int.parse(capacidade.text.trim()),
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (erro) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext)
                                .showSnackBar(
                              SnackBar(
                                content: Text(mensagemErro(erro)),
                              ),
                            );

                            atualizarDialogo(
                              () => salvando = false,
                            );
                          }
                        }
                      },
                child: Text(
                  salvando ? 'Salvando...' : 'Salvar',
                ),
              ),
            ],
          );
        },
      ),
    );

    placa.dispose();
    modelo.dispose();
    capacidade.dispose();

    if (sucesso == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veículo salvo com sucesso!'),
        ),
      );
    }
  }

  Future<void> confirmarExclusao(
    Map<String, dynamic> veiculo,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: Text(
          'Deseja excluir a placa ${veiculo['placa']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await vm.excluir(veiculo['id'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo excluído!'),
          ),
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro(erro))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onVoltar,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'Veículos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => abrirFormulario(),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo'),
                  ),
                ],
              ),
            ),
            if (vm.carregando)
              const LinearProgressIndicator(),
            if (vm.erro != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(vm.erro!),
                    TextButton(
                      onPressed: vm.carregar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: vm.veiculos.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum veículo cadastrado.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: vm.veiculos.length,
                      itemBuilder: (context, index) {
                        final veiculo = vm.veiculos[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                            ),
                            title: Text(
                              '${veiculo['placa']} - '
                              '${veiculo['modelo']}',
                            ),
                            subtitle: Text(
                              '${veiculo['capacidade']} lugares',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      abrirFormulario(veiculo),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      confirmarExclusao(veiculo),
                                ),
                              ],
                            ),
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
}
