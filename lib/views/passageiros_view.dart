import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/passageiros_viewmodel.dart';

class PassageirosView extends StatefulWidget {
  final VoidCallback onVoltar;

  const PassageirosView({super.key, required this.onVoltar});

  @override
  State<PassageirosView> createState() => _PassageirosViewState();
}

class _PassageirosViewState extends State<PassageirosView> {
  final vm = PassageirosViewModel();

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
    return '$dia/$mes/' + data.year.toString();
  }

  String dataIso(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return data.year.toString() + '-$mes-$dia';
  }

  String mascararCpf(String cpf) {
    final digitos = cpf.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 11) return 'CPF não informado';
    return '***.***.***-' + digitos.substring(9);
  }

  String formatarTelefone(String telefone) {
    final digitos = telefone.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 11) {
      return '(' + digitos.substring(0, 2) + ') ' +
          digitos.substring(2, 7) + '-' + digitos.substring(7);
    }
    if (digitos.length == 10) {
      return '(' + digitos.substring(0, 2) + ') ' +
          digitos.substring(2, 6) + '-' + digitos.substring(6);
    }
    return telefone;
  }

  String formatarCep(String cep) {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 8) {
      return digitos.substring(0, 5) + '-' + digitos.substring(5);
    }
    return cep;
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
    if (primeiroDigito == 10) primeiroDigito = 0;
    if (primeiroDigito != int.parse(cpf[9])) return false;

    soma = 0;
    for (var i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    var segundoDigito = (soma * 10) % 11;
    if (segundoDigito == 10) segundoDigito = 0;
    return segundoDigito == int.parse(cpf[10]);
  }

  String mensagemErro(Object erro) {
    if (erro is PostgrestException) {
      if (erro.code == '23505') return 'Este CPF já está cadastrado.';
      if (erro.code == '42501') {
        return 'Você não tem permissão para realizar esta operação.';
      }
      if (erro.code == '23514' || erro.code == '23502') {
        return 'Confira os dados obrigatórios e tente novamente.';
      }
      if (erro.code == '42P01' || erro.code == '42703') {
        return 'A estrutura da tabela de passageiros está desatualizada. '
            'Execute a migração SQL no Supabase.';
      }
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  Future<void> abrirFormulario([Map<String, dynamic>? passageiro]) async {
    final formKey = GlobalKey<FormState>();
    final novo = passageiro == null;
    String valor(String campo) => passageiro?[campo]?.toString() ?? '';

    var nome = valor('nome');
    var cpf = valor('cpf');
    var telefone = valor('telefone');
    var email = valor('email');
    var cep = valor('cep');
    var logradouro = valor('logradouro');
    var numero = valor('numero');
    var complemento = valor('complemento');
    var bairro = valor('bairro');
    var cidade = valor('cidade');
    var uf = valor('uf');
    var nomeResponsavel = valor('nome_responsavel');
    var telefoneResponsavel = valor('telefone_responsavel');
    var observacoes = valor('observacoes');
    var ativo = passageiro?['ativo'] as bool? ?? true;
    DateTime? nascimento = DateTime.tryParse(valor('data_nascimento'));

    var nascimentoTexto = nascimento == null ? '' : formatarData(nascimento);

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final maxHeight = MediaQuery.of(dialogContext).size.height * 0.72;

          return AlertDialog(
            title: Text(novo ? 'Cadastrar passageiro' : 'Editar passageiro'),
            content: SizedBox(
              width: 580,
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
                            labelText: 'Nome completo *',
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
                            labelText: 'CPF * (11 números)',
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
                            labelText: 'Telefone com DDD *',
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
                            if (texto.isEmpty) return null;
                            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(texto)
                                ? null
                                : 'Informe um e-mail válido';
                          },
                          onChanged: (v) => email = v,
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final hoje = DateUtils.dateOnly(DateTime.now());
                            final escolhida = await showDatePicker(
                              context: dialogContext,
                              initialDate: nascimento ??
                                  DateTime(hoje.year - 18, hoje.month, hoje.day),
                              firstDate: DateTime(1900),
                              lastDate: hoje,
                            );
                            if (escolhida != null) {
                              setDialogState(() {
                                nascimento = escolhida;
                                nascimentoTexto = formatarData(escolhida);
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data de nascimento (opcional)',
                              hintText: 'Selecione a data',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_month),
                            ),
                            child: Text(
                              nascimentoTexto.isEmpty
                                  ? 'Selecione a data'
                                  : nascimentoTexto,
                              style: TextStyle(
                                color: nascimentoTexto.isEmpty
                                    ? Theme.of(dialogContext).hintColor
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Endereço',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: cep,
                          decoration: const InputDecoration(
                            labelText: 'CEP (opcional)',
                            hintText: '00000000',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          validator: (v) {
                            final digitos = (v ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            return digitos.isEmpty || digitos.length == 8
                                ? null
                                : 'O CEP deve conter 8 números';
                          },
                          onChanged: (v) => cep = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: logradouro,
                          decoration: const InputDecoration(
                            labelText: 'Rua / Avenida',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (v) => logradouro = v,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: numero,
                                decoration: const InputDecoration(
                                  labelText: 'Número',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => numero = v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: complemento,
                                decoration: const InputDecoration(
                                  labelText: 'Complemento',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => complemento = v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: bairro,
                          decoration: const InputDecoration(
                            labelText: 'Bairro',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (v) => bairro = v,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: cidade,
                                decoration: const InputDecoration(
                                  labelText: 'Cidade',
                                  border: OutlineInputBorder(),
                                ),
                                textCapitalization: TextCapitalization.words,
                                onChanged: (v) => cidade = v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: uf,
                                decoration: const InputDecoration(
                                  labelText: 'UF',
                                  border: OutlineInputBorder(),
                                ),
                                textCapitalization: TextCapitalization.characters,
                                maxLength: 2,
                                validator: (v) {
                                  final texto = (v ?? '').trim();
                                  return texto.isEmpty ||
                                          RegExp(r'^[A-Za-z]{2}$')
                                              .hasMatch(texto)
                                      ? null
                                      : 'UF inválida';
                                },
                                onChanged: (v) => uf = v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Responsável (opcional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: nomeResponsavel,
                          decoration: const InputDecoration(
                            labelText: 'Nome do responsável',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (v) => nomeResponsavel = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: telefoneResponsavel,
                          decoration: const InputDecoration(
                            labelText: 'Telefone do responsável',
                            hintText: 'DDD + número',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          validator: (v) {
                            final digitos = (v ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            return digitos.isEmpty ||
                                    digitos.length == 10 ||
                                    digitos.length == 11
                                ? null
                                : 'Informe DDD e telefone';
                          },
                          onChanged: (v) => telefoneResponsavel = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: observacoes,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (v) => observacoes = v,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<bool>(
                          initialValue: ativo,
                          decoration: const InputDecoration(
                            labelText: 'Status do passageiro',
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
                  if (!formKey.currentState!.validate()) return;

                  Navigator.of(dialogContext).pop({
                    'nome': nome.trim(),
                    'cpf': cpf.replaceAll(RegExp(r'\D'), ''),
                    'telefone': telefone.replaceAll(RegExp(r'\D'), ''),
                    'email': email.trim().isEmpty ? null : email.trim(),
                    'data_nascimento':
                        nascimento == null ? null : dataIso(nascimento!),
                    'cep': cep.replaceAll(RegExp(r'\D'), ''),
                    'logradouro': logradouro.trim(),
                    'numero': numero.trim(),
                    'complemento': complemento.trim(),
                    'bairro': bairro.trim(),
                    'cidade': cidade.trim(),
                    'uf': uf.trim().toUpperCase(),
                    'nome_responsavel': nomeResponsavel.trim(),
                    'telefone_responsavel':
                        telefoneResponsavel.replaceAll(RegExp(r'\D'), ''),
                    'observacoes': observacoes.trim(),
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

    if (dados == null || !mounted) return;

    try {
      await vm.salvar(id: passageiro?['id'] as String?, dados: dados);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novo
                ? 'Passageiro cadastrado com sucesso!'
                : 'Passageiro atualizado com sucesso!',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> confirmarExclusao(Map<String, dynamic> passageiro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir passageiro?'),
        content: Text(
          'Deseja realmente excluir o cadastro de ' +
              passageiro['nome'].toString() + '?',
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
      await vm.excluir(passageiro['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passageiro excluído com sucesso!')),
      );
    } catch (erro) {
      if (!mounted) return;
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
                'Passageiros',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => abrirFormulario(),
                icon: const Icon(Icons.add),
                label: const Text('Novo passageiro'),
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
    if (vm.carregando && vm.passageiros.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.erro != null && vm.passageiros.isEmpty) {
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

    if (vm.passageiros.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.person_outline, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('Nenhum passageiro cadastrado.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: vm.passageiros.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final passageiro = vm.passageiros[index];
          final ativo = passageiro['ativo'] as bool? ?? true;
          final telefone = passageiro['telefone']?.toString() ?? '';
          final nascimento = DateTime.tryParse(
            passageiro['data_nascimento']?.toString() ?? '',
          );
          final endereco = [
            passageiro['logradouro'],
            passageiro['numero'],
            passageiro['bairro'],
            passageiro['cidade'],
            passageiro['uf'],
          ]
              .where((parte) => (parte?.toString() ?? '').trim().isNotEmpty)
              .join(', ');

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(ativo ? Icons.person : Icons.person_off_outlined),
              ),
              title: Text(
                passageiro['nome']?.toString() ?? 'Passageiro sem nome',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CPF: ' +
                          mascararCpf(passageiro['cpf']?.toString() ?? '') +
                          '  •  ' +
                          formatarTelefone(telefone),
                    ),
                    if ((passageiro['email']?.toString() ?? '').isNotEmpty)
                      Text('E-mail: ' + passageiro['email'].toString()),
                    if (nascimento != null)
                      Text('Nascimento: ' + formatarData(nascimento)),
                    if (endereco.isNotEmpty) Text('Endereço: ' + endereco),
                    if ((passageiro['cep']?.toString() ?? '').isNotEmpty)
                      Text(
                        'CEP: ' + formatarCep(passageiro['cep'].toString()),
                      ),
                    if ((passageiro['nome_responsavel']?.toString() ?? '')
                        .isNotEmpty)
                      Text(
                        'Responsável: ' +
                            passageiro['nome_responsavel'].toString(),
                      ),
                    if ((passageiro['telefone_responsavel']?.toString() ?? '')
                        .isNotEmpty)
                      Text(
                        'Telefone do responsável: ' +
                            formatarTelefone(
                              passageiro['telefone_responsavel'].toString(),
                            ),
                      ),
                    if ((passageiro['observacoes']?.toString() ?? '').isNotEmpty)
                      Text(
                        'Observações: ' + passageiro['observacoes'].toString(),
                      ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(ativo ? 'Ativo' : 'Inativo'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Editar passageiro',
                    onPressed: () => abrirFormulario(passageiro),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Excluir passageiro',
                    onPressed: () => confirmarExclusao(passageiro),
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
