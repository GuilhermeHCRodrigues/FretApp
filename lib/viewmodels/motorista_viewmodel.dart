import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/passageiro_viagem.dart';
import '../models/posicao_motorista.dart';
import '../models/viagem_do_dia.dart';

enum SituacaoViagem { aguardando, emAndamento, finalizada }

/// Situação do compartilhamento de localização do motorista.
enum EstadoLocalizacao { naoSolicitada, solicitando, permitida, negada }

/// Busca os passageiros da viagem (ex.: enquete do dia no Supabase).
typedef FontePassageiros =
    Future<List<PassageiroViagem>> Function(String viagemId);

/// Pede permissão de localização; devolve `true` se o motorista permitir.
typedef SolicitarLocalizacao = Future<bool> Function();

/// Posições do GPS em tempo real (depois da permissão concedida).
typedef AcompanharLocalizacao = Stream<PosicaoMotorista> Function();

/// Envia a posição para os passageiros. `emViagem: false` esconde o ônibus.
typedef PublicarPosicao =
    Future<void> Function(PosicaoMotorista posicao, bool emViagem);

/// Busca a viagem programada de hoje (null = nenhuma).
typedef FonteViagem = Future<ViagemDoDia?> Function();

/// Grava o status da viagem no banco ('em_andamento' | 'finalizada').
typedef AtualizarStatusViagem =
    Future<void> Function(String viagemId, String status);

/// Estado do painel do motorista.
///
/// A viagem vem de [fonteViagem] (programada pelo administrador) e os
/// passageiros de [fontePassageiros] (enquete do dia). Os embarques marcados
/// aqui ainda ficam só na tela; não são gravados no banco.
class MotoristaViewModel extends ChangeNotifier {
  MotoristaViewModel({
    this.viagemId = 'viagem-do-dia',
    ViagemDoDia? viagemInicial,
    this.fonteViagem,
    this.atualizarStatus,
    Iterable<PassageiroViagem> passageiros = const [],
    this.fontePassageiros,
    this.solicitarLocalizacao,
    this.acompanharLocalizacao,
    this.publicarPosicao,
    this.intervaloPublicacao = const Duration(seconds: 3),
    this.intervaloSinal = const Duration(seconds: 20),
  }) : _carregando = fontePassageiros != null,
       _viagem = viagemInicial,
       _carregandoViagem = fonteViagem != null,
       _passageiros = _porId(passageiros, viagemId);

  /// Chave usada para separar passageiros por viagem na lista local.
  final String viagemId;
  final FonteViagem? fonteViagem;
  final AtualizarStatusViagem? atualizarStatus;
  final FontePassageiros? fontePassageiros;
  final SolicitarLocalizacao? solicitarLocalizacao;
  final AcompanharLocalizacao? acompanharLocalizacao;
  final PublicarPosicao? publicarPosicao;

  /// Intervalo mínimo entre envios ao mover (evita gravar a cada metro).
  final Duration intervaloPublicacao;

  /// Reenvio periódico parado, para o passageiro saber que o sinal está vivo.
  final Duration intervaloSinal;

  ViagemDoDia? _viagem;
  bool _carregandoViagem;
  String? _erroViagem;
  Map<String, PassageiroViagem> _passageiros;
  bool _carregando;
  String? _erroPassageiros;
  String _busca = '';
  EstadoLocalizacao _localizacao = EstadoLocalizacao.naoSolicitada;
  SituacaoViagem _situacao = SituacaoViagem.aguardando;
  PosicaoMotorista? _posicao;
  final List<PosicaoMotorista> _rastro = [];
  StreamSubscription<PosicaoMotorista>? _assinaturaGps;
  Timer? _sinal;
  DateTime? _ultimaPublicacao;
  bool _avisouFalhaEnvio = false;
  String? _ultimoAviso;
  bool _descartado = false;

  static Map<String, PassageiroViagem> _porId(
    Iterable<PassageiroViagem> lista,
    String viagemId,
  ) => {
    for (final passageiro in lista)
      if (passageiro.viagemId == viagemId) passageiro.id: passageiro,
  };

  // ── Viagem programada ────────────────────────────────────────────────────
  ViagemDoDia? get viagem => _viagem;
  bool get carregandoViagem => _carregandoViagem;
  String? get erroViagem => _erroViagem;

  /// Sem viagem programada hoje (depois de carregar, sem erro).
  bool get semViagem =>
      !_carregandoViagem && _erroViagem == null && _viagem == null;

