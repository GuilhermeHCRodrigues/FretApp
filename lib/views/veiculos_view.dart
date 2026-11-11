import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/veiculos_viewmodel.dart';

class VeiculosView extends StatefulWidget {
  final VoidCallback onVoltar;
  const VeiculosView({super.key, required this.onVoltar});

  @override
  State<VeiculosView> createState() => _VeiculosViewState();
}

class _VeiculosViewState extends State<VeiculosView> {
  final vm = VeiculosViewModel();

  static const ufs = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];
  static const tipos = ['Ônibus', 'Micro-ônibus', 'Van', 'Carro', 'Outro'];
  static const combustiveis = [
    'Diesel',
    'Gasolina',
    'Etanol',
    'Flex',
    'GNV',
    'Elétrico',
    'Híbrido',
    'Outro',
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

  String mensagemErro(Object erro) {
    if (erro is PostgrestException) {
      if (erro.code == '23505') return 'Essa placa já está cadastrada.';
      if (erro.code == '42501') {
        return 'Você não tem permissão para realizar essa operação.';
      }
      if (erro.code == '42703') {
        return 'Os campos novos ainda não existem no Supabase. Execute a migração SQL.';
      }
      if (erro.code == '23514') {
        return 'Um dos dados informados não passou na validação do banco.';
      }
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  Widget secao(String titulo) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        titulo,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget texto({
    required String label,
    required String initial,
    required ValueChanged<String> changed,
    String? hint,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) => TextFormField(
    initialValue: initial,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: maxLength == null ? null : '',
    ),
    keyboardType: keyboard,
    textCapitalization: capitalization,
    maxLength: maxLength,
    maxLines: maxLines,
    onChanged: changed,
    validator: validator,
  );

  String? obrigatorio(String? v, String campo, bool novo) =>
      novo && (v == null || v.trim().isEmpty) ? 'Informe $campo' : null;

  Future<void> abrirFormulario([Map<String, dynamic>? veiculo]) async {
    final formKey = GlobalKey<FormState>();
    final novo = veiculo == null;
    String valor(String campo) => veiculo?[campo]?.toString() ?? '';

    var placa = valor('placa'),
        marca = valor('marca'),
        modelo = valor('modelo');
    var anoFabricacao = valor('ano_fabricacao'),
        anoModelo = valor('ano_modelo');
    var cor = valor('cor'),
        capacidade = valor('capacidade'),
        tipo = valor('tipo');
    var chassi = valor('chassi_final'), motor = valor('motor_final');
    var renavam = valor('renavam'), uf = valor('uf').toUpperCase();
    var municipio = valor('municipio'), km = valor('quilometragem');
    var combustivel = valor('combustivel'), observacoes = valor('observacoes');
    var ativo = veiculo?['ativo'] as bool? ?? true;

    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.68;
        return AlertDialog(
          title: Text(novo ? 'Cadastrar veículo' : 'Editar veículo'),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      secao('Identificação'),
                      texto(
                        label: 'Marca',
                        initial: marca,
                        changed: (v) => marca = v,
                        capitalization: TextCapitalization.words,
                        validator: (v) => obrigatorio(v, 'a marca', novo),
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Modelo',
                        initial: modelo,
                        changed: (v) => modelo = v,
                        capitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o modelo'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Ano de fabricação',
                        initial: anoFabricacao,
                        changed: (v) => anoFabricacao = v,
                        keyboard: TextInputType.number,
                        maxLength: 4,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) {
                            return novo ? 'Informe o ano de fabricação' : null;
                          }
                          final n = int.tryParse(t);
                          return n == null ||
                                  n < 1900 ||
                                  n > DateTime.now().year + 1
                              ? 'Informe um ano válido'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Ano-modelo',
                        initial: anoModelo,
                        changed: (v) => anoModelo = v,
                        keyboard: TextInputType.number,
                        maxLength: 4,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) {
                            return novo ? 'Informe o ano-modelo' : null;
                          }
                          final n = int.tryParse(t),
                              f = int.tryParse(anoFabricacao.trim());
                          if (n == null ||
                              n < 1900 ||
                              n > DateTime.now().year + 1) {
                            return 'Informe um ano válido';
                          }
                          if (f != null && (n < f || n > f + 1)) {
                            return 'Use o ano de fabricação ou o seguinte';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Cor',
                        initial: cor,
                        changed: (v) => cor = v,
                        capitalization: TextCapitalization.words,
                        validator: (v) => obrigatorio(v, 'a cor', novo),
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Placa',
                        initial: placa,
                        changed: (v) => placa = v,
                        capitalization: TextCapitalization.characters,
                        maxLength: 7,
                        hint: 'ABC1D23',
                        validator: (v) =>
                            RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$')
                                .hasMatch((v ?? '').trim().toUpperCase())
                            ? null
                            : 'Informe uma placa válida',
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Capacidade de passageiros',
                        initial: capacidade,
                        changed: (v) => capacidade = v,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null || n < 1 || n > 100
                              ? 'Informe de 1 a 100 lugares'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: tipos.contains(tipo) ? tipo : null,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de veículo',
                          border: OutlineInputBorder(),
                        ),
                        items: tipos
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => tipo = v ?? '',
                      ),
                      secao('Identificação documental'),
                      texto(
                        label: 'Final do chassi (7 caracteres)',
                        initial: chassi,
                        changed: (v) => chassi = v,
                        capitalization: TextCapitalization.characters,
                        maxLength: 7,
                        validator: (v) {
                          final t = (v ?? '').trim().toUpperCase();
                          return t.isEmpty ||
                                  RegExp(r'^[A-Z0-9]{7}$').hasMatch(t)
                              ? null
                              : 'Informe exatamente 7 letras ou números';
                        },
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Final do motor (7 caracteres)',
                        initial: motor,
                        changed: (v) => motor = v,
                        capitalization: TextCapitalization.characters,
                        maxLength: 7,
                        validator: (v) {
                          final t = (v ?? '').trim().toUpperCase();
                          return t.isEmpty ||
                                  RegExp(r'^[A-Z0-9]{7}$').hasMatch(t)
                              ? null
                              : 'Informe exatamente 7 letras ou números';
                        },
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'RENAVAM (11 números)',
                        initial: renavam,
                        changed: (v) => renavam = v,
                        keyboard: TextInputType.number,
                        maxLength: 11,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          return t.isEmpty || RegExp(r'^[0-9]{11}$').hasMatch(t)
                              ? null
                              : 'O RENAVAM deve ter 11 números';
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: ufs.contains(uf) ? uf : null,
                        decoration: const InputDecoration(
                          labelText: 'UF de registro',
                          border: OutlineInputBorder(),
                        ),
                        items: ufs
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => uf = v ?? '',
                        validator: (v) => novo && (v == null || v.isEmpty)
                            ? 'Selecione a UF'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      texto(
                        label: 'Município de registro',
                        initial: municipio,
                        changed: (v) => municipio = v,
                        capitalization: TextCapitalization.words,
                        validator: (v) => obrigatorio(v, 'o município', novo),
                      ),
                      secao('Informações operacionais'),
                      texto(
                        label: 'Quilometragem atual',
                        initial: km,
                        changed: (v) => km = v,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          final n = int.tryParse(t);
                          return t.isEmpty || (n != null && n >= 0)
                              ? null
                              : 'Informe uma quilometragem válida';
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: combustiveis.contains(combustivel)
                            ? combustivel
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Combustível',
                          border: OutlineInputBorder(),
                        ),
                        items: combustiveis
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => combustivel = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<bool>(
                        initialValue: ativo,
                        decoration: const InputDecoration(
                          labelText: 'Status do veículo',
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
                      const SizedBox(height: 12),
                      texto(
                        label: 'Observações',
                        initial: observacoes,
                        changed: (v) => observacoes = v,
                        maxLength: 500,
                        maxLines: 3,
                        hint: 'Informações adicionais',
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
                  'placa': placa.trim().toUpperCase(),
                  'marca': marca.trim().isEmpty ? null : marca.trim(),
                  'modelo': modelo.trim(),
                  'ano_fabricacao': int.tryParse(anoFabricacao.trim()),
                  'ano_modelo': int.tryParse(anoModelo.trim()),
                  'cor': cor.trim().isEmpty ? null : cor.trim(),
                  'capacidade': int.parse(capacidade.trim()),
                  'tipo': tipo.isEmpty ? null : tipo,
                  'chassi_final': chassi.trim().isEmpty
                      ? null
                      : chassi.trim().toUpperCase(),
                  'motor_final': motor.trim().isEmpty
                      ? null
                      : motor.trim().toUpperCase(),
                  'renavam': renavam.trim().isEmpty ? null : renavam.trim(),
                  'uf': uf.isEmpty ? null : uf,
                  'municipio': municipio.trim().isEmpty
                      ? null
                      : municipio.trim(),
                  'quilometragem': int.tryParse(km.trim()),
                  'combustivel': combustivel.isEmpty ? null : combustivel,
                  'observacoes': observacoes.trim().isEmpty
                      ? null
                      : observacoes.trim(),
                  'ativo': ativo,
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
      await vm.salvar(id: veiculo?['id'] as String?, dados: dados);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novo
                ? 'Veículo cadastrado com sucesso!'
                : 'Veículo atualizado com sucesso!',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemErro(erro))));
    }
  }

  Future<void> confirmarExclusao(Map<String, dynamic> veiculo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir veículo?'),
        content: Text(
          'Deseja realmente excluir o veículo ${veiculo['placa']} - ${veiculo['modelo']}?',
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
      await vm.excluir(veiculo['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo excluído com sucesso!')),
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
                'Veículos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
        Expanded(child: conteudo()),
      ],
    ),
  );

  Widget conteudo() {
    if (vm.carregando && vm.veiculos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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

    if (vm.veiculos.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.directions_bus_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('Nenhum veículo cadastrado.')),
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
          final v = vm.veiculos[index];
          final nome = [
            v['marca'],
            v['modelo'],
          ].where((x) => x != null && x.toString().trim().isNotEmpty).join(' ');
          final detalhes = <String>[
            '${v['capacidade']} lugares',
            if (v['tipo'] != null) v['tipo'].toString(),
            if (v['ano_modelo'] != null) 'Ano-modelo ${v['ano_modelo']}',
            if (v['cor'] != null) v['cor'].toString(),
            if (v['municipio'] != null) '${v['municipio']}/${v['uf'] ?? ''}',
            if (v['quilometragem'] != null) '${v['quilometragem']} km',
            (v['ativo'] as bool? ?? true) ? 'Ativo' : 'Inativo',
          ];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.directions_bus)),
              title: Text(
                '${nome.isEmpty ? v['modelo'] : nome} • ${v['placa']}',
              ),
              subtitle: Text(detalhes.join(' • ')),
              isThreeLine: detalhes.length > 3,
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Editar veículo',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => abrirFormulario(v),
                  ),
                  IconButton(
                    tooltip: 'Excluir veículo',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => confirmarExclusao(v),
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
