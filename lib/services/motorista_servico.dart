import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/passageiro_viagem.dart';
import '../models/posicao_motorista.dart';
import '../models/viagem_do_dia.dart';

/// Data local no formato do banco (yyyy-MM-dd), igual à enquete do passageiro.
String dataLocalHoje() {
  final agora = DateTime.now();
  final mes = agora.month.toString().padLeft(2, '0');
  final dia = agora.day.toString().padLeft(2, '0');
  return '${agora.year}-$mes-$dia';
}

/// Passageiros que responderam a enquete de hoje e vão comparecer.
///
/// Usa a função `passageiros_enquete_dia` (migration
/// 20261112040000_passageiros_enquete_motorista.sql), porque o RLS não deixa o
/// motorista ler `confirmacoes_presenca` diretamente.
Future<List<PassageiroViagem>> buscarPassageirosDaEnquete(
  String viagemId,
) async {
  final linhas = await Supabase.instance.client.rpc(
    'passageiros_enquete_dia',
    params: {'p_data': dataLocalHoje()},
  );
  return [
    for (final linha in List<Map<String, dynamic>>.from(linhas as List))
      PassageiroViagem(
        id: linha['passageiro_id'] as String,
        viagemId: viagemId,
        nome: linha['nome'] as String,
        trajeto: linha['trajeto'] as String?,
      ),
  ];
}

/// Pede ao dispositivo/navegador para compartilhar a localização.
/// Devolve `true` só se o motorista permitir.
Future<bool> solicitarLocalizacao() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    return permissao == LocationPermission.always ||
        permissao == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

/// Posições do GPS em tempo real (a cada ~5 m de deslocamento).
/// Só chame depois que [solicitarLocalizacao] devolver `true`.
Stream<PosicaoMotorista> acompanharLocalizacao() =>
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map(
      (p) => PosicaoMotorista(
        p.latitude,
        p.longitude,
        // No navegador o rumo costuma vir 0/NaN parado; só vale em movimento.
        rumo: p.heading.isFinite && p.speed > 1 ? p.heading : null,
        precisao: p.accuracy,
      ),
    );

// ── Posição compartilhada (tabela localizacao_onibus) ────────────────────────
// Migration: 20261112050000_localizacao_onibus.sql

/// Motorista: grava a própria posição. `emViagem: false` esconde dos passageiros.
Future<void> publicarPosicao(PosicaoMotorista posicao, bool emViagem) async {
  final cliente = Supabase.instance.client;
  final usuario = cliente.auth.currentUser;
  if (usuario == null) return;
  await cliente.from('localizacao_onibus').upsert({
    'motorista_id': usuario.id,
    'latitude': posicao.latitude,
    'longitude': posicao.longitude,
    'rumo': posicao.rumo,
    'precisao': posicao.precisao,
    'em_viagem': emViagem,
    'atualizado_em': DateTime.now().toUtc().toIso8601String(),
  });
}

/// Passageiro: ônibus em viagem agora, atualizados em tempo real.
/// Só leitura; não pede a localização do passageiro.
Stream<List<PosicaoMotorista>> acompanharOnibus() => Supabase.instance.client
    .from('localizacao_onibus')
    .stream(primaryKey: ['motorista_id'])
    .eq('em_viagem', true)
    .map(
      (linhas) => [
        for (final l in linhas)
          PosicaoMotorista(
            (l['latitude'] as num).toDouble(),
            (l['longitude'] as num).toDouble(),
            rumo: (l['rumo'] as num?)?.toDouble(),
            precisao: (l['precisao'] as num?)?.toDouble(),
            atualizadoEm: DateTime.tryParse(l['atualizado_em'] as String? ?? ''),
          ),
      ],
    );

// ── Viagem programada (migration 20261112060000_viagem_do_dia.sql) ──────────

/// Motorista: a próxima viagem dele hoje. Passageiro: a próxima viagem do dia.
/// `null` quando não há viagem programada.
Future<ViagemDoDia?> buscarViagemDoDia() async {
  final dados = await Supabase.instance.client.rpc('viagem_do_dia');
  if (dados == null) return null;
  return ViagemDoDia.deJson(Map<String, dynamic>.from(dados as Map));
}

/// Motorista marca a própria viagem: 'em_andamento' ou 'finalizada'.
Future<void> atualizarStatusViagem(String viagemId, String status) =>
    Supabase.instance.client.rpc(
      'atualizar_status_viagem',
      params: {'p_viagem': viagemId, 'p_status': status},
    );
