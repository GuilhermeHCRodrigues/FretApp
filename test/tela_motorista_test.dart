import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';
import 'package:fretapp/views/motorista_view.dart';

Future<void> abrirTela(WidgetTester tester, Size tamanho) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamanho;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: MotoristaView()));
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder controle) async {
  await tester.ensureVisible(controle);
  await tester.pumpAndSettle();
  await tester.tap(controle);
  await tester.pumpAndSettle();
}

Finder botaoPrincipal() =>
    find.byWidgetPredicate((widget) => widget is FilledButton);

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
    await tocar(tester, find.text('Passageiros'));
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

    final inicio = find.text('Início');
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

  testWidgets('em tela desktop o app mantém 430 pixels e fica centralizado', (
    tester,
  ) async {
    await abrirTela(tester, const Size(1280, 800));
    final area = tester.getRect(find.byType(Scaffold));
    expect(area.width, 430);
    expect(area.center.dx, 640);
    expect(tester.takeException(), isNull);
  });

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
      await tocar(tester, find.text('Avisos'));
      expect(
        find.text('Chegada ao primeiro ponto registrada.'),
        findsOneWidget,
      );
      await tocar(tester, find.text('Passageiros'));
      expect(find.text('Ana Souza'), findsOneWidget);
      await tocar(tester, find.text('Perfil'));
      expect(find.text('Perfil de demonstração do FretApp'), findsOneWidget);

      await tocar(tester, find.text('Início'));
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
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      greaterThan(1),
    );
    await tocar(tester, find.byTooltip('Mostrar trajeto completo'));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
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
      await tocar(tester, find.text('Passageiros'));
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

      await tocar(tester, find.text('Início'));
      expect(find.text('4'), findsOneWidget);
      await tocar(tester, find.text('Passageiros'));
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
