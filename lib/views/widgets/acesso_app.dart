import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/acesso_servico.dart';

/// Senha provisória legível (sem 0/O, 1/l/I) para o administrador repassar.
String gerarSenhaProvisoria([int tamanho = 10]) {
  const letras = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
  const numeros = '23456789';
  const todos = '$letras$numeros';
  final aleatorio = Random.secure();
  String de(String fonte) => fonte[aleatorio.nextInt(fonte.length)];

  // Garante ao menos uma letra e um número.
  final caracteres = [
    de(letras),
    de(numeros),
    for (var i = 2; i < tamanho; i++) de(todos),
  ]..shuffle(aleatorio);
  return caracteres.join();
}

/// Campos "E-mail de acesso" + "Senha provisória" usados nos formulários.
///
/// Os controladores pertencem a este widget e são descartados junto com ele.
/// Quem usa recebe os valores por [aoMudar]. (Descartar um controlador logo
/// após o `showDialog` retornar quebra o app: o diálogo ainda está na
/// animação de fechar e continua usando o controlador.)
class CamposAcesso extends StatefulWidget {
  const CamposAcesso({
    super.key,
    required this.aoMudar,
    this.emailInicial = '',
    this.senhaInicial,
    this.habilitado = true,
  });

  /// Chamado na criação e a cada alteração, com e-mail e senha atuais.
  final void Function(String email, String senha) aoMudar;
  final String emailInicial;

  /// Sem valor, gera uma senha provisória.
  final String? senhaInicial;
  final bool habilitado;

  @override
  State<CamposAcesso> createState() => _CamposAcessoState();
}

class _CamposAcessoState extends State<CamposAcesso> {
  late final _email = TextEditingController(text: widget.emailInicial);
  late final _senha = TextEditingController(
    text: (widget.senhaInicial?.isNotEmpty ?? false)
        ? widget.senhaInicial
        : gerarSenhaProvisoria(),
  );
  var _senhaVisivel = true;

  void _avisar() => widget.aoMudar(_email.text, _senha.text);

  @override
  void initState() {
    super.initState();
    _email.addListener(_avisar);
    _senha.addListener(_avisar);
    _avisar();
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _email,
          enabled: widget.habilitado,
          decoration: const InputDecoration(
            labelText: 'E-mail de acesso',
            hintText: 'nome@fretapp.com.br',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.alternate_email),
          ),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          validator: RegrasAcesso.validarEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _senha,
          enabled: widget.habilitado,
          obscureText: !_senhaVisivel,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Senha provisória',
            helperText: 'Repasse ao usuário; mínimo de 8 caracteres.',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                  onPressed: () =>
                      setState(() => _senhaVisivel = !_senhaVisivel),
                  icon: Icon(
                    _senhaVisivel
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Gerar nova senha',
                  onPressed: widget.habilitado
                      ? () => _senha.text = gerarSenhaProvisoria()
                      : null,
                  icon: const Icon(Icons.autorenew),
                ),
              ],
            ),
          ),
          validator: RegrasAcesso.validarSenha,
        ),
      ],
    );
  }
}

/// Diálogo para criar o acesso de um cadastro que ainda não tem login.
///
/// Retorna `true` se a conta foi criada.
Future<bool> mostrarDialogoCriarAcesso(
  BuildContext context, {
  required TipoAcesso tipo,
  required String cadastroId,
  required String nome,
  String? emailInicial,
}) async {
  final criado = await showDialog<(String, String)>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCriarAcesso(
      tipo: tipo,
      cadastroId: cadastroId,
      nome: nome,
      emailInicial: emailInicial,
    ),
  );
  if (criado == null || !context.mounted) return false;
  await mostrarCredenciaisCriadas(
    context,
    tipo: tipo,
    email: criado.$1,
    senha: criado.$2,
  );
  return true;
}

class _DialogoCriarAcesso extends StatefulWidget {
  const _DialogoCriarAcesso({
    required this.tipo,
    required this.cadastroId,
    required this.nome,
    this.emailInicial,
  });

  final TipoAcesso tipo;
  final String cadastroId;
  final String nome;
  final String? emailInicial;

  @override
  State<_DialogoCriarAcesso> createState() => _DialogoCriarAcessoState();
}

class _DialogoCriarAcessoState extends State<_DialogoCriarAcesso> {
  final _form = GlobalKey<FormState>();
  var _email = '';
  var _senha = '';
  var _enviando = false;
  String? _erro;

  Future<void> _criar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await criarAcesso(
        tipo: widget.tipo,
        cadastroId: widget.cadastroId,
        email: _email,
        senha: _senha,
      );
      if (!mounted) return;
      Navigator.of(context).pop((_email.trim().toLowerCase(), _senha));
    } on AcessoException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Criar acesso ao app'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.nome} vai entrar com este e-mail e já verá a '
                  'tela de ${widget.tipo.rotulo}.',
                ),
                const SizedBox(height: 16),
                CamposAcesso(
                  emailInicial: widget.emailInicial ?? '',
                  habilitado: !_enviando,
                  aoMudar: (email, senha) {
                    _email = email;
                    _senha = senha;
                  },
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(_erro!, style: TextStyle(color: cores.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _enviando ? null : _criar,
          icon: _enviando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: const Text('Criar acesso'),
        ),
      ],
    );
  }
}

/// Mostra e-mail e senha recém-criados para o administrador repassar.
Future<void> mostrarCredenciaisCriadas(
  BuildContext context, {
  required TipoAcesso tipo,
  required String email,
  required String senha,
}) {
  final tema = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.check_circle, color: tema.colorScheme.primary, size: 40),
      title: const Text('Acesso criado'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Envie estes dados ao ${tipo.rotulo}. No primeiro login, a '
              'tela de ${tipo.rotulo} abre automaticamente.',
            ),
            const SizedBox(height: 16),
            _LinhaCredencial(rotulo: 'E-mail', valor: email),
            const SizedBox(height: 8),
            _LinhaCredencial(rotulo: 'Senha provisória', valor: senha),
            const SizedBox(height: 12),
            Text(
              'A senha não fica salva no painel. Anote agora.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: 'E-mail: $email\nSenha: $senha'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dados de acesso copiados.')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Concluir'),
        ),
      ],
    ),
  );
}

class _LinhaCredencial extends StatelessWidget {
  const _LinhaCredencial({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: tema.textTheme.labelSmall),
          SelectableText(
            valor,
            style: tema.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Selo exibido no card do cadastro: com ou sem acesso ao app.
class SeloAcesso extends StatelessWidget {
  const SeloAcesso({super.key, required this.temAcesso});

  final bool temAcesso;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        temAcesso ? Icons.verified_user_outlined : Icons.no_accounts_outlined,
        size: 18,
        color: temAcesso ? cores.primary : cores.onSurfaceVariant,
      ),
      label: Text(temAcesso ? 'Acesso ao app' : 'Sem acesso ao app'),
      visualDensity: VisualDensity.compact,
    );
  }
}
