import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fretapp/models/passageiro_viagem.dart';
import 'package:fretapp/models/posicao_motorista.dart';
import 'package:fretapp/viewmodels/motorista_viewmodel.dart';

const _viagem = 'viagem-teste';

const _enquete = [
  PassageiroViagem(
    id: 'p1',
    viagemId: _viagem,
    nome: 'Ana Exemplo',
    trajeto: 'ida_volta',
  ),
  PassageiroViagem(
    id: 'p2',
    viagemId: _viagem,
    nome: 'Bruno Exemplo',
    trajeto: 'ida',
  ),
];

MotoristaViewModel _modelo({
  bool permitir = true,
  List<PassageiroViagem> enquete = _enquete,
}) => MotoristaViewModel(
  viagemId: _viagem,
  fontePassageiros: (_) async => enquete,
  solicitarLocalizacao: () async => permitir,
);

void main() {
  test('carrega os passageiros da enquete do dia', () async {
    final motorista = _modelo();
    addTearDown(motorista.dispose);
    expect(motorista.carregando, isTrue);

    await motorista.carregarPassageiros();
    expect(motorista.carregando, isFalse);
    expect(motorista.erroPassageiros, isNull);
    expect(
      motorista.passageirosFiltrados.map((p) => (p.nome, p.trajeto)),
      [('Ana Exemplo', 'ida_volta'), ('Bruno Exemplo', 'ida')],
    );
    expect((motorista.totalPassageiros, motorista.pendentes), (2, 2));
  });

  test('falha na enquete vira mensagem de erro e permite tentar de novo', () async {
    var falhar = true;
    final motorista = MotoristaViewModel(
      viagemId: _viagem,
      fontePassageiros: (_) async {
        if (falhar) throw Exception('sem rede');
        return _enquete;
      },
    );
    addTearDown(motorista.dispose);

    await motorista.carregarPassageiros();
    expect(motorista.erroPassageiros, isNotNull);
    expect(motorista.totalPassageiros, 0);

    falhar = false;
    await motorista.carregarPassageiros();
    expect(motorista.erroPassageiros, isNull);
    expect(motorista.totalPassageiros, 2);
  });

  test('recarregar a enquete mantém quem já embarcou', () async {
    final motorista = _modelo();
    addTearDown(motorista.dispose);
    await motorista.carregarPassageiros();
    motorista.definirEmbarque('p1', true);

    await motorista.carregarPassageiros();
    expect(motorista.embarcados, 1);
  });

  test('só inicia a viagem se a localização for permitida', () async {
    final motorista = _modelo(permitir: false);
    addTearDown(motorista.dispose);

    await motorista.iniciarViagem();
    expect(motorista.localizacao, EstadoLocalizacao.negada);
    expect(motorista.situacao, SituacaoViagem.aguardando);
    expect(motorista.podeIniciar, isTrue);
    expect(motorista.ultimoAviso, contains('localização'));
  });

  test('pede a localização uma única vez quando permitida', () async {
    var pedidos = 0;
    final motorista = MotoristaViewModel(
      solicitarLocalizacao: () async {
        pedidos++;
        return true;
      },
    );
    addTearDown(motorista.dispose);

    final inicio = motorista.iniciarViagem();
    expect(motorista.localizacao, EstadoLocalizacao.solicitando);
    expect(motorista.podeIniciar, isFalse);
    await inicio;
    expect(motorista.localizacao, EstadoLocalizacao.permitida);
    expect(motorista.situacao, SituacaoViagem.emAndamento);

    motorista
      ..finalizarViagem()
      ..novaViagem();
    await motorista.iniciarViagem();
    expect(pedidos, 1);
  });

  test('segue o GPS e grava o rastro só durante a viagem', () async {
    final gps = StreamController<PosicaoMotorista>();
    final motorista = MotoristaViewModel(
      solicitarLocalizacao: () async => true,
      acompanharLocalizacao: () => gps.stream,
    );
    addTearDown(() {
      motorista.dispose();
      gps.close();
    });

    expect(await motorista.compartilharLocalizacao(), isTrue);
    gps.add(const PosicaoMotorista(-23.5000, -46.6000));
    await Future<void>.delayed(Duration.zero);
    expect(motorista.posicao?.latitude, -23.5000);
    expect(motorista.rastro, isEmpty);

    await motorista.iniciarViagem();
    expect(motorista.rastro, hasLength(1));
    // ~110 m para o norte: o rumo é calculado pelo deslocamento.
    gps.add(const PosicaoMotorista(-23.4990, -46.6000));
    await Future<void>.delayed(Duration.zero);
    expect(motorista.rastro, hasLength(2));
    expect(motorista.posicao!.rumo, closeTo(0, 1));

    motorista.finalizarViagem();
    gps.add(const PosicaoMotorista(-23.4980, -46.6000));
    await Future<void>.delayed(Duration.zero);
    expect(motorista.rastro, hasLength(2));
    expect(motorista.posicao!.latitude, -23.4980);
  });

  test('depois de finalizar, "nova viagem" volta tudo ao estado inicial', () async {
    final motorista = _modelo();
    addTearDown(motorista.dispose);
    await motorista.carregarPassageiros();
    await motorista.iniciarViagem();
    motorista
      ..definirEmbarque('p1', true)
      ..finalizarViagem();

    expect(motorista.situacao, SituacaoViagem.finalizada);
    expect(
      (motorista.podeIniciar, motorista.podeFinalizar),
      (false, false),
    );
    expect(motorista.podeNovaViagem, isTrue);

    motorista.novaViagem();
    expect(motorista.situacao, SituacaoViagem.aguardando);
    expect(motorista.rastro, isEmpty);
    expect(motorista.embarcados, 0);
    expect(motorista.totalPassageiros, 2);
    expect(motorista.podeIniciar, isTrue);
    expect(motorista.podeNovaViagem, isFalse);
  });

  test('publica a posição durante a viagem e esconde ao finalizar', () async {
    final gps = StreamController<PosicaoMotorista>();
    final envios = <(double, bool)>[];
    final motorista = MotoristaViewModel(
      solicitarLocalizacao: () async => true,
      acompanharLocalizacao: () => gps.stream,
      publicarPosicao: (p, emViagem) async => envios.add((p.latitude, emViagem)),
      intervaloPublicacao: Duration.zero,
    );
    addTearDown(() {
      motorista.dispose();
      gps.close();
    });

    await motorista.compartilharLocalizacao();
    gps.add(const PosicaoMotorista(-23.50, -46.60));
    await Future<void>.delayed(Duration.zero);
    expect(envios, isEmpty, reason: 'antes de iniciar, nada é enviado');

    await motorista.iniciarViagem();
    gps.add(const PosicaoMotorista(-23.49, -46.60));
    await Future<void>.delayed(Duration.zero);
    motorista.finalizarViagem();
    await Future<void>.delayed(Duration.zero);

    expect(envios, [(-23.50, true), (-23.49, true), (-23.49, false)]);
  });

  test('falha ao enviar avisa uma vez e não para a viagem', () async {
    final motorista = MotoristaViewModel(
      solicitarLocalizacao: () async => true,
      acompanharLocalizacao: () =>
          Stream.value(const PosicaoMotorista(-23.5, -46.6)),
      publicarPosicao: (_, _) async => throw Exception('sem rede'),
    );
    addTearDown(motorista.dispose);
    await motorista.compartilharLocalizacao();
    await Future<void>.delayed(Duration.zero);
    await motorista.iniciarViagem();
    await Future<void>.delayed(Duration.zero);
    expect(motorista.situacao, SituacaoViagem.emAndamento);
    expect(motorista.ultimoAviso, contains('enviar sua posição'));
  });
}
