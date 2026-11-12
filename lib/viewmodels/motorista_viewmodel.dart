import 'package:flutter/foundation.dart';

import '../models/passageiro_viagem.dart';

enum SituacaoViagem { aguardando, emAndamento, finalizada }

/// Estado local da demonstração. Nenhuma posição do dispositivo é consultada.
class MotoristaViewModel extends ChangeNotifier {
  MotoristaViewModel({
    this.viagemId = _viagemDemo,
    this.origem = 'Centro',
    this.destino = 'Faculdade',
    this.horarioSaida = '06:30',
    Iterable<PassageiroViagem> passageiros = _passageirosDemo,
  }) : _passageiros = {
         for (final passageiro in passageiros)
           if (passageiro.viagemId == viagemId) passageiro.id: passageiro,
       };

  final String viagemId;
  final String origem;
  final String destino;
  final String horarioSaida;
  final Map<String, PassageiroViagem> _passageiros;
  String _busca = '';
  bool _gpsAtivado = true;
  SituacaoViagem _situacao = SituacaoViagem.aguardando;
  int _etapaMapa = 0;
  String? _ultimoAviso;

  bool get gpsAtivado => _gpsAtivado;
  SituacaoViagem get situacao => _situacao;
  int get etapaMapa => _etapaMapa;
  String? get ultimoAviso => _ultimoAviso;

  String get busca => _busca;
  int get totalPassageiros => _passageiros.length;
  int get embarcados => _passageiros.values.where((p) => p.embarcou).length;
  int get pendentes => totalPassageiros - embarcados;

  List<PassageiroViagem> get passageirosFiltrados {
    final termo = _normalizar(_busca);
    return List.unmodifiable(
      _passageiros.values.where((p) => _normalizar(p.nome).contains(termo)),
    );
  }

  void pesquisar(String texto) {
    if (_busca == texto) return;
    _busca = texto;
    notifyListeners();
  }

  void definirEmbarque(String id, bool embarcou) {
    final passageiro = _passageiros[id];
    if (passageiro == null || passageiro.embarcou == embarcou) return;
    _passageiros[id] = passageiro.comEmbarque(embarcou);
    notifyListeners();
  }

  bool get podeIniciar => gpsAtivado && situacao == SituacaoViagem.aguardando;

  bool get podeSair =>
      situacao == SituacaoViagem.emAndamento &&
      (etapaMapa == 0 || etapaMapa == 2);

  bool get podeChegar =>
      situacao == SituacaoViagem.emAndamento &&
      (etapaMapa == 1 || etapaMapa == 3);

  bool get podeFinalizar => situacao == SituacaoViagem.emAndamento;

  void definirGps(bool ativado) {
    if (_gpsAtivado == ativado) return;
    _gpsAtivado = ativado;
    notifyListeners();
  }

  void iniciarViagem() {
    if (!podeIniciar) return;
    _situacao = SituacaoViagem.emAndamento;
    _ultimoAviso = 'Viagem iniciada.';
    notifyListeners();
  }

  void registrarSaida() {
    if (!podeSair) return;
    _etapaMapa++;
    _ultimoAviso = _etapaMapa == 1
        ? 'Saída do Centro registrada.'
        : 'Saída do primeiro ponto registrada.';
    notifyListeners();
  }

  void registrarChegada() {
    if (!podeChegar) return;
    _etapaMapa++;
    _ultimoAviso = _etapaMapa == 2
        ? 'Chegada ao primeiro ponto registrada.'
        : 'Chegada ao segundo ponto registrada.';
    notifyListeners();
  }

  void finalizarViagem() {
    if (!podeFinalizar) return;
    _situacao = SituacaoViagem.finalizada;
    _etapaMapa = 5;
    _ultimoAviso = 'Viagem finalizada.';
    notifyListeners();
  }
}

String _normalizar(String texto) => texto
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[\u0300-\u036f]'), '');

const _viagemDemo = 'demo-centro-faculdade-0630';
const _passageirosDemo = [
  PassageiroViagem(
    id: 'ana',
    viagemId: _viagemDemo,
    nome: 'Ana Souza',
    pontoEmbarque: 'Praça Central',
    embarcou: true,
  ),
  PassageiroViagem(
    id: 'carlos',
    viagemId: _viagemDemo,
    nome: 'Carlos Lima',
    pontoEmbarque: 'Terminal Rodoviário',
    embarcou: true,
  ),
  PassageiroViagem(
    id: 'beatriz',
    viagemId: _viagemDemo,
    nome: 'Beatriz Alves',
    pontoEmbarque: 'Avenida Brasil',
  ),
  PassageiroViagem(
    id: 'joao',
    viagemId: _viagemDemo,
    nome: 'João Pedro',
    pontoEmbarque: 'Praça Central',
  ),
];
