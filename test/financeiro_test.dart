import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/situacao_financeira.dart';
import 'package:fretapp/services/mensalidade_servico.dart';
import 'package:fretapp/tema/app_tema.dart';
import 'package:fretapp/viewmodels/financeiro_viewmodel.dart';
import 'package:fretapp/views/financeiro_view.dart';

final hoje = DateTime(2026, 11, 15);

Map<String, dynamic> perfil(String id, String nome) => {
  'id': id,
  'nome_completo': nome,
  'telefone': '11988887777',
  'instituicao': 'UMC',
};

Map<String, dynamic> mensalidade(
  String perfilId,
  String status, {
  String vencimento = '2026-11-10',
  int valor = 20000,
  List<Map<String, dynamic>> pagamentos = const [],
}) => {
  'id': 'm-$perfilId',
  'passageiro_id': perfilId,
  'valor_centavos': valor,
  'vencimento': vencimento,
  'status': status,
  'pagamentos': pagamentos,
};

/// Ana pagou, Bruno atrasado (vencida), Carla a vencer, Davi não assinou
/// (em aberto), Eva cancelada, Fábio só tem cadastro (sem login).
final dadosExemplo = DadosFinanceiros(
  valorPadraoCentavos: 20000,
  perfis: [
    perfil('ana', 'Ana Souza'),
    perfil('bruno', 'Bruno Lima'),
    perfil('carla', 'Carla Dias'),
    perfil('davi', 'Davi Rocha'),
    perfil('eva', 'Eva Melo'),
  ],
  cadastros: [
    {
      'id': 'c1',
      'nome': 'Ana Souza Cadastro',
      'telefone': '11911112222',
      'perfil_id': 'ana',
    },
    {
      'id': 'c2',
      'nome': 'Fábio Nunes',
      'telefone': '11933334444',
      'perfil_id': null,
    },
  ],
  mensalidades: [
    mensalidade(
      'ana',
      'paga',
      pagamentos: [
        {'status': 'rejeitado', 'pago_em': null},
        {'status': 'aprovado', 'pago_em': '2026-11-05T13:00:00Z'},
      ],
    ),
    mensalidade('bruno', 'vencida'),
    mensalidade('carla', 'pendente', vencimento: '2026-11-20', valor: 18000),
    mensalidade('eva', 'cancelada'),
  ],
  assinaturas: [
    {'passageiro_id': 'ana', 'status': 'active'},
    {'passageiro_id': 'bruno', 'status': 'past_due'},
  ],
);