  String get origem => _viagem?.origem ?? '—';
  String get destino => _viagem?.destino ?? '—';
  String get horarioSaida => _viagem?.horarioSaida ?? '--:--';
  String get veiculo => _viagem?.veiculo ?? '—';

  Future<void> carregarViagem() async {
    final fonte = fonteViagem;
    if (fonte == null) return;
    _carregandoViagem = true;
    _erroViagem = null;
    _notificar();
    try {
      _viagem = await fonte();
      if (_descartado) return;
      // Voltou para a tela com a viagem já em andamento: retoma.
      if (_viagem?.status == 'em_andamento' &&
          _situacao == SituacaoViagem.aguardando) {
        _situacao = SituacaoViagem.emAndamento;
        _ultimoAviso = 'Viagem em andamento retomada.';
        if (await compartilharLocalizacao()) _comecarEnvio();
      }
    } catch (e) {
      debugPrint('Erro ao carregar a viagem do dia: $e');
      _erroViagem = 'Não foi possível carregar a viagem de hoje.';
    } finally {
      _carregandoViagem = false;
      _notificar();
    }
  }

  // ── Passageiros ──────────────────────────────────────────────────────────
  bool get carregando => _carregando;
  String? get erroPassageiros => _erroPassageiros;
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

  /// Recarrega a lista da [fontePassageiros], mantendo quem já embarcou.
  Future<void> carregarPassageiros() async {
    final fonte = fontePassageiros;
    if (fonte == null) return;
    _carregando = true;
    _erroPassageiros = null;
    _notificar();
    try {
      final lista = await fonte(viagemId);
      final embarcados = {
        for (final p in _passageiros.values)
          if (p.embarcou) p.id,
      };
      _passageiros = _porId(
        lista.map(
          (p) => embarcados.contains(p.id) ? p.comEmbarque(true) : p,
        ),
        viagemId,
      );
    } catch (e) {
      debugPrint('Erro ao carregar passageiros da enquete: $e');
      _erroPassageiros = 'Não foi possível carregar a lista da enquete.';
    } finally {
      _carregando = false;
      _notificar();
    }
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

  // ── Localização ──────────────────────────────────────────────────────────
  EstadoLocalizacao get localizacao => _localizacao;

  /// Última posição do GPS (null até a primeira leitura).
  PosicaoMotorista? get posicao => _posicao;

  /// Caminho percorrido desde o início da viagem.
  List<PosicaoMotorista> get rastro => List.unmodifiable(_rastro);

  /// Pede a localização (sem iniciar a viagem) e começa a seguir o GPS.
  /// Devolve `true` se o motorista permitir.
  Future<bool> compartilharLocalizacao() async {
    if (_localizacao == EstadoLocalizacao.permitida) return true;
    if (_localizacao == EstadoLocalizacao.solicitando) return false;

    final solicitar = solicitarLocalizacao;
    if (solicitar == null) {
      _localizacao = EstadoLocalizacao.permitida;
      _acompanhar();
      return true;
    }

    _localizacao = EstadoLocalizacao.solicitando;
    _notificar();
    final permitiu = await solicitar();
    if (_descartado) return false;
    _localizacao = permitiu
        ? EstadoLocalizacao.permitida
        : EstadoLocalizacao.negada;
    if (permitiu) {
      _acompanhar();
    } else {
      _ultimoAviso = 'Compartilhe sua localização para iniciar a viagem.';
    }
    notifyListeners();
    return permitiu;
  }

  void _acompanhar() {
    final fonte = acompanharLocalizacao;
    if (fonte == null || _assinaturaGps != null) return;
    _assinaturaGps = fonte().listen(
      _receberPosicao,
      onError: (Object e) {
        debugPrint('Erro no GPS: $e');
        _ultimoAviso = 'Sinal de GPS indisponível no momento.';
        _notificar();
      },
    );
  }

  void _receberPosicao(PosicaoMotorista nova) {
    if (_descartado) return;
    final anterior = _posicao;
    // Sem rumo do aparelho: calcula pela direção do deslocamento.
    var rumo = nova.rumo;
    if (rumo == null && anterior != null) {
      rumo = anterior.distanciaAte(nova) >= 3
          ? anterior.rumoAte(nova)
          : anterior.rumo;
    }
    _posicao = nova.comRumo(rumo);
    if (_situacao == SituacaoViagem.emAndamento) {
      _rastro.add(_posicao!);
      final ultima = _ultimaPublicacao;
      if (ultima == null ||
          DateTime.now().difference(ultima) >= intervaloPublicacao) {
        _publicar(emViagem: true);
      }
    }
    notifyListeners();
  }

  /// Envia a última posição; falhas não interrompem a viagem.
  Future<void> _publicar({required bool emViagem}) async {
    final enviar = publicarPosicao;
    final atual = _posicao;
    if (enviar == null || atual == null) return;
    _ultimaPublicacao = DateTime.now();
    try {
      await enviar(atual, emViagem);
      _avisouFalhaEnvio = false;
    } catch (e) {
      debugPrint('Erro ao enviar posição: $e');
      if (!_avisouFalhaEnvio && !_descartado) {
        _avisouFalhaEnvio = true;
        _ultimoAviso = 'Não foi possível enviar sua posição aos passageiros.';
        notifyListeners();
      }
    }
  }

  // ── Viagem ───────────────────────────────────────────────────────────────
  SituacaoViagem get situacao => _situacao;
  String? get ultimoAviso => _ultimoAviso;

  bool get podeIniciar =>
      situacao == SituacaoViagem.aguardando &&
      localizacao != EstadoLocalizacao.solicitando &&
      (fonteViagem == null || _viagem != null);

  bool get podeFinalizar => situacao == SituacaoViagem.emAndamento;

  bool get podeNovaViagem => situacao == SituacaoViagem.finalizada;

  /// Pede a localização e só inicia a viagem se o motorista permitir.
  Future<void> iniciarViagem() async {
    if (!podeIniciar) return;
    if (!await compartilharLocalizacao()) return;
    if (_descartado || _situacao != SituacaoViagem.aguardando) return;

    final atual = _viagem;
    final gravar = atualizarStatus;
    if (atual != null && gravar != null) {
      try {
        await gravar(atual.id, 'em_andamento');
        _viagem = atual.comStatus('em_andamento');
      } catch (e) {
        debugPrint('Erro ao iniciar a viagem no banco: $e');
        _ultimoAviso = 'Não foi possível iniciar a viagem. Tente de novo.';
        _notificar();
        return;
      }
      if (_descartado) return;
    }

    _situacao = SituacaoViagem.emAndamento;
    _rastro
      ..clear()
      ..addAll([?_posicao]);
    _ultimoAviso = 'Viagem iniciada.';
    _comecarEnvio();
    notifyListeners();
  }

  /// Envia a posição agora e mantém um sinal periódico enquanto em viagem.
  void _comecarEnvio() {
    _publicar(emViagem: true);
    _sinal?.cancel();
    if (publicarPosicao != null) {
      _sinal = Timer.periodic(
        intervaloSinal,
        (_) => _publicar(emViagem: true),
      );
    }
  }

  Future<void> finalizarViagem() async {
    if (!podeFinalizar) return;
    _situacao = SituacaoViagem.finalizada;
    _sinal?.cancel();
    _sinal = null;
    _publicar(emViagem: false);
    _ultimoAviso = 'Viagem finalizada.';
    notifyListeners();

    final atual = _viagem;
    final gravar = atualizarStatus;
    if (atual == null || gravar == null) return;
    try {
      await gravar(atual.id, 'finalizada');
      _viagem = atual.comStatus('finalizada');
    } catch (e) {
      debugPrint('Erro ao finalizar a viagem no banco: $e');
      _ultimoAviso =
          'Viagem finalizada aqui, mas não foi possível avisar o sistema.';
    }
    _notificar();
  }

  /// Volta o painel ao estado inicial depois de finalizar.
  void novaViagem() {
    if (!podeNovaViagem) return;
    _situacao = SituacaoViagem.aguardando;
    _rastro.clear();
    _passageiros = {
      for (final p in _passageiros.values) p.id: p.comEmbarque(false),
    };
    _ultimoAviso = 'Pronto para uma nova viagem.';
    notifyListeners();
    // A viagem anterior acabou: busca a próxima programada.
    carregarViagem();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _assinaturaGps?.cancel();
    _sinal?.cancel();
    // Saiu da tela no meio da viagem: esconde o ônibus dos passageiros.
    if (_situacao == SituacaoViagem.emAndamento) _publicar(emViagem: false);
    super.dispose();
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
    .replaceAll(RegExp(r'[̀-ͯ]'), '');
