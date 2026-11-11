import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';
import 'package:fretapp/views/motorista_view.dart';
import 'package:fretapp/views/widgets/mapa_trajeto_demo.dart';

Future<void> abrirTela(
  WidgetTester tester,
  Size tamanho, {
  ThemeData? tema,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamanho;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: tema, home: const MotoristaView()),
  );
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder controle) async {
  await tester.ensureVisible(controle);
  await tester.pumpAndSettle();
  await tester.tap(controle);
  await tester.pumpAndSettle();
}

Finder botaoPrincipal() => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        const {
          'Iniciar viagem',
          'Viagem em andamento',
          'Viagem finalizada',
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
  testWidgets('o cartão e a lista usam os dados da viagem fornecida', (
    tester,
  ) async {
    final modelo = MotoristaViewModel(
      viagemId: 'volta',
      origem: 'Campus',
      destino: 'Estação',
      horarioSaida: '18:30',
      passageiros: const [
        PassageiroViagem(
          id: 'bia',
          viagemId: 'volta',
          nome: 'Bia',
          pontoEmbarque: 'Biblioteca',
        ),
        PassageiroViagem(
          id: 'ana',
          viagemId: 'ida',
          nome: 'Ana',
          pontoEmbarque: 'Praça',
        ),
      ],
    );
    addTearDown(modelo.dispose);
    await tester.pumpWidget(MaterialApp(home: MotoristaView(modelo: modelo)));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('passageiro'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);
    await tocar(tester, destino('Passageiros'));
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(find.bySemanticsLabel('Total: 1'), findsOneWidget);
  });

  testWidgets('em tela estreita o conteúdo rola acima da navegação fixa', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrirTela(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);

    final inicio = destino('Início');
    final menuAntes = tester.getRect(inicio);
    final topoAntes = tester.getTopLeft(find.text('Próxima viagem')).dy;
    final finalizar = find.text('Finalizar');
    await tester.ensureVisible(finalizar);
    await tester.pumpAndSettle();
    expect(tester.getRect(inicio), menuAntes);
    expect(
      tester.getTopLeft(find.text('Próxima viagem')).dy,
      lessThan(topoAntes),
    );
    expect(tester.getRect(finalizar).bottom, lessThan(menuAntes.top));
    expect(tester.takeException(), isNull);
  });

  const celular = Size(390, 844);
  const tablet = Size(768, 1024);
  const antesDoDesktop = Size(1023, 768);
  const desktopMinimo = Size(1024, 768);
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
      'disposição do painel e navegação em ${tamanho.width} × ${tamanho.height}',
      (tester) async {
        await abrirTela(tester, tamanho);
        final area = tester.getRect(find.byType(Scaffold));
        final mapa = tester.getRect(find.byType(MapaTrajetoDemo));
        final viagem = tester.getRect(find.text('Próxima viagem'));
        final gps = tester.getRect(find.byType(Switch));
        final iniciar = tester.getRect(botaoPrincipal());
        final inicio = destino('Início');
        final menu = tester.getRect(inicio);
        expect(area.center.dx, closeTo(tamanho.width / 2, 1));
        expect(viagem.bottom, lessThan(mapa.top));

        final desktop = tamanho.width >= 1024;
        if (!desktop) {
          final barra = find.byType(NavigationBar);
          expect(
            tester.widget<NavigationBar>(barra).destinations,
            hasLength(4),
          );
          expect(menu.bottom, greaterThan(tamanho.height - 80));
          expect(menu.bottom, lessThanOrEqualTo(tamanho.height));
          if (tamanho == celular) expect(area.width, tamanho.width);
          expect(mapa.bottom, lessThan(gps.top));
          expect(gps.bottom, lessThan(iniciar.top));
          expect(find.text('Ver passageiros'), findsNothing);
          expect(find.text('Último aviso'), findsNothing);
        } else {
          final trilho = find.byType(NavigationRail);
          expect(
            tester.widget<NavigationRail>(trilho).destinations,
            hasLength(4),
          );
          expect(tester.getRect(trilho).right, lessThanOrEqualTo(mapa.left));
          expect(area.left, greaterThan(0));
          expect(
            area.width,
            inInclusiveRange(tamanho == desktopMinimo ? 976 : 1000, 1360),
          );
          expect(mapa.width, greaterThan(430));
          expect(mapa.right, lessThanOrEqualTo(iniciar.left));
          expect(mapa.right, lessThan(gps.left));
          final cartaoViagem = find.ancestor(
            of: find.text('Próxima viagem'),
            matching: find.byType(Card),
          );
          final dados = [
            for (final valor in ['Centro', '06:30', 'Ônibus 12', '4'])
              tester.getRect(
                find.descendant(of: cartaoViagem, matching: find.text(valor)),
              ),
          ];
          for (var i = 1; i < dados.length; i++) {
            expect(dados[i - 1].right, lessThan(dados[i].left));
          }
          expect(gps.bottom, lessThan(iniciar.top));
          final finalizar = tester.getRect(find.text('Finalizar'));
          expect(iniciar.bottom, lessThan(finalizar.top));
          expect(finalizar.bottom, lessThanOrEqualTo(area.bottom));
          expect(
            finalizar.bottom,
            lessThan(tester.getTopLeft(find.text('Ver passageiros')).dy),
          );
          expect(
            tester.getBottomLeft(find.text('Ver passageiros')).dy,
            lessThan(tester.getTopLeft(find.text('Último aviso')).dy),
          );
          expect(mapa.bottom, lessThanOrEqualTo(area.bottom));
        }

        await tester.ensureVisible(find.text('Finalizar'));
        await tester.pumpAndSettle();
        expect(tester.getRect(inicio), menu);
        await tocar(tester, destino('Passageiros'));
        final indice = desktop
            ? tester
                  .widget<NavigationRail>(find.byType(NavigationRail))
                  .selectedIndex
            : tester
                  .widget<NavigationBar>(find.byType(NavigationBar))
                  .selectedIndex;
        expect(indice, 1);
        expect(find.text('Ana Souza'), findsOneWidget);
        final ana = tester.getRect(find.byKey(const ValueKey('ana')));
        final carlos = tester.getRect(find.byKey(const ValueKey('carlos')));
        if (desktop) {
          expect(carlos.left, greaterThan(ana.right));
          expect(carlos.top, closeTo(ana.top, 1));
        } else {
          expect(carlos.top, greaterThan(ana.bottom));
        }
        await tocar(tester, destino('Avisos'));
        expect(find.text('Nenhum aviso'), findsOneWidget);
        await tocar(tester, destino('Perfil'));
        expect(find.text('Perfil de demonstração do FretApp'), findsOneWidget);
        await tocar(tester, inicio);
        expect(find.text('Próxima viagem'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('o menu se expande com a largura e o mapa acompanha a altura', (
    tester,
  ) async {
    await abrirTela(tester, desktopMinimo);
    final trilho = find.byType(NavigationRail);
    final mapa = find.byType(MapaTrajetoDemo);
    final larguraCompacta = tester.getSize(trilho).width;
    expect(tester.widget<NavigationRail>(trilho).extended, isFalse);

    tester.view.physicalSize = notebook;
    await tester.pumpAndSettle();
    final alturaNotebook = tester.getSize(mapa).height;
    expect(tester.widget<NavigationRail>(trilho).extended, isTrue);
    expect(tester.getSize(trilho).width, greaterThan(larguraCompacta));
    expect(
      tester.getSize(mapa).width,
      greaterThan(tester.getSize(trilho).width),
    );

    tester.view.physicalSize = Size(notebook.width, monitor.height);
    await tester.pumpAndSettle();
    expect(tester.getSize(mapa).height, greaterThan(alturaNotebook));
    expect(tester.takeException(), isNull);
  });

  testWidgets('o resumo e o último aviso acompanham as ações da viagem', (
    tester,
  ) async {
    await abrirTela(tester, notebook);
    final atalho = find.text('Ver passageiros');
    final cartaoAviso = find.ancestor(
      of: find.text('Último aviso'),
      matching: find.byType(Card),
    );
    final cartaoResumo = find.ancestor(of: atalho, matching: find.byType(Card));
    Finder contador(String rotulo) => find.descendant(
      of: cartaoResumo,
      matching: find.bySemanticsLabel(rotulo),
    );
    Finder mensagem(String texto) =>
        find.descendant(of: cartaoAviso, matching: find.text(texto));
    final beatriz = find.byKey(const ValueKey('beatriz'));

    expect(mensagem('Nenhum aviso registrado.'), findsOneWidget);
    expect(contador('Total: 4'), findsOneWidget);
    expect(contador('Embarcados: 2'), findsOneWidget);
    expect(contador('Pendentes: 2'), findsOneWidget);
    await tocar(tester, atalho);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    await tocar(
      tester,
      find.descendant(of: beatriz, matching: find.text('Confirmar')),
    );
    await tocar(tester, destino('Início'));
    expect(contador('Total: 4'), findsOneWidget);
    expect(contador('Embarcados: 3'), findsOneWidget);
    expect(contador('Pendentes: 1'), findsOneWidget);
    await tocar(tester, atalho);
    await tocar(
      tester,
      find.descendant(of: beatriz, matching: find.text('Desfazer')),
    );
    await tocar(tester, destino('Início'));
    expect(contador('Embarcados: 2'), findsOneWidget);
    expect(contador('Pendentes: 2'), findsOneWidget);

    await tocar(tester, find.text('Iniciar viagem'));
    expect(mensagem('Viagem iniciada.'), findsOneWidget);
    await tocar(tester, find.text('Estou saindo'));
    expect(mensagem('Saída do Centro registrada.'), findsOneWidget);
    await tocar(tester, destino('Avisos'));
    expect(find.text('Saída do Centro registrada.'), findsOneWidget);
    await tocar(tester, destino('Início'));
    expect(mensagem('Saída do Centro registrada.'), findsOneWidget);
    await tocar(tester, find.text('Cheguei ao ponto'));
    expect(mensagem('Chegada ao primeiro ponto registrada.'), findsOneWidget);
    await tocar(tester, find.text('Finalizar'));
    expect(mensagem('Viagem finalizada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o painel e a aba Passageiros herdam o tema do aplicativo', (
    tester,
  ) async {
    final tema = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    await abrirTela(tester, notebook, tema: tema);
    expect(
      Theme.of(tester.element(botaoPrincipal())).colorScheme,
      tema.colorScheme,
    );
    await tocar(tester, destino('Passageiros'));
    expect(
      Theme.of(tester.element(find.byType(TextField))).colorScheme,
      tema.colorScheme,
    );
  });

  testWidgets(
    'redimensionar a janela preserva aba, busca, embarques e viagem',
    (tester) async {
      await abrirTela(tester, celular);
      await tocar(tester, find.text('Iniciar viagem'));
      await tocar(tester, destino('Passageiros'));
      final busca = find.byType(TextField);
      await tester.enterText(busca, 'beatriz');
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Confirmar'));

      for (final tamanho in [notebook, monitor, celular]) {
        tester.view.physicalSize = tamanho;
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(busca).controller!.text, 'beatriz');
        expect(find.text('Beatriz Alves'), findsOneWidget);
        expect(find.text('Embarcou'), findsOneWidget);
        expect(find.bySemanticsLabel('Embarcados: 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (tamanho == notebook) {
          await tocar(tester, find.text('Desfazer'));
          expect(find.text('Pendente'), findsOneWidget);
          expect(find.bySemanticsLabel('Embarcados: 2'), findsOneWidget);
          await tocar(tester, find.text('Confirmar'));
          expect(find.bySemanticsLabel('Embarcados: 3'), findsOneWidget);
        }
      }
      await tocar(tester, destino('Início'));
      expect(find.text('Viagem em andamento'), findsOneWidget);
    },
  );

  testWidgets(
    'GPS controla o início e a viagem persiste ao navegar entre abas',
    (tester) async {
      await abrirTela(tester, const Size(390, 844));
      final chaveGps = find.byType(Switch);
      await tocar(tester, chaveGps);
      expect(find.text('GPS desativado'), findsOneWidget);
      expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isFalse);
      await tocar(tester, chaveGps);
      expect(find.text('GPS ativado'), findsOneWidget);
      expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isTrue);

      await tocar(tester, find.text('Iniciar viagem'));
      expect(find.text('Viagem em andamento'), findsOneWidget);
      expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isFalse);
      await tocar(tester, find.text('Estou saindo'));
      await tocar(tester, find.text('Cheguei ao ponto'));
      await tocar(tester, destino('Avisos'));
      expect(
        find.text('Chegada ao primeiro ponto registrada.'),
        findsOneWidget,
      );
      await tocar(tester, destino('Passageiros'));
      expect(find.text('Ana Souza'), findsOneWidget);
      await tocar(tester, destino('Perfil'));
      expect(find.text('Perfil de demonstração do FretApp'), findsOneWidget);

      await tocar(tester, destino('Início'));
      expect(find.text('Viagem em andamento'), findsOneWidget);
      await tocar(tester, chaveGps);
      await tocar(tester, find.text('Finalizar'));
      expect(find.text('Viagem finalizada'), findsOneWidget);
      await tocar(tester, chaveGps);
      expect(tester.widget<FilledButton>(botaoPrincipal()).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('o mapa demonstrativo amplia a posição e restaura o trajeto', (
    tester,
  ) async {
    await abrirTela(tester, const Size(360, 720));
    final ampliar = find.byTooltip('Ampliar posição simulada do ônibus');
    expect(find.text('Mapa demonstrativo'), findsOneWidget);
    await tocar(tester, ampliar);
    tester.view.physicalSize = notebook;
    await tester.pumpAndSettle();
    final escalaMapa = find.descendant(
      of: find.byType(MapaTrajetoDemo),
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(escalaMapa).scale, greaterThan(1));
    await tocar(tester, find.byTooltip('Mostrar trajeto completo'));
    expect(tester.widget<AnimatedScale>(escalaMapa).scale, 1);
    expect(ampliar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'passageiros em tela estreita: busca, embarque, navegação e desfazer',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrirTela(tester, const Size(320, 568));
      expect(find.text('4'), findsOneWidget);
      await tocar(tester, destino('Passageiros'));
      final busca = find.byType(TextField);
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Carlos Lima'), findsOneWidget);
      expect(find.text('Beatriz Alves'), findsOneWidget);
      expect(find.text('João Pedro'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(busca);
      await tester.enterText(busca, 'ausente');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum passageiro encontrado'), findsOneWidget);

      await tester.enterText(busca, 'joao');
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza'), findsNothing);
      expect(find.text('João Pedro'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      await tocar(tester, find.text('Confirmar'));
      expect(find.text('Embarcou'), findsOneWidget);
      expect(find.bySemanticsLabel('Total: 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Embarcados: 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Pendentes: 1'), findsOneWidget);

      await tocar(tester, destino('Início'));
      expect(find.text('4'), findsOneWidget);
      await tocar(tester, destino('Passageiros'));
      expect(tester.widget<TextField>(busca).controller!.text, 'joao');
      expect(find.text('Embarcou'), findsOneWidget);
      await tocar(tester, find.text('Desfazer'));
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.bySemanticsLabel('Embarcados: 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Pendentes: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