void main() {
  group('montarLinhas', () {
    final linhas = montarLinhas(dadosExemplo, hoje);
    LinhaFinanceira de(String nomeInicio) =>
        linhas.firstWhere((l) => l.nome.startsWith(nomeInicio));

    test('uma linha por pessoa, em ordem alfabética', () {
      expect(linhas.map((l) => l.nome), [
        'Ana Souza Cadastro',
        'Bruno Lima',
        'Carla Dias',
        'Davi Rocha',
        'Eva Melo',
        'Fábio Nunes',
      ]);
    });

    test('situação de cada passageiro no mês', () {
      expect(de('Ana').situacao, SituacaoPagamento.pago);
      expect(de('Bruno').situacao, SituacaoPagamento.atrasado);
      expect(de('Carla').situacao, SituacaoPagamento.pendente);
      expect(de('Davi').situacao, SituacaoPagamento.emAberto);
      expect(de('Eva').situacao, SituacaoPagamento.cancelada);
      expect(de('Fábio').situacao, SituacaoPagamento.semAcesso);
    });

    test('cadastro do administrador tem prioridade no nome e telefone', () {
      final ana = de('Ana');
      expect(ana.telefone, '11911112222');
      expect(ana.perfilId, 'ana');
      expect(ana.statusAssinatura, 'active');
    });

    test('pago em = último pagamento aprovado', () {
      expect(de('Ana').pagoEm, DateTime.utc(2026, 11, 5, 13).toLocal());
      expect(de('Bruno').pagoEm, isNull);
    });

    test('pendente com vencimento passado conta como atrasado', () {
      final s = situacaoDaMensalidade(
        mensalidade('x', 'pendente', vencimento: '2026-11-14'),
        hoje,
      );
      expect(s, SituacaoPagamento.atrasado);
      expect(
        situacaoDaMensalidade(
          mensalidade('x', 'pendente', vencimento: '2026-11-15'),
          hoje,
        ),
        SituacaoPagamento.pendente,
      );
    });

    test('resumo do mês', () {
      final r = ResumoFinanceiro.de(linhas);
      expect(r.total, 6);
      expect(r.pagaram, 1);
      expect(r.naoPagaram, 4); // Bruno, Carla, Davi, Fábio
      expect(r.atrasados, 1);
      expect(r.recebidoCentavos, 20000);
      // Bruno 200 + Carla 180 + Davi 200 (valor vigente) + Fábio 200.
      expect(r.emAbertoCentavos, 78000);
    });

    test('todo cadastrado deve o valor vigente, mesmo sem cobrança', () {
      final davi = de('Davi');
      expect(davi.valorCentavos, 20000);
      expect(davi.vencimento, isNull);
      expect(davi.vencimentoTexto, 'Ao assinar');
      expect(davi.situacao.naoPagou, isTrue);

      final fabio = de('Fábio');
      expect(fabio.valorCentavos, 20000);
      expect(fabio.situacao, SituacaoPagamento.semAcesso);
    });

    test('assinatura em vigor sem cobrança no mês vence na renovação', () {
      final linhas = montarLinhas(
        DadosFinanceiros(
          perfis: [perfil('gil', 'Gil')],
          assinaturas: [
            {
              'passageiro_id': 'gil',
              'status': 'active',
              'periodo_fim': '2026-11-25T03:00:00Z',
            },
          ],
        ),
        hoje,
        valorPadraoCentavos: 25000,
      );
      final gil = linhas.single;
      expect(gil.situacao, SituacaoPagamento.pendente);
      expect(gil.valorCentavos, 25000);
      expect(gil.vencimento, DateTime.utc(2026, 11, 25, 3).toLocal());
    });

    test('sem assinatura o rótulo é "Não assinou"', () {
      expect(statusAssinatura(null).rotulo, 'Não assinou');
    });
  });

  group('filtro de status', () {
    test('cada filtro aceita as situações certas', () {
      expect(SituacaoPagamento.values.where(FiltroPagamento.pagaram.aceita), [
        SituacaoPagamento.pago,
      ]);
      expect(
        SituacaoPagamento.values.where(FiltroPagamento.naoPagaram.aceita),
        [
          SituacaoPagamento.pendente,
          SituacaoPagamento.atrasado,
          SituacaoPagamento.emAberto,
          SituacaoPagamento.semAcesso,
        ],
      );
      expect(SituacaoPagamento.values.where(FiltroPagamento.atrasados.aceita), [
        SituacaoPagamento.atrasado,
      ]);
      expect(
        SituacaoPagamento.values.where(FiltroPagamento.todos.aceita),
        SituacaoPagamento.values,
      );
    });

    test('formatação de moeda e mês', () {
      expect(formatarCentavos(20000), r'R$ 200,00');
      expect(formatarCentavos(123456789), r'R$ 1.234.567,89');
      expect(formatarCentavos(5), r'R$ 0,05');
      expect(formatarCompetencia(DateTime(2026, 3)), 'março de 2026');
    });
  });

  group('FinanceiroViewModel', () {
    test('consulta a competência atual e navega entre meses', () async {
      final pedidos = <DateTime>[];
      final vm = FinanceiroViewModel(
        agora: () => hoje,
        fonte: (mes) async {
          pedidos.add(mes);
          return dadosExemplo;
        },
      );
      addTearDown(vm.dispose);

      await vm.carregar();
      await vm.mudarMes(-1);
      await vm.mudarMes(2);
      expect(pedidos, [
        DateTime(2026, 11),
        DateTime(2026, 10),
        DateTime(2026, 12),
      ]);
    });

    test('filtra por status e busca sem acento', () async {
      final vm = FinanceiroViewModel(
        agora: () => hoje,
        fonte: (_) async => dadosExemplo,
      );
      addTearDown(vm.dispose);
      await vm.carregar();

      vm.filtrar(FiltroPagamento.pagaram);
      expect(vm.linhasFiltradas.map((l) => l.nome), ['Ana Souza Cadastro']);

      vm.filtrar(FiltroPagamento.naoPagaram);
      expect(vm.linhasFiltradas, hasLength(4));
      expect(vm.contar(FiltroPagamento.naoPagaram), 4);

      vm.buscar('fabio');
      expect(vm.linhasFiltradas.map((l) => l.nome), ['Fábio Nunes']);
    });

    test('erro de conexão vira mensagem', () async {
      final vm = FinanceiroViewModel(
        agora: () => hoje,
        fonte: (_) async => throw Exception('offline'),
      );
      addTearDown(vm.dispose);
      await vm.carregar();
      expect(vm.erro, 'Não foi possível conectar ao Supabase.');
      expect(vm.carregando, isFalse);
    });
  });

  group('valor digitado', () {
    test('aceita formatos brasileiros', () {
      expect(centavosDoTexto('250'), 25000);
      expect(centavosDoTexto('250,5'), 25050);
      expect(centavosDoTexto('250,50'), 25050);
      expect(centavosDoTexto('1.250,00'), 125000);
      expect(centavosDoTexto(r'R$ 199,90'), 19990);
    });

    test('recusa o que não é valor', () {
      for (final texto in ['', 'abc', '250,505', '12.5', '1.25,00', '-10']) {
        expect(centavosDoTexto(texto), isNull, reason: texto);
      }
    });
  });

  group('tela', () {
    late List<(int, bool)> alteracoes;

    Future<FinanceiroViewModel> abrir(
      WidgetTester tester,
      Size tamanho, {
      int assinaturas = 3,
      Object? erroAlterar,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = tamanho;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      alteracoes = [];
      // Stripe falso: lembra o valor alterado, como o real.
      var valorAtual = 20000;
      final vm = FinanceiroViewModel(
        agora: () => hoje,
        fonte: (_) async => dadosExemplo,
        consultarValor: () async => ValorMensalidade(
          valorCentavos: valorAtual,
          assinaturas: assinaturas,
        ),
        alterarValor: (valor, aplicar) async {
          if (erroAlterar != null) throw erroAlterar;
          alteracoes.add((valor, aplicar));
          valorAtual = valor;
          return ResultadoAlteracao(
            valorCentavos: valor,
            atualizadas: aplicar ? assinaturas : 0,
          );
        },
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTema.claro,
          home: Scaffold(body: FinanceiroView(modelo: vm)),
        ),
      );
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('desktop mostra a tabela e filtra quem não pagou', (
      tester,
    ) async {
      await abrir(tester, const Size(1366, 900));

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('novembro de 2026'), findsOneWidget);
      expect(find.text('1 de 6'), findsOneWidget);
      for (final coluna in [
        'Passageiro',
        'Assinatura',
        'Vencimento',
        'Status',
      ]) {
        expect(find.text(coluna), findsOneWidget);
      }
      expect(find.text('Bruno Lima'), findsOneWidget);

      await tester.tap(find.text('Pagaram (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza Cadastro'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsNothing);

      await tester.tap(find.text('Não pagaram (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza Cadastro'), findsNothing);
      expect(find.text('Bruno Lima'), findsOneWidget);
      expect(find.text('Fábio Nunes'), findsOneWidget);
      expect(find.text('Eva Melo'), findsNothing);

      await tester.tap(find.text('Atrasados (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Bruno Lima'), findsOneWidget);
      expect(find.text('Carla Dias'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('celular usa cartões e não estoura', (tester) async {
      await abrir(tester, const Size(360, 780));
      expect(find.byType(DataTable), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Ana Souza Cadastro'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ana Souza Cadastro'), findsOneWidget);
      expect(find.text('Atrasado'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busca sem resultado mostra estado vazio', (tester) async {
      await abrir(tester, const Size(1366, 900));
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Ninguém neste filtro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tela estreita com fonte ampliada não estoura', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester, const Size(320, 640));
      expect(find.text('Alterar valor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mostra o valor atual do Stripe', (tester) async {
      await abrir(tester, const Size(1366, 900));
      expect(find.text('Mensalidade no Stripe'), findsOneWidget);
      expect(find.text(r'R$ 200,00 / mês'), findsOneWidget);
      expect(find.text('3 assinaturas em vigor'), findsOneWidget);
    });

    testWidgets('altera o valor e aplica às assinaturas atuais', (
      tester,
    ) async {
      await abrir(tester, const Size(1366, 900));
      await tester.tap(find.text('Alterar valor'));
      await tester.pumpAndSettle();

      final campo = find.widgetWithText(TextFormField, 'Novo valor mensal');
      expect(tester.widget<TextFormField>(campo).controller!.text, '200,00');

      // Mesmo valor e valor inválido não passam.
      await tester.tap(find.text('Alterar no Stripe'));
      await tester.pump();
      expect(find.text('Este já é o valor atual'), findsOneWidget);
      await tester.enterText(campo, 'abc');
      await tester.tap(find.text('Alterar no Stripe'));
      await tester.pump();
      expect(find.text('Informe um valor, ex.: 250,00'), findsOneWidget);

      await tester.enterText(campo, '230,00');
      await tester.pump();
      expect(find.textContaining('Pix Automático'), findsNothing);
      expect(
        find.text('Aplicar também às 3 assinaturas atuais'),
        findsOneWidget,
      );
      await tester.tap(find.text('Alterar no Stripe'));
      await tester.pumpAndSettle();

      expect(alteracoes, [(23000, true)]);
      expect(find.text('Alterar valor da mensalidade'), findsNothing);
      expect(find.textContaining('Mensalidade alterada para'), findsOneWidget);
      expect(find.text(r'R$ 230,00 / mês'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('só para novas assinaturas quando desmarcado', (tester) async {
      await abrir(tester, const Size(1366, 900));
      await tester.tap(find.text('Alterar valor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Novo valor mensal'),
        '180',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Alterar no Stripe'));
      await tester.pumpAndSettle();
      expect(alteracoes, [(18000, false)]);
    });

    testWidgets('acima de R\$ 250 avisa sobre o Pix Automático', (
      tester,
    ) async {
      await abrir(tester, const Size(1366, 900));
      await tester.tap(find.text('Alterar valor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Novo valor mensal'),
        '300,00',
      );
      await tester.pump();
      expect(find.textContaining('Pix Automático'), findsOneWidget);

      // Desmarcando (só novas assinaturas), o aviso some.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(find.textContaining('Pix Automático'), findsNothing);
    });

    testWidgets('erro do Stripe fica no diálogo', (tester) async {
      await abrir(
        tester,
        const Size(1366, 900),
        erroAlterar: const MensalidadeException('Stripe fora do ar.'),
      );
      await tester.tap(find.text('Alterar valor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Novo valor mensal'),
        '210',
      );
      await tester.tap(find.text('Alterar no Stripe'));
      await tester.pumpAndSettle();
      expect(find.text('Stripe fora do ar.'), findsOneWidget);
      expect(find.text('Alterar valor da mensalidade'), findsOneWidget);
    });

    testWidgets('sem assinaturas, a opção de aplicar fica desativada', (
      tester,
    ) async {
      await abrir(tester, const Size(1366, 900), assinaturas: 0);
      await tester.tap(find.text('Alterar valor'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma assinatura em vigor'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });
  });
}
