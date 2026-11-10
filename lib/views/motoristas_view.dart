import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/motoristas_viewmodel.dart';

class MotoristasView extends StatefulWidget {
  final VoidCallback onVoltar;

  const MotoristasView({super.key, required this.onVoltar});

  @override
  State<MotoristasView> createState() => _MotoristasViewState();
}

class _MotoristasViewState extends State<MotoristasView> {
  final vm = MotoristasViewModel();

  static const categoriasCnh = [
    'ACC',
    'A',
    'B',
    'C',
    'D',
    'E',
    'AB',
    'AC',
    'AD',
    'AE',
  ];

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

  String formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '${dia}/${mes}/${data.year}';
  }

  String dataIso(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '${data.year}-${mes}-${dia}';
  }

  String mascararCpf(String cpf) {
    final digitos = cpf.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 11) {
      return 'CPF não informado';
    }
    return '***.***.***-${digitos.substring(9)}';
  }

  String mascararCnh(String cnh) {
    final digitos = cnh.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 4) {
      return 'Não informado';
    }
    return '•••••••${digitos.substring(digitos.length - 4)}';
  }

  String formatarTelefone(String telefone) {
    final digitos = telefone.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 11) {
      return '(${digitos.substring(0, 2)}) '
          '${digitos.substring(2, 7)}-${digitos.substring(7)}';
    }
    if (digitos.length == 10) {
      return '(${digitos.substring(0, 2)}) '
          '${digitos.substring(2, 6)}-${digitos.substring(6)}';
    }
    return telefone;
  }

  bool cpfValido(String valor) {
    final cpf = valor.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return false;
    }

    var soma = 0;
    for (var i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    var primeiroDigito = (soma * 10) % 11;
    if (primeiroDigito == 10) {
      primeiroDigito = 0;
    }
    if (primeiroDigito != int.parse(cpf[9])) {
      return false;
    }

    soma = 0;
    for (var i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    var segundoDigito = (soma * 10) % 11;
    if (segundoDigito == 10) {
      segundoDigito = 0;
    }
    return segundoDigito == int.parse(cpf[10]);
  }

  String mensagemErro(Object erro) {
    if (erro is PostgrestException) {
      if (erro.code == '23505') {
        return 'Este CPF ou número de CNH já está cadastrado.';
      }
      if (erro.code == '42501') {
        return 'Você não tem permissão para realizar esta operação.';
      }
      if (erro.code == '23514' || erro.code == '23502') {
        return 'Confira os dados obrigatórios e tente novamente.';
      }
      if (erro.code == '42P01' || erro.code == '42703') {
        return 'A estrutura da tabela de motoristas está desatualizada. '
            'Execute a migração SQL no Supabase.';
      }
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  Future<void> abrirFormulario([Map<String, dynamic>? motorista]) async {
    final formKey = GlobalKey<FormState>();
    final novo = motorista == null;
    String valor(String campo) => motorista?[campo]?.toString() ?? '';

    var nome = valor('nome');
    var cpf = valor('cpf');
    var telefone = valor('telefone');
    var email = valor('email');
    var cnhNumero = valor('cnh_numero');
    var cnhCategoria = valor('cnh_categoria');
    var ativo = motorista?['ativo'] as bool? ?? true;
    DateTime? validadeCnh = DateTime.tryParse(valor('cnh_validade'));
    final validadeController = TextEditingController(
      text: validadeCnh == null ? '' : formatarData(validadeCnh!),
    );

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final maxHeight = MediaQuery.of(dialogContext).size.height * 0.68;

          return AlertDialog(
            title: Text(novo ? 'Cadastrar motorista' : 'Editar motorista'),
            content: SizedBox(
              width: 540,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Dados pessoais',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: nome,
                          decoration: const InputDecoration(
                            labelText: 'Nome completo',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v == null || v.trim().length < 3
                              ? 'Informe o nome completo'
                              : null,
                          onChanged: (v) => nome = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: cpf,
                          decoration: const InputDecoration(
                            labelText: 'CPF (11 números)',
                            hintText: 'Somente números',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          validator: (v) => cpfValido(v ?? '')
                              ? null
                              : 'Informe um CPF válido',
                          onChanged: (v) => cpf = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: telefone,
                          decoration: const InputDecoration(
                            labelText: 'Telefone com DDD',
                            hintText: '11999999999',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          validator: (v) {
                            final digitos = (v ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            return digitos.length == 10 || digitos.length == 11
                                ? null
                                : 'Informe DDD e telefone';
                          },
                          onChanged: (v) => telefone = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: email,
                          decoration: const InputDecoration(
                            labelText: 'E-mail (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final texto = (v ?? '').trim();
                            if (texto.isEmpty) {
                              return null;
                            }
                            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(texto)
                                ? null
                                : 'Informe um e-mail válido';
                          },
                          onChanged: (v) => email = v,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Carteira Nacional de Habilitação (CNH)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: cnhNumero,
                          decoration: const InputDecoration(
                            labelText: 'Número da CNH (11 números)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          validator: (v) {
                            final digitos = (v ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            return RegExp(r'^[0-9]{11}$').hasMatch(digitos)
                                ? null
                                : 'A CNH deve conter 11 números';
                          },
                          onChanged: (v) => cnhNumero = v,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: categoriasCnh.contains(cnhCategoria)
                              ? cnhCategoria
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Categoria da CNH',
                            border: OutlineInputBorder(),
                          ),
                          items: categoriasCnh
                              .map(
                                (categoria) => DropdownMenuItem(
                                  value: categoria,
                                  child: Text(categoria),
                                ),
                              )
                              .toList(),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Selecione a categoria da CNH'
                              : null,
                          onChanged: (v) => cnhCategoria = v ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: validadeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Validade da CNH',
                            hintText: 'Selecione a data',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          validator: (v) => validadeCnh == null
                              ? 'Selecione a validade da CNH'
                              : null,
                          onTap: () async {
                            final hoje = DateUtils.dateOnly(DateTime.now());
                            final escolhida = await showDatePicker(
                              context: dialogContext,
                              initialDate: validadeCnh ?? hoje,
                              firstDate: DateTime(1950),
                              lastDate: hoje.add(
                                const Duration(days: 365 * 20),
                              ),
                            );
                            if (escolhida != null) {
                              setDialogState(() {
                                validadeCnh = escolhida;
                                validadeController.text = formatarData(
                                  escolhida,
                                );
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<bool>(
                          initialValue: ativo,
                          decoration: const InputDecoration(
                            labelText: 'Status do motorista',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('Ativo')),
                            DropdownMenuItem(
                              value: false,
                              child: Text('Inativo'),
                            ),
                          ],
                          onChanged: (v) => ativo = v ?? true,
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
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  Navigator.of(dialogContext).pop({
                    'nome': nome.trim(),
                    'cpf': cpf.replaceAll(RegExp(r'\D'), ''),
                    'telefone': telefone.replaceAll(RegExp(r'\D'), ''),
                    'email': email.trim().isEmpty ? null : email.trim(),
                    'cnh_numero': cnhNumero.replaceAll(RegExp(r'\D'), ''),
                    'cnh_categoria': cnhCategoria,
                    'cnh_validade': dataIso(validadeCnh!),
                    'ativo': ativo,
                  });
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    validadeController.dispose();

    if (dados == null || !mounted) {
      return;
    }

    try {
      await vm.salvar(id: motorista?['id'] as String?, dados: dados);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novo
                ? 'Motorista cadastrado com sucesso!'
                : 'Motorista atualizado com sucesso!',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> confirmarExclusao(Map<String, dynamic> motorista) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir motorista?'),
        content: Text(
          'Deseja realmente excluir o cadastro de ${motorista['nome']}?',
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

    if (confirmar != true || !mounted) {
      return;
    }

    try {
      await vm.excluir(motorista['id'] as String);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motorista excluído com sucesso!')),
      );
    } catch (erro) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
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
              IconButton(
                onPressed: widget.onVoltar,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
              ),
              const Text(
                'Motoristas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => abrirFormulario(),
                icon: const Icon(Icons.add),
                label: const Text('Novo motorista'),
              ),
            ],
          ),
        ),
        if (vm.carregando) const LinearProgressIndicator(),
        Expanded(child: conteudo()),
      ],
    ),
  );

  Widget conteudo() {
    if (vm.carregando && vm.motoristas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.erro != null && vm.motoristas.isEmpty) {
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

    if (vm.motoristas.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.people_outline, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('Nenhum motorista cadastrado.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: vm.motoristas.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final motorista = vm.motoristas[index];
          final validade = DateTime.tryParse(
            motorista['cnh_validade']?.toString() ?? '',
          );
          final cnhVencida =
              validade != null &&
              DateUtils.dateOnly(validade)
                  .isBefore(DateUtils.dateOnly(DateTime.now()));
          final ativo = motorista['ativo'] as bool? ?? true;
          final telefone = motorista['telefone']?.toString() ?? '';

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(ativo ? Icons.person : Icons.person_off_outlined),
              ),
              title: Text(
                motorista['nome']?.toString() ?? 'Motorista sem nome',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CPF: ${mascararCpf(motorista['cpf']?.toString() ?? '')}'
                      '  •  ${formatarTelefone(telefone)}',
                    ),
                    if ((motorista['email']?.toString() ?? '').isNotEmpty)
                      Text('E-mail: ${motorista['email']}'),
                    Text(
                      'CNH: ${mascararCnh(motorista['cnh_numero']?.toString() ?? '')}'
                      '  •  Categoria ${motorista['cnh_categoria']}',
                    ),
                    Text(
                      'Validade: ${validade == null ? 'Não informada' : formatarData(validade)}',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(ativo ? 'Ativo' : 'Inativo'),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (cnhVencida)
                          const Chip(
                            label: Text('CNH vencida'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Editar motorista',
                    onPressed: () => abrirFormulario(motorista),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Excluir motorista',
                    onPressed: () => confirmarExclusao(motorista),
                    icon: const Icon(Icons.delete_outline),
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
