import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/tema/app_tema.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';
import 'package:fretapp/views/motorista_view.dart';
import 'package:fretapp/models/posicao_motorista.dart';
import 'package:fretapp/models/viagem_do_dia.dart';
import 'package:fretapp/views/widgets/mapa_motorista.dart';

const _viagem = 'viagem-teste';
const _enquete = [
  PassageiroViagem(
    id: 'ana',
    viagemId: _viagem,
    nome: 'Ana Exemplo',
    trajeto: 'ida_volta',
  ),
  PassageiroViagem(
    id: 'bruno',
    viagemId: _viagem,
    nome: 'Bruno Exemplo',
    trajeto: 'ida',
  ),
  PassageiroViagem(
    id: 'carla',
    viagemId: _viagem,
    nome: 'Carla Exemplo',
    trajeto: 'volta',
  ),
];

final viagemTeste = ViagemDoDia(
  id: 'v-teste',
  status: 'programada',
  saidaPrevista: DateTime(2026, 11, 12, 18),
  origem: 'Delegacia de Santa Isabel',
  destino: 'UMC',
  placa: 'ABC1D23',
  modeloVeiculo: 'MPOLO VIAGGIO R',
);

MotoristaViewModel modeloTeste({
  bool permitirLocalizacao = true,
  List<PassageiroViagem> enquete = _enquete,
  bool falhar = false,
  List<(String, String)>? statusGravados,
}) => MotoristaViewModel(
  viagemId: _viagem,
  viagemInicial: viagemTeste,
  atualizarStatus: statusGravados == null
      ? null
      : (id, status) async => statusGravados.add((id, status)),
  fontePassageiros: (_) async {
    if (falhar) throw Exception('falha simulada');
    return enquete;
  },
  solicitarLocalizacao: () async => permitirLocalizacao,
);

Future<MotoristaViewModel> abrirTela(
  WidgetTester tester,
  Size tamanho, {
  MotoristaViewModel? modelo,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamanho;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final m = modelo ?? modeloTeste();
  addTearDown(m.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.claro,
      home: MotoristaView(modelo: m, onSair: () async {}),
    ),
  );
  await assentar(tester);
  return m;
}

/// Avança animações por tempo fixo. Não usa pumpAndSettle porque o
/// indicador "Buscando sinal de GPS…" gira sem parar nos testes (sem GPS).
Future<void> assentar(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tocar(WidgetTester tester, Finder controle) async {
  await tester.ensureVisible(controle);
  await assentar(tester);
  await tester.tap(controle);
  await assentar(tester);
}

Finder botaoPrincipal() => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        const {
          'Iniciar viagem',
          'Viagem em andamento',
          'Nova viagem',
        }.contains(widget.data),
  ),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

Finder destino(String nome) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is NavigationBar || widget is NavigationRail,
  ),
  matching: find.text(nome),
);

