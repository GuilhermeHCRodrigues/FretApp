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
    if (erro is PostgrestException) {
      if (erro.code == '23505') {
        return 'Essa placa já está cadastrada.';
      }

      if (erro.code == '42501') {
        return 'Você não tem permissão para realizar essa operação.';
      }
    }

    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  Future<void> abrirFormulario([
    Map<String, dynamic>? veiculo,
  ]) async {
    final formKey = GlobalKey<FormState>();

    var placa = veiculo?['placa']?.toString() ?? '';
    var modelo = veiculo?['modelo']?.toString() ?? '';
    var capacidade =
        veiculo?['capacidade']?.toString() ?? '';

    // O diálogo devolve os dados. A operação no Supabase acontece
    // somente depois que o diálogo é fechado.
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            veiculo == null ? 'Cadastrar veículo' : 'Editar veículo',
          ),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: placa,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      hintText: 'ABC1D23',
                    ),
                    onChanged: (valor) => placa = valor,
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
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: modelo,
                    decoration: const InputDecoration(
                      labelText: 'Modelo',
                      hintText: 'Ex.: Mercedes-Benz OF-1721',
                    ),
                    onChanged: (valor) => modelo = valor,
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe o modelo';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: capacidade,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacidade',
                      hintText: 'Ex.: 40',
                    ),
                    onChanged: (valor) => capacidade = valor,
                    validator: (valor) {
                      final numero = int.tryParse(
                        (valor ?? '').trim(),
                      );

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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'placa': placa.trim().toUpperCase(),
                  'modelo': modelo.trim(),
                  'capacidade': int.parse(capacidade.trim()),
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (dados == null || !mounted) return;

    try {
      await vm.salvar(
        id: veiculo?['id'] as String?,
        placa: dados['placa'] as String,
        modelo: dados['modelo'] as String,
        capacidade: dados['capacidade'] as int,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            veiculo == null
                ? 'Veículo cadastrado com sucesso!'
                : 'Veículo atualizado com sucesso!',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(erro))),
      );
    }
  }

  Future<void> confirmarExclusao(
    Map<String, dynamic> veiculo,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir veículo?'),
          content: Text(
            'Deseja realmente excluir o veículo '
            '${veiculo['placa']} - ${veiculo['modelo']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    try {
      await vm.excluir(veiculo['id'] as String);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veículo excluído com sucesso!'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(erro))),
      );
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
                    tooltip: 'Voltar',
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
                    label: const Text('Novo veículo'),
                  ),
                ],
              ),
            ),
            if (vm.carregando) const LinearProgressIndicator(),
            Expanded(
              child: _construirConteudo(),
            ),
          ],
        );
      },
    );
  }

  Widget _construirConteudo() {
    if (vm.carregando && vm.veiculos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (vm.erro != null && vm.veiculos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                vm.erro!,
                textAlign: TextAlign.center,
              ),
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

    if (vm.veiculos.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.directions_bus_outlined,
              size: 56,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(
              child: Text('Nenhum veículo cadastrado.'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: vm.veiculos.length,
        itemBuilder: (context, index) {
          final veiculo = vm.veiculos[index];

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.directions_bus),
              ),
              title: Text(
                '${veiculo['placa']} - ${veiculo['modelo']}',
              ),
              subtitle: Text(
                '${veiculo['capacidade']} lugares',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Editar veículo',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => abrirFormulario(veiculo),
                  ),
                  IconButton(
                    tooltip: 'Excluir veículo',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => confirmarExclusao(veiculo),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
