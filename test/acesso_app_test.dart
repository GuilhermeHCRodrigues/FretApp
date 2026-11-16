import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/services/acesso_servico.dart';
import 'package:fretapp/tema/app_tema.dart';
import 'package:fretapp/views/widgets/acesso_app.dart';

void main() {
  group('senha provisória', () {
    test('tem 10 caracteres, letra, número e nada ambíguo', () {
      for (var i = 0; i < 200; i++) {
        final senha = gerarSenhaProvisoria();
        expect(senha, hasLength(10));
        expect(senha, matches(RegExp(r'[a-zA-Z]')));
        expect(senha, matches(RegExp(r'[0-9]')));
        expect(senha, isNot(matches(RegExp(r'[0O1lI]'))));
        expect(RegrasAcesso.validarSenha(senha), isNull);
      }
    });

    test('não se repete', () {
      final senhas = {for (var i = 0; i < 50; i++) gerarSenhaProvisoria()};
      expect(senhas, hasLength(50));
    });
  });

  group('regras de acesso', () {
    test('e-mail é obrigatório e precisa ser válido', () {
      expect(RegrasAcesso.validarEmail(''), isNotNull);
      expect(RegrasAcesso.validarEmail('motorista'), isNotNull);
      expect(RegrasAcesso.validarEmail('motorista@fretapp'), isNotNull);
      expect(RegrasAcesso.validarEmail(' motorista@fretapp.com.br '), isNull);
    });

    test('senha entre 8 e 72 caracteres', () {
      expect(RegrasAcesso.validarSenha('1234567'), isNotNull);
      expect(RegrasAcesso.validarSenha('12345678'), isNull);
      expect(RegrasAcesso.validarSenha('a' * 73), isNotNull);
    });

    test('tipos gravados em perfis', () {
      expect(TipoAcesso.motorista.valor, 'motorista');
      expect(TipoAcesso.passageiro.valor, 'passageiro');
    });
  });

  testWidgets('campos validam e o botão gera outra senha', (tester) async {
    final form = GlobalKey<FormState>();
    var email = '';
    var senha = '';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.claro,
        home: Scaffold(
          body: Form(
            key: form,
            child: CamposAcesso(
              senhaInicial: 'abc',
              aoMudar: (e, s) {
                email = e;
                senha = s;
              },
            ),
          ),
        ),
      ),
    );
    // Já informa os valores iniciais.
    expect(senha, 'abc');

    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Informe o e-mail de acesso'), findsOneWidget);
    expect(find.text('Use pelo menos 8 caracteres'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail de acesso'),
      'motorista@fretapp.com.br',
    );
    await tester.tap(find.byTooltip('Gerar nova senha'));
    await tester.pump();
    expect(email, 'motorista@fretapp.com.br');
    expect(senha, hasLength(10));
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('sem senha inicial, gera uma senha provisória', (tester) async {
    var senha = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CamposAcesso(aoMudar: (_, s) => senha = s)),
      ),
    );
    expect(senha, hasLength(10));
    expect(RegrasAcesso.validarSenha(senha), isNull);
  });

  // Regressão: o formulário de motorista quebrava com "_dependents.isEmpty"
  // ao salvar, porque descartava os controladores com o diálogo ainda
  // animando o fechamento.
  testWidgets('salvar o formulário com o campo focado não quebra', (
    tester,
  ) async {
    (String, String)? salvo;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                var email = '';
                var senha = '';
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    content: CamposAcesso(
                      aoMudar: (e, s) {
                        email = e;
                        senha = s;
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) salvo = (email, senha);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail de acesso'),
      'motorista@fretapp.com.br',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(salvo?.$1, 'motorista@fretapp.com.br');
    expect(salvo?.$2, hasLength(10));
  });

  testWidgets('credenciais criadas mostram e-mail e senha', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => mostrarCredenciaisCriadas(
                  context,
                  tipo: TipoAcesso.motorista,
                  email: 'motorista@fretapp.com.br',
                  senha: 'Ab3dEf7hJk',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso criado'), findsOneWidget);
    expect(find.text('motorista@fretapp.com.br'), findsOneWidget);
    expect(find.text('Ab3dEf7hJk'), findsOneWidget);

    await tester.tap(find.text('Copiar'));
    await tester.pump();
    expect(find.text('Dados de acesso copiados.'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso criado'), findsNothing);
  });
}
