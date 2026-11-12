/// Coordenada simples para o mapa.
class Coordenada {
  const Coordenada(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Ponto de parada da rota (`pontos_rota`).
class PontoRota {
  const PontoRota({
    required this.nome,
    required this.ordem,
    this.endereco,
    this.horario,
    this.coordenada,
  });

  factory PontoRota.deJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return PontoRota(
      nome: json['nome'] as String? ?? 'Ponto',
      ordem: (json['ordem'] as num?)?.toInt() ?? 0,
      endereco: json['endereco'] as String?,
      horario: _horaMinuto(json['horario'] as String?),
      coordenada: lat == null || lng == null ? null : Coordenada(lat, lng),
    );
  }

  final String nome;
  final int ordem;
  final String? endereco;

  /// "HH:mm".
  final String? horario;
  final Coordenada? coordenada;
}

/// Viagem programada pelo administrador para hoje (função `viagem_do_dia`).
class ViagemDoDia {
  const ViagemDoDia({
    required this.id,
    required this.status,
    required this.saidaPrevista,
    required this.origem,
    required this.destino,
    this.chegadaPrevista,
    this.nomeRota,
    this.trajeto = const [],
    this.distanciaKm,
    this.duracaoMin,
    this.placa,
    this.modeloVeiculo,
    this.pontos = const [],
  });

  factory ViagemDoDia.deJson(Map<String, dynamic> json) {
    final rota = Map<String, dynamic>.from(json['rota'] as Map? ?? const {});
    final veiculo = json['veiculo'] == null
        ? null
        : Map<String, dynamic>.from(json['veiculo'] as Map);
    return ViagemDoDia(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'programada',
      saidaPrevista: DateTime.parse(json['saida_prevista'] as String).toLocal(),
      chegadaPrevista: json['chegada_prevista'] == null
          ? null
          : DateTime.parse(json['chegada_prevista'] as String).toLocal(),
      nomeRota: rota['nome'] as String?,
      origem: rota['origem'] as String? ?? 'Origem',
      destino: rota['destino'] as String? ?? 'Destino',
      trajeto: [
        for (final p in (rota['trajeto'] as List? ?? const []))
          Coordenada(
            ((p as List)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
      ],
      distanciaKm: (rota['distancia_km'] as num?)?.toDouble(),
      duracaoMin: (rota['duracao_min'] as num?)?.toInt(),
      placa: veiculo?['placa'] as String?,
      modeloVeiculo: veiculo?['modelo'] as String?,
      pontos: [
        for (final p in (json['pontos'] as List? ?? const []))
          PontoRota.deJson(Map<String, dynamic>.from(p as Map)),
      ],
    );
  }

  final String id;

  /// `viagens.status`: programada | em_andamento | finalizada | cancelada.
  final String status;
  final DateTime saidaPrevista;
  final DateTime? chegadaPrevista;
  final String? nomeRota;
  final String origem;
  final String destino;
  final List<Coordenada> trajeto;
  final double? distanciaKm;
  final int? duracaoMin;
  final String? placa;
  final String? modeloVeiculo;
  final List<PontoRota> pontos;

  /// "HH:mm" da saída prevista (horário local).
  String get horarioSaida => _formatar(saidaPrevista);

  /// Ex.: "VIAGGIO R · OYB-4I11" (ou "—" sem veículo).
  String get veiculo {
    final partes = [
      if (modeloVeiculo != null && modeloVeiculo!.trim().isNotEmpty)
        _modeloCurto(modeloVeiculo!),
      if (placa != null && placa!.trim().isNotEmpty) _placaFormatada(placa!),
    ];
    return partes.isEmpty ? '—' : partes.join(' · ');
  }

  ViagemDoDia comStatus(String novo) => ViagemDoDia(
    id: id,
    status: novo,
    saidaPrevista: saidaPrevista,
    chegadaPrevista: chegadaPrevista,
    nomeRota: nomeRota,
    origem: origem,
    destino: destino,
    trajeto: trajeto,
    distanciaKm: distanciaKm,
    duracaoMin: duracaoMin,
    placa: placa,
    modeloVeiculo: modeloVeiculo,
    pontos: pontos,
  );

  static String _formatar(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Tira o prefixo da fabricante quando vier junto ("MPOLO VIAGGIO R").
  static String _modeloCurto(String modelo) {
    final m = modelo.trim();
    return m.toUpperCase().startsWith('MPOLO ') ? m.substring(6) : m;
  }

  /// "OYB4I11" -> "OYB-4I11".
  static String _placaFormatada(String placa) {
    final p = placa.trim().toUpperCase();
    return p.length == 7 ? '${p.substring(0, 3)}-${p.substring(3)}' : p;
  }
}

String? _horaMinuto(String? hora) {
  if (hora == null || hora.length < 5) return hora;
  return hora.substring(0, 5);
}