void main() {
  const celular = Size(390, 844);
  const tablet = Size(768, 1024);
  const antesDoDesktop = Size(899, 768);
  const desktopMinimo = Size(900, 768);
  const notebook = Size(1366, 768);
  const monitor = Size(1920, 1080);

  for (final tamanho in [
    celular,
    tablet,
    antesDoDesktop,
    desktopMinimo,
    notebook,
    monitor,
  ]) {
    testWidgets(
      'painel ocupa a tela toda e navega em ${tamanho.width} × ${tamanho.height}',
      (tester) async {
        await abrirTela(tester, tamanho);
        expect(tester.takeException(), isNull);

        // Sem "caixa" centralizada: o Scaffold encosta nas bordas.
        final area = tester.getRect(find.byType(Scaffold).first);
        expect(area.left, 0);
        expect(area.width, tamanho.width);

        final mapa = tester.getRect(find.byType(MapaMotorista));
        final viagem = tester.getRect(find.text('Próxima viagem'));
        expect(viagem.bottom, lessThan(mapa.top));

        final desktop = tamanho.width >= AppBreakpoints.desktop;
        if (desktop) {
          final trilho = find.byType(NavigationRail);
          expect(tester.widget<NavigationRail>(trilho).destinations, hasLength(4));
          expect(tester.getRect(trilho).left, 0);
          expect(find.text('ÁREA DO MOTORISTA'), findsOneWidget);
          expect(find.text('Sair da conta'), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.text('Ver passageiros'), findsOneWidget);
        } else {
          expect(find.byType(NavigationRail), findsNothing);
          final barra = tester.getRect(find.byType(NavigationBar));
          expect(barra.bottom, tamanho.height);
          expect(find.byType(AppBar), findsOneWidget);
          expect(find.text('Ver passageiros'), findsNothing);
        }

        await tocar(tester, destino('Passageiros'));
        expect(find.text('Ana Exemplo'), findsOneWidget);
        expect(find.text('Ida e volta'), findsOneWidget);
        await tocar(tester, destino('Avisos'));
        expect(find.text('Nenhum aviso'), findsOneWidget);
        await tocar(tester, destino('Perfil'));
        expect(find.text('Sair'), findsOneWidget);
        await tocar(tester, destino('Início'));
        expect(find.text('Próxima viagem'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a lista vem da enquete do dia, com contadores', (tester) async {
    await abrirTela(tester, notebook);
    expect(find.bySemanticsLabel('Total: 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Pendentes: 3'), findsOneWidget);

    await tocar(tester, find.text('Ver passageiros'));
    for (final nome in ['Ana Exemplo', 'Bruno Exemplo', 'Carla Exemplo']) {
      expect(find.text(nome), findsOneWidget);
    }
    expect(find.text('Só ida'), findsOneWidget);
    expect(find.text('Só volta'), findsOneWidget);

    await tocar(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('bruno')),
        matching: find.text('Confirmar'),
      ),
    );
    expect(find.text('Embarcou'), findsOneWidget);
    expect(find.bySemanticsLabel('Embarcados: 1'), findsOneWidget);
  });

  testWidgets('sem respostas na enquete mostra estado vazio', (tester) async {
    await abrirTela(tester, celular, modelo: modeloTeste(enquete: const []));
    await tocar(tester, destino('Passageiros'));
    expect(find.text('Ninguém confirmou presença hoje'), findsOneWidget);
  });

  testWidgets('erro ao buscar a enquete oferece "Tentar de novo"', (
    tester,
  ) async {
    await abrirTela(tester, celular, modelo: modeloTeste(falhar: true));
    await tocar(tester, destino('Passageiros'));
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('localização negada não inicia a viagem', (tester) async {
    await abrirTela(
      tester,
      celular,
      modelo: modeloTeste(permitirLocalizacao: false),
    );
    expect(find.text('Será solicitada ao iniciar a viagem'), findsOneWidget);
    await tocar(tester, find.text('Iniciar viagem'));
    expect(find.text('Localização não permitida'), findsOneWidget);
    expect(find.text('Iniciar viagem'), findsOneWidget);
    expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isTrue);
    expect(tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('Finalizar viagem'), matching: find.byType(OutlinedButton)),
    ).enabled, isFalse);
  });

  testWidgets('fluxo completo e os botões voltam ao estado original', (
    tester,
  ) async {
    await abrirTela(tester, notebook);
    final aviso = find.descendant(
      of: find.ancestor(
        of: find.text('Último aviso'),
        matching: find.byType(Card),
      ),
      matching: find.byType(Text),
    );
    String ultimoAviso() => tester.widget<Text>(aviso.last).data!;

    await tocar(tester, find.text('Iniciar viagem'));
    expect(find.text('Localização compartilhada'), findsOneWidget);
    expect(find.text('Viagem em andamento'), findsOneWidget);
    expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isFalse);
    expect(ultimoAviso(), 'Viagem iniciada.');

    expect(find.text('Estou saindo'), findsNothing);
    expect(find.text('Cheguei ao ponto'), findsNothing);
    await tocar(tester, find.text('Finalizar viagem'));
    expect(ultimoAviso(), 'Viagem finalizada.');
    expect(find.text('Viagem encerrada'), findsOneWidget);

    await tocar(tester, find.text('Nova viagem'));
    expect(find.text('Próxima viagem'), findsOneWidget);
    expect(find.text('Iniciar viagem'), findsOneWidget);
    expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redimensionar preserva aba, busca, embarques e viagem', (
    tester,
  ) async {
    await abrirTela(tester, celular);
    await tocar(tester, find.text('Iniciar viagem'));
    await tocar(tester, destino('Passageiros'));
    final busca = find.byType(TextField);
    await tester.enterText(busca, 'bruno');
    await assentar(tester);
    await tocar(tester, find.text('Confirmar'));

    for (final tamanho in [notebook, monitor, celular]) {
      tester.view.physicalSize = tamanho;
      await assentar(tester);
      expect(tester.widget<TextField>(busca).controller!.text, 'bruno');
      expect(find.text('Bruno Exemplo'), findsOneWidget);
      expect(find.text('Embarcou'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tocar(tester, destino('Início'));
    expect(find.text('Viagem em andamento'), findsOneWidget);
  });

  testWidgets('em tela estreita com fonte ampliada não estoura o layout', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrirTela(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Finalizar viagem'));
    await assentar(tester);
    await tocar(tester, destino('Passageiros'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem localização o mapa convida a compartilhar', (tester) async {
    await abrirTela(tester, celular);
    expect(
      find.text('Compartilhe sua localização para ver o mapa'),
      findsOneWidget,
    );
    await tocar(tester, find.text('Compartilhar localização'));
    // Permitido, mas sem leitura de GPS ainda (o teste não tem GPS).
    expect(find.text('Buscando sinal de GPS…'), findsOneWidget);
    expect(find.text('Localização compartilhada'), findsOneWidget);
    expect(find.text('Iniciar viagem'), findsOneWidget);
  });

  testWidgets('mapa mostra o veículo e o botão Centralizar após arrastar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = celular;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTema.claro,
        home: const Scaffold(
          body: MapaMotorista(
            urlTiles: null,
            posicao: PosicaoMotorista(-23.5, -46.6, rumo: 90),
            rastro: [
              PosicaoMotorista(-23.501, -46.6),
              PosicaoMotorista(-23.5, -46.6),
            ],
          ),
        ),
      ),
    );
    await assentar(tester);
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.text('Centralizar'), findsNothing);

    await tester.drag(find.byType(MapaMotorista), const Offset(-120, 0));
    await assentar(tester);
    expect(find.text('Centralizar'), findsOneWidget);
    await tester.tap(find.text('Centralizar'));
    await assentar(tester);
    expect(find.text('Centralizar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartão mostra os dados reais da viagem programada', (
    tester,
  ) async {
    await abrirTela(tester, notebook);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('Delegacia de Santa Isabel'), findsOneWidget);
    expect(find.text('VIAGGIO R · ABC-1D23'), findsOneWidget);
    expect(find.text('Ônibus 12'), findsNothing);
  });

  testWidgets('sem viagem programada hoje não deixa iniciar', (tester) async {
    final modelo = MotoristaViewModel(
      fonteViagem: () async => null,
      solicitarLocalizacao: () async => true,
    );
    await abrirTela(tester, celular, modelo: modelo);
    await modelo.carregarViagem();
    await assentar(tester);
    expect(find.text('Nenhuma viagem programada para hoje'), findsOneWidget);
    expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isFalse);
  });

  testWidgets('iniciar e finalizar gravam o status da viagem', (tester) async {
    final gravados = <(String, String)>[];
    await abrirTela(
      tester,
      notebook,
      modelo: modeloTeste(statusGravados: gravados),
    );
    await tocar(tester, find.text('Iniciar viagem'));
    await tocar(tester, find.text('Finalizar viagem'));
    expect(gravados, [('v-teste', 'em_andamento'), ('v-teste', 'finalizada')]);
  });
}
