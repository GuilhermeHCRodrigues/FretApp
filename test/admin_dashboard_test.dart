import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/tema/app_tema.dart';
import 'package:fretapp/views/admin_dashboard_view.dart';

// Só a Visão geral é aberta: as demais abas consultam o Supabase.
Future<List<String>> abrir(WidgetTester tester, Size tamanho) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamanho;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final saidas = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.claro,
      home: AdminDashboardView(onSair: () async => saidas.add('sair')),
    ),
  );
  await tester.pumpAndSettle();
  return saidas;
}

void main() {
  for (final tamanho in const [
    Size(1366, 768),
    Size(1920, 1080),
    Size(900, 768),
  ]) {
    testWidgets('desktop usa a casca com menu lateral em $tamanho', (
      tester,
    ) async {
      final saidas = await abrir(tester, tamanho);

      final trilho = find.byType(NavigationRail);
      expect(trilho, findsOneWidget);
      expect(tester.widget<NavigationRail>(trilho).destinations, hasLength(8));
      expect(tester.getRect(trilho).left, 0);
      expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      // Título da aba no cabeçalho + item do menu.
      expect(find.text('Visão geral'), findsNWidgets(2));
      expect(find.text('Acesso rápido'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sair da conta'));
      expect(saidas, ['sair']);
    });
  }

  testWidgets('janela baixa rola o menu sem estourar', (tester) async {
    await abrir(tester, const Size(1366, 520));
    expect(tester.takeException(), isNull);

    // O rodapé (sair) fica fixo; os itens rolam dentro do menu.
    expect(find.text('Sair da conta').hitTestable(), findsOneWidget);
    final ultimo = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Mensagens'),
    );
    await tester.scrollUntilVisible(
      ultimo,
      100,
      scrollable: find
          .descendant(
            of: find.byType(NavigationRail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(ultimo.hitTestable(), findsOneWidget);
    expect(find.text('Sair da conta').hitTestable(), findsOneWidget);
  });

  for (final tamanho in const [Size(390, 844), Size(768, 1024)]) {
    testWidgets('celular troca a barra inferior pela gaveta em $tamanho', (
      tester,
    ) async {
      final saidas = await abrir(tester, tamanho);

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Visão geral'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final gaveta = find.byType(NavigationDrawer);
      expect(gaveta, findsOneWidget);
      for (final rotulo in [
        'Veículos',
        'Motoristas',
        'Passageiros',
        'Mensagens',
      ]) {
        expect(
          find.descendant(of: gaveta, matching: find.text(rotulo)),
          findsOneWidget,
        );
      }
      expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);

      await tester.tap(find.text('Sair da conta'));
      expect(saidas, ['sair']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('em tela estreita com fonte ampliada não estoura', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await abrir(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
