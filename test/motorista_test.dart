import 'package:flutter_test/flutter_test.dart';

import 'package:fretapp/viewmodels/motorista_viewmodel.dart';

void main() {
  late MotoristaViewModel motorista;
  late int notificacoes;

  setUp(() {
    motorista = MotoristaViewModel();
    notificacoes = 0;
    motorista.addListener(() => notificacoes++);
  });

  tearDown(() => motorista.dispose());

  test('aguarda o início e exige GPS simulado ativo', () {
    expect(motorista.situacao, SituacaoViagem.aguardando);
    expect(motorista.gpsAtivado, isTrue);
    expect(motorista.podeIniciar, isTrue);
    expect(motorista.ultimoAviso, isNull);

    motorista.definirGps(false);
    motorista.definirGps(false);
    expect(motorista.podeIniciar, isFalse);
    motorista.iniciarViagem();
    motorista.registrarSaida();
    motorista.registrarChegada();
    motorista.finalizarViagem();
    expect(motorista.situacao, SituacaoViagem.aguardando);
    expect(motorista.etapaMapa, 0);
    expect(notificacoes, 1);

    motorista.definirGps(true);
    motorista.iniciarViagem();
    motorista.iniciarViagem();
    expect(motorista.situacao, SituacaoViagem.emAndamento);
    expect(motorista.podeIniciar, isFalse);
    expect(motorista.ultimoAviso, isNotEmpty);
    expect(notificacoes, 3);
  });

  test('alterna saída e chegada pelos dois pontos sem duplicar ações', () {
    motorista.iniciarViagem();
    motorista.registrarChegada();
    expect(motorista.etapaMapa, 0);

    for (final ponto in [1, 2]) {
      expect(motorista.podeSair, isTrue);
      expect(motorista.podeChegar, isFalse);
      motorista.registrarSaida();
      motorista.registrarSaida();
      expect(motorista.etapaMapa, ponto * 2 - 1);
      expect(motorista.podeSair, isFalse);
      expect(motorista.podeChegar, isTrue);

      motorista.registrarChegada();
      motorista.registrarChegada();
      expect(motorista.etapaMapa, ponto * 2);
      expect(motorista.ultimoAviso, contains('Chegada'));
    }

    expect(motorista.podeSair, isFalse);
    expect(motorista.podeChegar, isFalse);
    expect(motorista.podeFinalizar, isTrue);
    motorista.registrarSaida();
    expect(notificacoes, 5);
  });

  test('permite finalizar com GPS desligado e mantém o estado final', () {
    motorista.iniciarViagem();
    motorista.definirGps(false);
    expect(motorista.podeFinalizar, isTrue);
    motorista.finalizarViagem();
    motorista.definirGps(true);
    expect(motorista.podeIniciar, isFalse);
    expect(motorista.podeSair, isFalse);
    expect(motorista.podeChegar, isFalse);
    expect(motorista.podeFinalizar, isFalse);
    motorista.iniciarViagem();
    motorista.registrarSaida();
    motorista.registrarChegada();
    motorista.finalizarViagem();
    expect(motorista.situacao, SituacaoViagem.finalizada);
    expect(motorista.etapaMapa, 5);
    expect(motorista.ultimoAviso, contains('finalizada'));
    expect(notificacoes, 4);
  });

  test('reinicia a demonstração e permite uma segunda viagem', () {
    motorista.iniciarViagem();
    motorista.registrarSaida();
    motorista.registrarChegada();
    motorista.finalizarViagem();

    expect(motorista.situacao, SituacaoViagem.finalizada);
    expect(motorista.podeReiniciarDemonstracao, isTrue);
    expect(motorista.podeIniciar, isFalse);
    expect(motorista.etapaMapa, 5);

    motorista.reiniciarDemonstracao();

    expect(motorista.situacao, SituacaoViagem.aguardando);
    expect(motorista.podeReiniciarDemonstracao, isFalse);
    expect(motorista.podeIniciar, isTrue);
    expect(motorista.podeSair, isFalse);
    expect(motorista.podeChegar, isFalse);
    expect(motorista.podeFinalizar, isFalse);
    expect(motorista.etapaMapa, 0);
    expect(motorista.ultimoAviso, isNull);

    motorista.iniciarViagem();

    expect(motorista.situacao, SituacaoViagem.emAndamento);
    expect(motorista.podeSair, isTrue);
    expect(motorista.podeIniciar, isFalse);
  });
}
