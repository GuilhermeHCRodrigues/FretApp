import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretapp/models/posicao_motorista.dart';
import 'package:fretapp/models/viagem_do_dia.dart';
import 'package:fretapp/tema/app_tema.dart';
import 'package:fretapp/views/acompanhar_onibus_view.dart';

const _trajeto = [
  Coordenada(-23.3159, -46.2256),
  Coordenada(-23.4200, -46.2100),
  Coordenada(-23.5169, -46.1825),
];
const _pontos = [
  PontoRota(
    nome: 'Saída',
    ordem: 1,
    horario: '18:00',
    coordenada: Coordenada(-23.3159, -46.2256),
  ),
  PontoRota(
    nome: 'Destino',
    ordem: 2,
    horario: '18:45',
    coordenada: Coordenada(-23.5169, -46.1825),
  ),
];

Future<StreamController<List<PosicaoMotorista>>> abrir(
  WidgetTester tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fonte = StreamController<List<PosicaoMotorista>>();
  addTearDown(fonte.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTema.claro,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MapaOnibusAoVivo(
            trajeto: _trajeto,
            pontos: _pontos,
            fonte: () => fonte.stream,
            urlTiles: null,
          ),
        ),
      ),
    ),
  );
  return fonte;
}

void main() {
  testWidgets('mostra o trajeto e avisa que o ônibus ainda não saiu', (
    tester,
  ) async {
    final fonte = await abrir(tester);
    expect(find.text('Procurando o ônibus…'), findsOneWidget);
    fonte.add(const []);
    await tester.pump();
    await tester.pump();
    expect(find.text('O ônibus ainda não saiu'), findsWidgets);
    // Trajeto visível: marcador do destino (bandeira) e botão "ver trajeto".
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.byTooltip('Ver trajeto inteiro'), findsOneWidget);
    // Passageiro só visualiza: nenhum pedido de localização.
    expect(find.text('Compartilhar localização'), findsNothing);
  });

  testWidgets('mostra o ônibus ao vivo e depois sem sinal', (tester) async {
    final fonte = await abrir(tester);
    fonte.add([
      PosicaoMotorista(
        -23.4,
        -46.21,
        rumo: 45,
        atualizadoEm: DateTime.now().toUtc(),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.text('Ônibus a caminho'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);

    fonte.add([
      PosicaoMotorista(
        -23.4,
        -46.21,
        atualizadoEm: DateTime.now().toUtc().subtract(
          const Duration(minutes: 3),
        ),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Sem sinal do ônibus'), findsWidgets);
    expect(find.text('Última posição há 3 min'), findsOneWidget);
    expect(find.byIcon(Icons.navigation), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro na conexão oferece tentar de novo', (tester) async {
    final fonte = await abrir(tester);
    fonte.addError(Exception('falha'));
    await tester.pump();
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  test('ViagemDoDia lê o JSON da função viagem_do_dia', () {
    final v = ViagemDoDia.deJson({
      'id': 'v1',
      'status': 'programada',
      'saida_prevista': '2026-11-12T21:00:00+00:00',
      'rota': {
        'nome': 'Santa Isabel → UMC',
        'origem': 'Delegacia',
        'destino': 'UMC',
        'trajeto': [
          [-23.3, -46.2],
          [-23.5, -46.1],
        ],
        'distancia_km': 39.8,
        'duracao_min': 43,
      },
      'veiculo': {'placa': 'ABC1D23', 'modelo': 'MPOLO VIAGGIO R'},
      'pontos': [
        {'nome': 'Delegacia', 'ordem': 1, 'horario': '18:00:00'},
      ],
    });
    expect(v.trajeto, hasLength(2));
    expect(v.veiculo, 'VIAGGIO R · ABC-1D23');
    expect(v.pontos.single.horario, '18:00');
    expect(v.distanciaKm, 39.8);
  });
}
